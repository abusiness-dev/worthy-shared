import type { MarketSegment } from "../types";

export const MARKET_SEGMENTS = [
  { id: "ultra_fast" as MarketSegment,   label: "Ultra Fast Fashion" },
  { id: "fast_fashion" as MarketSegment, label: "Fast Fashion" },
  { id: "premium" as MarketSegment,      label: "Premium" },
  { id: "maison" as MarketSegment,       label: "Maison" },
] as const;
