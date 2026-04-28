import { calculateQPR } from "../../calculateQPR";

// QPR lens (peso 20% del Worthy Score v2).
// Sigmoid del rapporto qualità/prezzo del prodotto rispetto al riferimento di
// cluster (categoria × market_segment del brand) con fallback alla median di
// categoria. I valori di riferimento sono risolti dal chiamante.
// Default 50 in edge case (price <= 0, dati riferimento mancanti). È sempre
// presente (mai null).
export function qprLens(
  compositionScore: number,
  price: number,
  refCompositionScore: number,
  refPrice: number,
): number {
  return calculateQPR(compositionScore, price, refCompositionScore, refPrice);
}
