import { supabase } from "../config.js";
import type { ScrapedProduct } from "../types.js";

export interface InsertOptions {
  source?: string;
  /**
   * Disambiguator opzionale: se l'insert fallisce per slug duplicato (ad es.
   * varianti tipografiche dello stesso name che slugify normalizza identiche),
   * il nome viene suffissato con questo valore e l'insert ritentato.
   */
  slugDisambiguator?: string;
}

export async function insertProduct(
  product: ScrapedProduct,
  options: InsertOptions | string = {}
): Promise<boolean> {
  // Backward-compat: il vecchio signature accettava `source` come secondo arg.
  const opts: InsertOptions = typeof options === "string" ? { source: options } : options;
  const source = opts.source ?? "scraper";
  // Dedup preventiva per affiliate_url: lo stesso SKU può comparire su più path
  // listing (es. una maglia 'Maglione' sia in /men/jumpers che in /men/innerwear).
  const { data: existing } = await supabase
    .from("products")
    .select("id")
    .eq("affiliate_url", product.productUrl)
    .maybeSingle();
  if (existing) {
    console.warn(`  [DUP-URL] "${product.name}" already in DB, skip`);
    return false;
  }

  const { data, error } = await supabase
    .from("products")
    .insert({
      brand_id: product.brandId,
      category_id: product.categoryId,
      name: product.name,
      slug: product.slug,
      gender: product.gender,
      price: product.price,
      composition: product.composition,
      country_of_production: product.countryOfProduction,
      spinning_location: product.spinningLocation,
      weaving_location: product.weavingLocation,
      dyeing_location: product.dyeingLocation,
      country_of_production_iso2: product.countryOfProductionIso2,
      spinning_iso2: product.spinningIso2,
      weaving_iso2: product.weavingIso2,
      dyeing_iso2: product.dyeingIso2,
      photo_urls: product.photoUrls,
      affiliate_url: product.productUrl,
      ean_barcode: product.eanBarcode,
      worthy_score: product.worthyScore,
      score_composition: product.scoreComposition,
      score_qpr: product.scoreQpr,
      verdict: product.verdict,
      verification_status: "unverified",
    })
    .select("id")
    .single();

  if (error) {
    if (error.code === "23505") {
      // Retry-on-slug-collision: se l'errore è sul vincolo UNIQUE(slug) e abbiamo
      // un disambiguator (es. SKU/colorId estratto dall'URL), suffissiamo il nome
      // e ricostruiamo lo slug, poi ritentiamo una volta.
      if (opts.slugDisambiguator && !product.slug.includes(opts.slugDisambiguator)) {
        const disambiguatedName = `${product.name} ${opts.slugDisambiguator}`;
        const disambiguatedSlug = `${product.slug}-${opts.slugDisambiguator.toLowerCase().replace(/[^a-z0-9]+/g, "-")}`;
        console.warn(`  [RETRY-SLUG] "${product.name}" collide, retry come "${disambiguatedName}"`);
        return insertProduct(
          { ...product, name: disambiguatedName, slug: disambiguatedSlug },
          { source, slugDisambiguator: undefined }
        );
      }
      console.warn(`  [DUP] Duplicate slug for "${product.name}", skipping`);
      return false;
    }
    console.error(`  [ERR] Insert failed for "${product.name}":`, error.message);
    return false;
  }

  // Insert price history
  await supabase.from("price_history").insert({
    product_id: data.id,
    price: product.price,
    source,
  });

  // v2 link tables (best-effort: errori non bloccano l'insert principale).
  // Il trigger trg_pc_recalc_v2 ricalcola automaticamente score_breakdown
  // ad ogni insert qui.
  await persistV2Links(data.id, product);

  return true;
}

async function persistV2Links(productId: string, product: ScrapedProduct): Promise<void> {
  if (product.certifications.length > 0) {
    const rows = product.certifications.map((cid) => ({
      product_id: productId,
      certification_id: cid,
    }));
    const { error } = await supabase
      .from("product_certifications")
      .upsert(rows, { onConflict: "product_id,certification_id" });
    if (error) console.warn(`  [V2-WARN] product_certifications for "${product.name}":`, error.message);
  }
}

export async function insertBatch(
  products: ScrapedProduct[],
  options: InsertOptions | string = {}
): Promise<{
  inserted: number;
  skipped: number;
}> {
  let inserted = 0;
  let skipped = 0;

  for (const product of products) {
    const ok = await insertProduct(product, options);
    if (ok) {
      inserted++;
    } else {
      skipped++;
    }
  }

  return { inserted, skipped };
}
