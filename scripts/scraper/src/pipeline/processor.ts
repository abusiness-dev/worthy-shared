import shared from "@worthy/shared";
const { calculateCompositionScore, calculateQPR, calculateWorthyScore, validateComposition } = shared;
import {
  brandIdMap,
  brandSegmentMap,
  categoryIdMap,
  categoryClusterMap,
  categoryFallbackMap,
  clusterKey,
} from "../config.js";
import type { RawProduct, ScrapedProduct } from "../types.js";
import { parseComposition } from "../utils/composition-parser.js";
import { generateSlug } from "../utils/slug.js";
import { normalizeCountry } from "../utils/country-normalizer.js";
import { extractV2Fields } from "../utils/pdp-extractor.js";

/**
 * Raffina la categoria dal path del listing in una sub-categoria DB più precisa
 * basandosi sul nome del prodotto. Se la sub-categoria non è presente nel DB
 * (categoryIdMap), si resta sulla categoria base.
 */
function refineCategory(
  name: string,
  baseCategory: string,
  gender: "uomo" | "donna" | "unisex"
): string {
  const n = name.toLowerCase();

  // Felpe (cattura "sweatshirt", "hoodie") — prima di pattern ambigui di maglieria.
  if (/felp.*cappuccio|hoodie|con cappuccio|hood.*sweatshirt|sweatshirt.*hood/.test(n)) return "felpa-cappuccio";
  if (/felp|sweatshirt/.test(n) && baseCategory === "felpe") return "felpa-girocollo";

  // Maglieria — cardigan/jumper/pullover/maglione/sweater
  if (/cardigan/.test(n)) return "cardigan";
  if (/maglione|pullover|jumper|sweater/.test(n)) return "maglione";
  // Pattern ambigui (henley/girocollo/crew-neck/knit) solo se base = maglieria,
  // altrimenti finirebbero a catturare anche t-shirt "Girocollo a maniche corte".
  if (baseCategory === "maglieria" && /henley|girocollo|crew.?neck|knit\b/.test(n)) return "maglione";

  // Outerwear — trench/peacoat/cappotto in priorità (anche dentro "giacche").
  if (/trench|impermeabile|mackintosh/.test(n)) return "trench";
  if (/piumin|down jacket|puffer/.test(n)) return "piumino";
  if (/parka/.test(n)) return "parka";
  if (/cappotto|peacoat|cabàn|caban|coat\b/.test(n) && (baseCategory === "cappotti" || baseCategory === "giacche")) return "cappotto";
  if (/bomber|blouson/.test(n)) return "bomber";
  if (/blazer/.test(n)) return "blazer";
  if (/giubbot|giubbin/.test(n) && (baseCategory === "giacche" || baseCategory === "cappotti")) return "giubbotto";
  if (/smanicato|gilet|waistcoat|vest|field jacket|giacca da lavoro/.test(n) && (baseCategory === "cappotti" || baseCategory === "giacche")) return "giubbotto";

  // Abiti / vestiti — gender-aware: SUITSUPPLY uomo = completo formale (abito);
  // BERSHKA donna = dress (vestito).
  if (baseCategory === "abiti") {
    return gender === "donna" ? "vestito" : "abito";
  }

  // Gonne — base BERSHKA "gonne".
  if (baseCategory === "gonne") return "gonna";

  // Top femminile (BERSHKA "top" + "altro" è prevalentemente top donna).
  if (baseCategory === "top" || baseCategory === "altro") {
    if (/canotta|tank top/.test(n)) return "canotta";
    if (/gilet|waistcoat|vest/.test(n)) return "giubbotto";
    if (/t-shirt|tee\b/.test(n)) return "t-shirt-basic";
    return "top";
  }

  // Pantaloni — shorts/jorts via nome (BERSHKA mette tanti shorts in "pantaloni").
  if (baseCategory === "pantaloni" && /shorts?\b|jorts?\b/.test(n)) return "shorts";
  if (/chinos?\b/.test(n)) return "chinos";
  if (/jogger|sweat.?pants|pantaloni da jogging/.test(n)) return "jogger";
  if (/cargo/.test(n)) return "cargo";
  if (/pantalon.*elegant|dress pant|tailored trousers/.test(n)) return "pantaloni-eleganti";

  // Jeans
  if (/slim.?fit/.test(n) && baseCategory === "jeans") return "jeans-slim";
  if (/wide.?leg|straight/.test(n) && baseCategory === "jeans") return "jeans-regular";

  // T-shirt
  if (/polo/.test(n)) return "polo";
  if (/oversiz|oversize/.test(n) && baseCategory === "t-shirt") return "t-shirt-oversize";

  // Scarpe (base = scarpe) — sotto-categorie via nome.
  if (baseCategory === "scarpe") {
    if (/trainer|sneaker/.test(n)) return "sneakers";
    if (/boot/.test(n)) return "stivali";
    if (/sandal|flip.?flop|infradito|slider sandal/.test(n)) return "sandali";
    return "scarpe-eleganti"; // ballerine, tacchi, mules, loafers, clogs, slingback
  }

  // Accessori — sotto-categorie per nome (priorità: borse prima di belt per
  // evitare che "belt-bag" finisca in cinture).
  if (baseCategory === "accessori") {
    if (/bag\b|backpack|tote\b|fanny pack|wallet|purse|crossbody|clutch/.test(n)) return "borse";
    if (/sock|tights\b/.test(n)) return "calzini";
    if (/scarf|bandana|foulard/.test(n)) return "sciarpe";
    if (/\bbelt\b|cintura/.test(n)) return "cinture";
    if (/beret|\bcap\b|\bhat\b|fedora|bucket\b/.test(n)) return "cappelli";
    return "accessori";
  }

  // Shorts sportivi — ovunque il nome lo dica.
  if (/shorts?.*sport|running short|sport short/.test(n)) return "shorts-sportivi";

  // Default by-base per categorie italiane non-slug del DB.
  if (baseCategory === "maglieria") return "maglione";
  if (baseCategory === "cappotti") return "cappotto";

  return baseCategory;
}

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

  // 3. Resolve brand ID + raffina categoria prima di risolvere il categoryId
  const brandId = brandIdMap[brandSlug];
  if (!brandId) {
    console.warn(`  [SKIP] Unknown brand slug: ${brandSlug}`);
    return null;
  }

  const refinedSlug = refineCategory(raw.name, raw.category, raw.gender);
  // Usa la sub-categoria solo se esiste nel DB; altrimenti ricade sulla base.
  const finalCategorySlug =
    categoryIdMap[refinedSlug] ? refinedSlug : raw.category;
  const categoryId = categoryIdMap[finalCategorySlug];
  if (!categoryId) {
    console.warn(`  [SKIP] Unknown category slug: ${raw.category}`);
    return null;
  }

  // 4. Calculate scores
  const scoreComposition = calculateCompositionScore(composition);

  // QPR cluster-based: median di (categoria × segmento brand). Fallback alla
  // median di categoria se il cluster ha < 3 prodotti o non esiste.
  const segment = brandSegmentMap[brandSlug];
  const cluster = segment
    ? categoryClusterMap[clusterKey(finalCategorySlug, segment)]
    : undefined;
  const useCluster = cluster && cluster.productCount >= 3;
  const fallback = categoryFallbackMap[finalCategorySlug] ?? {
    medianPrice: 25,
    medianScore: 50,
  };
  const ref = useCluster
    ? { medianPrice: cluster!.medianPrice, medianScore: cluster!.medianScore }
    : fallback;
  const scoreQpr = calculateQPR(
    scoreComposition,
    raw.price,
    ref.medianScore || 50,
    ref.medianPrice || 25
  );

  const { score: worthyScore, verdict } = calculateWorthyScore({
    compositionScore: scoreComposition,
    qprScore: scoreQpr,
  });

  // 5. Generate slug
  const slug = generateSlug(raw.name, brandSlug);

  // 6. v2 enrichments (best-effort)
  const v2 = extractV2Fields(
    raw.rawDescription,
    raw.compositionText,
    raw.countryOfProduction,
    raw.spinningLocation,
    raw.weavingLocation,
    raw.dyeingLocation,
  );

  return {
    name: raw.name,
    slug,
    brandSlug,
    brandId,
    categorySlug: finalCategorySlug,
    categoryId,
    gender: raw.gender,
    price: raw.price,
    composition,
    photoUrls: raw.imageUrls,
    countryOfProduction: raw.countryOfProduction ?? null,
    spinningLocation: raw.spinningLocation ?? null,
    weavingLocation: raw.weavingLocation ?? null,
    dyeingLocation: raw.dyeingLocation ?? null,
    countryOfProductionIso2: normalizeCountry(raw.countryOfProduction),
    spinningIso2: normalizeCountry(raw.spinningLocation),
    weavingIso2: normalizeCountry(raw.weavingLocation),
    dyeingIso2: normalizeCountry(raw.dyeingLocation),
    productUrl: raw.productUrl,
    scoreComposition,
    scoreQpr,
    worthyScore,
    verdict,
    eanBarcode: raw.eanBarcode ?? null,
    certifications: v2.certifications,
  };
}
