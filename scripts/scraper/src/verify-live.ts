import { supabase } from "./config.js";

async function verify() {
  // 1. Check products have photo_urls
  const { data: withPhotos, count: withPhotosCount } = await supabase
    .from("products")
    .select("id", { count: "exact", head: true })
    .not("photo_urls", "eq", "{}");

  const { data: noPhotos, count: noPhotosCount } = await supabase
    .from("products")
    .select("id, name", { count: "exact" })
    .eq("photo_urls", "{}");

  console.log("=== VERIFICA DATI LIVE ===\n");
  console.log(`Prodotti con immagini: ${withPhotosCount}`);
  console.log(`Prodotti SENZA immagini: ${noPhotosCount}`);

  if (noPhotos?.length) {
    console.log("Esempi senza immagini:");
    for (const p of noPhotos.slice(0, 5)) {
      console.log(`  - ${p.name}`);
    }
  }

  // 2. Sample a few products and check image URLs respond
  console.log("\n--- Verifica URL immagini (5 prodotti random) ---");
  const { data: sample } = await supabase
    .from("products")
    .select("name, photo_urls, price, composition, worthy_score, verdict")
    .not("photo_urls", "eq", "{}")
    .limit(5);

  for (const p of sample || []) {
    const urls = p.photo_urls as string[];
    console.log(`\n  "${p.name}" | ${p.price}€ | score:${p.worthy_score} | ${p.verdict}`);
    console.log(`  Composizione: ${JSON.stringify(p.composition)}`);
    console.log(`  Immagini: ${urls.length}`);

    if (urls.length > 0) {
      try {
        const resp = await fetch(urls[0], { method: "HEAD" });
        const ct = resp.headers.get("content-type") || "";
        console.log(`  Prima immagine [${resp.status}] ${ct} → ${urls[0].substring(0, 80)}...`);
      } catch (e: any) {
        console.log(`  Prima immagine ERRORE: ${e.message}`);
      }
    }
  }

  // 3. Check data completeness
  console.log("\n--- Completezza dati ---");
  const checks = [
    { field: "name", label: "Nome" },
    { field: "price", label: "Prezzo" },
    { field: "composition", label: "Composizione" },
    { field: "worthy_score", label: "Score" },
    { field: "verdict", label: "Verdict" },
    { field: "brand_id", label: "Brand" },
    { field: "category_id", label: "Categoria" },
    { field: "slug", label: "Slug" },
  ];

  for (const check of checks) {
    const { count } = await supabase
      .from("products")
      .select("id", { count: "exact", head: true })
      .is(check.field, null);
    console.log(`  ${check.label}: ${count === 0 ? "✓ tutti compilati" : `⚠ ${count} mancanti`}`);
  }

  // 4. Check price_history
  const { count: priceHistoryCount } = await supabase
    .from("price_history")
    .select("id", { count: "exact", head: true });
  console.log(`\n  Price history: ${priceHistoryCount} record`);

  // 5. Summary
  console.log("\n=== RIEPILOGO ===");
  console.log(`Tutto è nel DB Supabase di PRODUZIONE (${process.env.SUPABASE_URL})`);
  console.log("I dati sono accessibili via API Supabase standard.");
  console.log("L'app dovrebbe mostrarli se query la tabella 'products'.");
}

verify().catch(console.error);
