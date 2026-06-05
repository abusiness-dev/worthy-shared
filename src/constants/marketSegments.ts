import type { MarketSegment } from "../types";

export const MARKET_SEGMENTS = [
  { id: "ultra_fast" as MarketSegment,   label: "Ultra Fast Fashion" },
  { id: "fast_fashion" as MarketSegment, label: "Fast Fashion" },
  { id: "premium" as MarketSegment,      label: "Premium" },
  { id: "maison" as MarketSegment,       label: "Maison" },
] as const;

// Scala ordinale dei segmenti: ultra_fast < fast_fashion < premium < maison.
// Usata dal matching delle alternative per misurare la "distanza di posizionamento".
export const SEGMENT_ORDER: Record<MarketSegment, number> = {
  ultra_fast: 0,
  fast_fashion: 1,
  premium: 2,
  maison: 3,
};

// Distanza ordinale tra due segmenti. null se uno dei due è ignoto.
export function segmentDistance(
  a: MarketSegment | null | undefined,
  b: MarketSegment | null | undefined,
): number | null {
  if (!a || !b) return null;
  return Math.abs(SEGMENT_ORDER[a] - SEGMENT_ORDER[b]);
}

// Due segmenti sono compatibili se uguali o adiacenti di al più `maxDistance`
// livelli. Segmento ignoto (es. record storici) ⇒ compatibile: non blocca il
// matching (viene semmai penalizzato nel ranking).
export function isSegmentAdjacent(
  a: MarketSegment | null | undefined,
  b: MarketSegment | null | undefined,
  maxDistance = 1,
): boolean {
  const d = segmentDistance(a, b);
  if (d === null) return true;
  return d <= maxDistance;
}
