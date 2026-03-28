import type { MarketSegment } from "../types";

export const MARKET_SEGMENTS = [
  { id: "ultra_fast" as MarketSegment, label: "Ultra Fast Fashion" },
  { id: "fast" as MarketSegment, label: "Fast Fashion" },
  { id: "premium_fast" as MarketSegment, label: "Premium Fast Fashion" },
  { id: "mid_range" as MarketSegment, label: "Mid Range" },
] as const;
