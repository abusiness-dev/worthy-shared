import type { MarketSegment } from "../types";

export const LAUNCH_BRANDS = [
  { name: "Zara", slug: "zara", originCountry: "Spagna", marketSegment: "fast" as MarketSegment },
  { name: "H&M", slug: "h-and-m", originCountry: "Svezia", marketSegment: "fast" as MarketSegment },
  { name: "Uniqlo", slug: "uniqlo", originCountry: "Giappone", marketSegment: "fast" as MarketSegment },
  { name: "Shein", slug: "shein", originCountry: "Cina", marketSegment: "ultra_fast" as MarketSegment },
  { name: "Bershka", slug: "bershka", originCountry: "Spagna", marketSegment: "fast" as MarketSegment },
  { name: "Pull&Bear", slug: "pull-and-bear", originCountry: "Spagna", marketSegment: "fast" as MarketSegment },
  { name: "Stradivarius", slug: "stradivarius", originCountry: "Spagna", marketSegment: "fast" as MarketSegment },
  { name: "Primark", slug: "primark", originCountry: "Irlanda", marketSegment: "ultra_fast" as MarketSegment },
  { name: "ASOS", slug: "asos", originCountry: "UK", marketSegment: "fast" as MarketSegment },
  { name: "Mango", slug: "mango", originCountry: "Spagna", marketSegment: "fast" as MarketSegment },
  { name: "COS", slug: "cos", originCountry: "Svezia", marketSegment: "premium_fast" as MarketSegment },
  { name: "Massimo Dutti", slug: "massimo-dutti", originCountry: "Spagna", marketSegment: "premium_fast" as MarketSegment },
] as const;
