import shared from "@worthy/shared";
const { calculateCompositionScore, calculateQPR, calculateWorthyScore, validateComposition } = shared;
import {
  brandIdMap,
  categoryIdMap,
  categoryAvgMap,
} from "../config.js";
import type { RawProduct, ScrapedProduct } from "../types.js";
import { parseComposition } from "../utils/composition-parser.js";
import { generateSlug } from "../utils/slug.js";

export function processProduct(
  raw: RawProduct,
  brandSlug: string
): ScrapedProduct | null {
  // 1. Parse composition
  const composition = parseComposition(raw.compositionText);
  if (composition.length === 0) {
    console.warn(`  [SKIP] No composition parsed for "${raw.name}"`);
    return null;
  }

  // 2. Validate composition
  const compValidation = validateComposition(composition);
  if (!compValidation.valid) {
    console.warn(
      `  [SKIP] Invalid composition for "${raw.name}": ${compValidation.errors.join(", ")}`
    );
    return null;
  }

  // 3. Resolve brand and category IDs
  const brandId = brandIdMap[brandSlug];
  const categoryId = categoryIdMap[raw.category];
  if (!brandId) {
    console.warn(`  [SKIP] Unknown brand slug: ${brandSlug}`);
    return null;
  }
  if (!categoryId) {
    console.warn(`  [SKIP] Unknown category slug: ${raw.category}`);
    return null;
  }

  // 4. Calculate scores
  const scoreComposition = calculateCompositionScore(composition);

  const catAvg = categoryAvgMap[raw.category] ?? {
    avgPrice: 25,
    avgScore: 50,
  };
  const scoreQpr = calculateQPR(
    scoreComposition,
    raw.price,
    catAvg.avgScore || 50,
    catAvg.avgPrice || 25
  );

  const { score: worthyScore, verdict } = calculateWorthyScore({
    compositionScore: scoreComposition,
    qprScore: scoreQpr,
  });

  // 5. Generate slug
  const slug = generateSlug(raw.name, brandSlug);

  return {
    name: raw.name,
    slug,
    brandSlug,
    brandId,
    categorySlug: raw.category,
    categoryId,
    gender: raw.gender,
    price: raw.price,
    composition,
    photoUrls: raw.imageUrls,
    countryOfProduction: raw.countryOfProduction ?? null,
    productUrl: raw.productUrl,
    scoreComposition,
    scoreQpr,
    worthyScore,
    verdict,
  };
}
