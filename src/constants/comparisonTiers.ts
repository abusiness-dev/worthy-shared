import type { ComparisonTier } from "../types";

// Leghe di confronto del brand — asse di clustering del QPR (categoria × lega).
// Mantenute come dato editabile nel DB (tabella comparison_tiers); qui ne
// replichiamo l'ordinamento per il matching delle alternative lato client.
export const COMPARISON_TIERS = [
  { id: "mass_market" as ComparisonTier, label: "Mass-market" },
  { id: "premium" as ComparisonTier,     label: "Premium / Contemporary" },
  { id: "luxury" as ComparisonTier,      label: "Luxury" },
  { id: "maison" as ComparisonTier,      label: "Maison" },
] as const;

// Scala ordinale: mass_market < premium < luxury < maison.
// Usata dal matching delle alternative per la "distanza di posizionamento".
export const COMPARISON_TIER_ORDER: Record<ComparisonTier, number> = {
  mass_market: 0,
  premium: 1,
  luxury: 2,
  maison: 3,
};

// Distanza ordinale tra due leghe. null se una delle due è ignota.
export function tierDistance(
  a: ComparisonTier | null | undefined,
  b: ComparisonTier | null | undefined,
): number | null {
  if (!a || !b) return null;
  return Math.abs(COMPARISON_TIER_ORDER[a] - COMPARISON_TIER_ORDER[b]);
}

// Due leghe sono compatibili se uguali o adiacenti di al più `maxDistance`
// livelli. Lega ignota (es. record storici) ⇒ compatibile: non blocca il
// matching (viene semmai penalizzata nel ranking).
export function isTierAdjacent(
  a: ComparisonTier | null | undefined,
  b: ComparisonTier | null | undefined,
  maxDistance = 1,
): boolean {
  const d = tierDistance(a, b);
  if (d === null) return true;
  return d <= maxDistance;
}

// Prossimità di lega [0..1]. Lega ignota ⇒ neutro (0.5). Max distanza = 3.
export function tierProximity(
  a: ComparisonTier | null | undefined,
  b: ComparisonTier | null | undefined,
): number {
  const d = tierDistance(a, b);
  if (d === null) return 0.5;
  return 1 - d / 3;
}
