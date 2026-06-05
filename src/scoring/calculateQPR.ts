// Indice di qualità composito — UNICA fonte di verità lato client, allineato a
// compute_quality_index (SQL): 2/3 composition + 1/3 manufacturing, con
// rinormalizzazione su 0.75. Se manufacturing manca, collassa su composition.
//   (comp*0.50 + manuf*0.25) / 0.75 = (2*comp + manuf) / 3
export function computeQualityIndex(
  compScore: number,
  manufScore?: number | null,
): number {
  if (manufScore == null) return compScore;
  return (compScore * 0.5 + manufScore * 0.25) / 0.75;
}

// Sigmoid centrata in 100, pendenza 0.025 (curva morbida, allineata a SQL v3+).
function sigmoid(x: number): number {
  return 100 / (1 + Math.exp(-0.025 * (x - 100)));
}

// QPR cluster-based — allineato 1:1 a calculate_qpr_cluster (SQL v6).
//
// Confronta il quality_index/prezzo del prodotto con il riferimento del cluster
// (categoria × comparison_tier del brand), risolto dal chiamante. Il riferimento
// del cluster è la median del quality_index quando disponibile; in fallback la
// median di categoria o la media. La risoluzione del riferimento e la fallback
// chain vivono lato SQL: qui calcoliamo SOLO la matematica, dato il riferimento.
//
//   quality_idx = computeQualityIndex(compScore, manufScore)
//   raw_qpr     = (quality_idx / price) / (refQuality / refPrice) * 100
//   qpr         = round(sigmoid(raw_qpr))                       // coeff 0.025
//   bonus       = (manufScore - refManufScore) * 0.3            // se entrambi noti
//   return clamp(15, 95, qpr + round(bonus))
//
// Edge case: price/refPrice/refQuality <= 0 ⇒ 50 (neutro).
//
// I parametri 5° e 6° (manufScore, refManufScore) sono opzionali: omettendoli la
// firma legacy a 4 argomenti resta valida (quality_index = composition, nessun
// bonus), con la sola differenza di curva/clamp rispetto alla versione precedente.
export function calculateQPR(
  compScore: number,
  price: number,
  refQuality: number,
  refPrice: number,
  manufScore?: number | null,
  refManufScore?: number | null,
): number {
  if (price <= 0 || refPrice <= 0 || refQuality <= 0) return 50;

  const qualityIdx = computeQualityIndex(compScore, manufScore);
  const raw = (qualityIdx / price) / (refQuality / refPrice) * 100;
  const qpr = Math.round(sigmoid(raw));

  let bonus = 0;
  if (manufScore != null && refManufScore != null) {
    bonus = (manufScore - refManufScore) * 0.3;
  }

  return Math.min(95, Math.max(15, qpr + Math.round(bonus)));
}
