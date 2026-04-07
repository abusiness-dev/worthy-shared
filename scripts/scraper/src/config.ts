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
  { slug: "t-shirt", name: "T-Shirt" },
  { slug: "felpe", name: "Felpe" },
  { slug: "jeans", name: "Jeans" },
  { slug: "pantaloni", name: "Pantaloni" },
  { slug: "giacche", name: "Giacche" },
  { slug: "camicie", name: "Camicie" },
];

// Populated at runtime from Supabase
export const brandIdMap: Record<string, string> = {};
export const categoryIdMap: Record<string, string> = {};
export const categoryAvgMap: Record<
  string,
  { avgPrice: number; avgScore: number }
> = {};

export async function loadDbMappings(): Promise<void> {
  const { data: brands } = await supabase.from("brands").select("id, slug");
  if (brands) {
    for (const b of brands) {
      brandIdMap[b.slug] = b.id;
    }
  }

  const { data: categories } = await supabase
    .from("categories")
    .select("id, slug, avg_price, avg_composition_score");
  if (categories) {
    for (const c of categories) {
      categoryIdMap[c.slug] = c.id;
      categoryAvgMap[c.slug] = {
        avgPrice: Number(c.avg_price) || 25,
        avgScore: Number(c.avg_composition_score) || 50,
      };
    }
  }

  console.log(
    `Loaded ${Object.keys(brandIdMap).length} brands, ${Object.keys(categoryIdMap).length} categories`
  );
}
