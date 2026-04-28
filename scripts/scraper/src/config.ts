import "dotenv/config";
import { createClient } from "@supabase/supabase-js";
import type { BrandConfig, CategoryConfig } from "./types.js";

const supabaseUrl = process.env.SUPABASE_URL;
const supabaseKey = process.env.SUPABASE_SERVICE_ROLE_KEY;

if (!supabaseUrl || !supabaseKey) {
  throw new Error(
    "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY. Copy .env.example to .env and fill in your values."
  );
}

export const supabase = createClient(supabaseUrl, supabaseKey);

export const BRANDS: Record<string, BrandConfig> = {
  zara: { slug: "zara", name: "Zara", baseUrl: "https://www.zara.com/it/it" },
  hm: { slug: "h-and-m", name: "H&M", baseUrl: "https://www2.hm.com/it_it" },
  uniqlo: {
    slug: "uniqlo",
    name: "Uniqlo",
    baseUrl: "https://www.uniqlo.com/it/it",
  },
  cos: { slug: "cos", name: "COS", baseUrl: "https://www.cos.com/it_it" },
  "massimo-dutti": {
    slug: "massimo-dutti",
    name: "Massimo Dutti",
    baseUrl: "https://www.massimodutti.com/it",
  },
};

export const CATEGORIES: CategoryConfig[] = [
  // Base (stesse di Phase 1)
  { slug: "t-shirt", name: "T-Shirt" },
  { slug: "felpe", name: "Felpe" },
  { slug: "jeans", name: "Jeans" },
  { slug: "pantaloni", name: "Pantaloni" },
  { slug: "giacche", name: "Giacche" },
  { slug: "camicie", name: "Camicie" },
  // Estese (listing path dedicati Uniqlo — sub-categorie via refineCategory)
  { slug: "polo", name: "Polo" },
  { slug: "shorts", name: "Shorts" },
  { slug: "intimo", name: "Intimo" },
  { slug: "top-sportivo", name: "Top sportivi" },
  { slug: "canotta", name: "Canotte" },
  { slug: "leggings", name: "Leggings" },
];

// Populated at runtime from Supabase
export const brandIdMap: Record<string, string> = {};
export const brandSegmentMap: Record<string, string> = {}; // brandSlug → market_segment
export const categoryIdMap: Record<string, string> = {};

// Riferimenti del QPR cluster-based: median di (categorySlug × market_segment).
// Fallback per categoria quando il cluster ha < 3 prodotti.
export const categoryClusterMap: Record<
  string, // chiave: `${categorySlug}::${market_segment}`
  { medianPrice: number; medianScore: number; productCount: number }
> = {};
export const categoryFallbackMap: Record<
  string, // categorySlug
  { medianPrice: number; medianScore: number }
> = {};

export function clusterKey(categorySlug: string, segment: string): string {
  return `${categorySlug}::${segment}`;
}

export async function loadDbMappings(): Promise<void> {
  const { data: brands } = await supabase
    .from("brands")
    .select("id, slug, market_segment");
  if (brands) {
    for (const b of brands) {
      brandIdMap[b.slug] = b.id;
      if (b.market_segment) brandSegmentMap[b.slug] = b.market_segment;
    }
  }

  const { data: categories } = await supabase
    .from("categories")
    .select("id, slug, median_price, median_composition_score");
  if (categories) {
    for (const c of categories) {
      categoryIdMap[c.slug] = c.id;
      categoryFallbackMap[c.slug] = {
        medianPrice: Number(c.median_price) || 25,
        medianScore: Number(c.median_composition_score) || 50,
      };
    }
  }

  // Mappa slug → id (inverso) per il join in cluster aggregates
  const idToSlug: Record<string, string> = {};
  for (const [slug, id] of Object.entries(categoryIdMap)) idToSlug[id] = slug;

  const { data: aggregates } = await supabase
    .from("category_segment_aggregates")
    .select("category_id, market_segment, median_price, median_composition_score, product_count");
  if (aggregates) {
    for (const a of aggregates) {
      const slug = idToSlug[a.category_id];
      if (!slug) continue;
      categoryClusterMap[clusterKey(slug, a.market_segment)] = {
        medianPrice: Number(a.median_price) || 25,
        medianScore: Number(a.median_composition_score) || 50,
        productCount: Number(a.product_count) || 0,
      };
    }
  }

  console.log(
    `Loaded ${Object.keys(brandIdMap).length} brands, ${Object.keys(categoryIdMap).length} categories, ${Object.keys(categoryClusterMap).length} cluster aggregates`
  );
}
