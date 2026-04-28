function sigmoid(x: number): number {
  return 100 / (1 + Math.exp(-0.05 * (x - 100)));
}

// QPR: confronta il rapporto qualità/prezzo del prodotto con un riferimento.
// Il riferimento è oggi la median del cluster (categoria × market_segment del
// brand), con fallback alla median della categoria se il cluster ha < 3
// prodotti. I parametri `refScore` e `refPrice` sono risolti dal chiamante.
export function calculateQPR(
  compScore: number,
  price: number,
  refScore: number,
  refPrice: number,
): number {
  if (price <= 0 || refPrice <= 0 || refScore <= 0) return 50;

  const raw = (compScore / price) / (refScore / refPrice) * 100;

  return Math.round(Math.min(100, Math.max(0, sigmoid(raw))));
}
