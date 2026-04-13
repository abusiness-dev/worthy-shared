/**
 * Cleanup dei prodotti duplicati e incompleti.
 *
 * Uso:
 *   SUPABASE_URL=https://xxx.supabase.co \
 *   SUPABASE_SERVICE_ROLE_KEY=eyJ... \
 *     npx ts-node scripts/cleanup-products.ts
 *
 * Il service-role key bypassa RLS, quindi il file .env non va committato.
 *
 * Dipendenze runtime richieste (installate via `npm i -D ts-node typescript`
 * e `npm i @supabase/supabase-js` nel package root, oppure eseguendo dallo
 * scraper sub-package che le ha già):
 *   - @supabase/supabase-js
 *   - ts-node (o tsx)
 *
 * Lo script opera in due fasi:
 *   1) DRY RUN: scansiona il DB, stampa un report dettagliato e non tocca nulla.
 *   2) Chiede conferma via readline. Se "yes" → soft-delete dei duplicati
 *      (is_active = false). I prodotti incompleti vengono solo segnalati,
 *      non eliminati: la loro correzione è un'azione manuale.
 */

import { createClient } from "@supabase/supabase-js";
import * as readline from "node:readline/promises";
import { stdin as input, stdout as output } from "node:process";

type Composition = { fiber: string; percentage: number }[] | null;

interface ProductRow {
  id: string;
  brand_id: string;
  name: string;
  slug: string;
  price: number | null;
  composition: Composition;
  ean_barcode: string | null;
  photo_urls: string[] | null;
  country_of_production: string | null;
  care_instructions: string | null;
  label_photo_url: string | null;
  affiliate_url: string | null;
  is_active: boolean;
  updated_at: string;
}

function normalizeName(name: string): string {
  return name.toLowerCase().trim().replace(/\s+/g, " ");
}

function isCompositionEmpty(c: Composition): boolean {
  if (c === null) return true;
  if (!Array.isArray(c)) return true;
  if (c.length === 0) return true;
  const totalPct = c.reduce((sum, f) => sum + (f?.percentage ?? 0), 0);
  return totalPct <= 0;
}

function isPriceMissing(price: number | null): boolean {
  return price === null || price <= 0;
}

// Ranking "più campi compilati = migliore". In caso di parità, vince
// l'updated_at più recente (vedi resolveDuplicateGroup).
function completenessScore(p: ProductRow): number {
  let s = 0;
  if (!isCompositionEmpty(p.composition)) s += 5;
  if (!isPriceMissing(p.price)) s += 3;
  if (p.ean_barcode) s += 2;
  if (p.photo_urls && p.photo_urls.length > 0) s += Math.min(5, p.photo_urls.length);
  if (p.country_of_production) s += 1;
  if (p.care_instructions) s += 1;
  if (p.label_photo_url) s += 1;
  if (p.affiliate_url) s += 1;
  if (p.is_active) s += 1;
  return s;
}

function resolveDuplicateGroup(group: ProductRow[]): { keep: ProductRow; drop: ProductRow[] } {
  const sorted = [...group].sort((a, b) => {
    const scoreDiff = completenessScore(b) - completenessScore(a);
    if (scoreDiff !== 0) return scoreDiff;
    return new Date(b.updated_at).getTime() - new Date(a.updated_at).getTime();
  });
  return { keep: sorted[0]!, drop: sorted.slice(1) };
}

async function main(): Promise<void> {
  const url = process.env.SUPABASE_URL;
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;

  if (!url || !key) {
    console.error("Env SUPABASE_URL e SUPABASE_SERVICE_ROLE_KEY obbligatorie.");
    process.exit(1);
  }

  const supabase = createClient(url, key, {
    auth: { autoRefreshToken: false, persistSession: false },
  });

  console.log("→ Fetching prodotti…");

  const { data: products, error } = await supabase
    .from("products")
    .select(
      "id, brand_id, name, slug, price, composition, ean_barcode, photo_urls, country_of_production, care_instructions, label_photo_url, affiliate_url, is_active, updated_at",
    )
    .eq("is_active", true);

  if (error) {
    console.error("Errore fetch products:", error.message);
    process.exit(1);
  }

  const rows = (products ?? []) as ProductRow[];
  console.log(`  ${rows.length} prodotti attivi trovati.\n`);

  // ── Duplicati: group by (brand_id, normalized_name) ─────────────
  const groups = new Map<string, ProductRow[]>();
  for (const p of rows) {
    const key = `${p.brand_id}::${normalizeName(p.name)}`;
    const arr = groups.get(key);
    if (arr) arr.push(p);
    else groups.set(key, [p]);
  }

  const duplicateGroups = Array.from(groups.values()).filter((g) => g.length > 1);
  const toDelete: { keep: ProductRow; drop: ProductRow[] }[] = duplicateGroups.map(
    resolveDuplicateGroup,
  );
  const totalToDelete = toDelete.reduce((sum, g) => sum + g.drop.length, 0);

  // ── Incompleti ───────────────────────────────────────────────────
  const incomplete = rows.filter(
    (p) => isCompositionEmpty(p.composition) || isPriceMissing(p.price),
  );

  // ── Report ───────────────────────────────────────────────────────
  console.log("════════════════════════════════════════════");
  console.log(" CLEANUP REPORT (dry run)");
  console.log("════════════════════════════════════════════");
  console.log(
    `DUPLICATI:  ${duplicateGroups.length} gruppi trovati, ${totalToDelete} prodotti da soft-eliminare`,
  );
  console.log(`INCOMPLETI: ${incomplete.length} prodotti (solo segnalazione, non verranno toccati)`);
  console.log("────────────────────────────────────────────\n");

  if (toDelete.length > 0) {
    console.log("DETTAGLIO DUPLICATI:");
    for (const { keep, drop } of toDelete) {
      console.log(`\n  Gruppo: "${keep.name}"`);
      console.log(`    ✓ KEEP  ${keep.id}  score=${completenessScore(keep)}  slug=${keep.slug}`);
      for (const d of drop) {
        console.log(
          `    ✗ DROP  ${d.id}  score=${completenessScore(d)}  slug=${d.slug}`,
        );
      }
    }
    console.log();
  }

  if (incomplete.length > 0) {
    console.log("DETTAGLIO INCOMPLETI:");
    for (const p of incomplete) {
      const issues: string[] = [];
      if (isCompositionEmpty(p.composition)) issues.push("composition vuota");
      if (isPriceMissing(p.price)) issues.push("price mancante");
      console.log(`  • ${p.id}  "${p.name}"  [${issues.join(", ")}]`);
    }
    console.log();
  }

  if (totalToDelete === 0) {
    console.log("Nessun duplicato da eliminare. Esco.");
    return;
  }

  // ── Conferma interattiva ─────────────────────────────────────────
  const rl = readline.createInterface({ input, output });
  const answer = (
    await rl.question(
      `Procedere con il soft-delete di ${totalToDelete} prodotti duplicati? (yes/no) `,
    )
  )
    .trim()
    .toLowerCase();
  rl.close();

  if (answer !== "yes" && answer !== "y") {
    console.log("Annullato. Nessuna modifica applicata.");
    return;
  }

  // ── Esecuzione: soft delete ──────────────────────────────────────
  const ids = toDelete.flatMap((g) => g.drop.map((d) => d.id));
  console.log(`\n→ Soft-delete di ${ids.length} prodotti in corso…`);

  const { error: updateError, count } = await supabase
    .from("products")
    .update({ is_active: false })
    .in("id", ids);

  if (updateError) {
    console.error("Errore durante il soft-delete:", updateError.message);
    process.exit(1);
  }

  console.log(`✓ Completato. Righe aggiornate: ${count ?? ids.length}.`);
}

main().catch((err) => {
  console.error("Errore inatteso:", err);
  process.exit(1);
});
