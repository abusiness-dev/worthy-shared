import { supabase } from "../config.js";
import type { ScrapedProduct } from "../types.js";

export async function insertProduct(product: ScrapedProduct): Promise<boolean> {
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
      photo_urls: product.photoUrls,
      affiliate_url: product.productUrl,
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
    source: "scraper",
  });

  return true;
}

export async function insertBatch(products: ScrapedProduct[]): Promise<{
  inserted: number;
  skipped: number;
}> {
  let inserted = 0;
  let skipped = 0;

  for (const product of products) {
    const ok = await insertProduct(product);
    if (ok) {
      inserted++;
    } else {
      skipped++;
    }
  }

  return { inserted, skipped };
}
