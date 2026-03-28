function sigmoid(x: number): number {
  return 100 / (1 + Math.exp(-0.05 * (x - 100)));
}

export function calculateQPR(
  compScore: number,
  price: number,
  avgCatScore: number,
  avgCatPrice: number,
): number {
  if (price <= 0 || avgCatPrice <= 0 || avgCatScore <= 0) return 50;

  const raw = (compScore / price) / (avgCatScore / avgCatPrice) * 100;

  return Math.round(Math.min(100, Math.max(0, sigmoid(raw))));
}
