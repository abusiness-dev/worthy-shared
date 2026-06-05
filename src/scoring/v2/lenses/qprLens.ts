import { calculateQPR } from "../../calculateQPR";

// QPR lens (peso 25% del Worthy Score v2).
// Sigmoid del rapporto qualità/prezzo del prodotto rispetto al riferimento del
// cluster (categoria × comparison_tier del brand) con fallback alla median di
// categoria. Il riferimento (`refQuality`/`refPrice`, e opzionalmente
// `refManufacturing`) è risolto dal chiamante. Quando il manufacturing è noto sia
// per il prodotto sia per il cluster, calculateQPR applica il bonus additivo.
// Default 50 in edge case (price <= 0, dati riferimento mancanti). Sempre presente.
export function qprLens(
  compositionScore: number,
  price: number,
  refQuality: number,
  refPrice: number,
  manufacturingScore?: number | null,
  refManufacturing?: number | null,
): number {
  return calculateQPR(
    compositionScore,
    price,
    refQuality,
    refPrice,
    manufacturingScore,
    refManufacturing,
  );
}
