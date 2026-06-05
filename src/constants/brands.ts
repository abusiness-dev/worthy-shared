import type { ComparisonTier, MarketSegment } from "../types";

// Brand di lancio. `marketSegment` è l'attributo legacy; `comparisonTier` è la
// lega di confronto che guida il QPR cluster-based (vedi comparisonTiers.ts).
// La fonte di verità completa del catalogo brand è il seed DB (migrations).
export const LAUNCH_BRANDS = [
  // Mass-market (fast / ultra fast fashion)
  { name: "Zara",          slug: "zara",          originCountry: "Spagna",    marketSegment: "fast_fashion" as MarketSegment, comparisonTier: "mass_market" as ComparisonTier },
  { name: "H&M",           slug: "h-and-m",       originCountry: "Svezia",    marketSegment: "fast_fashion" as MarketSegment, comparisonTier: "mass_market" as ComparisonTier },
  { name: "Uniqlo",        slug: "uniqlo",        originCountry: "Giappone",  marketSegment: "fast_fashion" as MarketSegment, comparisonTier: "mass_market" as ComparisonTier },
  { name: "Shein",         slug: "shein",         originCountry: "Cina",      marketSegment: "ultra_fast" as MarketSegment,   comparisonTier: "mass_market" as ComparisonTier },
  { name: "Bershka",       slug: "bershka",       originCountry: "Spagna",    marketSegment: "fast_fashion" as MarketSegment, comparisonTier: "mass_market" as ComparisonTier },
  { name: "Pull&Bear",     slug: "pull-and-bear", originCountry: "Spagna",    marketSegment: "fast_fashion" as MarketSegment, comparisonTier: "mass_market" as ComparisonTier },
  { name: "Stradivarius",  slug: "stradivarius",  originCountry: "Spagna",    marketSegment: "fast_fashion" as MarketSegment, comparisonTier: "mass_market" as ComparisonTier },
  { name: "Primark",       slug: "primark",       originCountry: "Irlanda",   marketSegment: "ultra_fast" as MarketSegment,   comparisonTier: "mass_market" as ComparisonTier },
  { name: "ASOS",          slug: "asos",          originCountry: "UK",        marketSegment: "fast_fashion" as MarketSegment, comparisonTier: "mass_market" as ComparisonTier },
  { name: "Mango",         slug: "mango",         originCountry: "Spagna",    marketSegment: "fast_fashion" as MarketSegment, comparisonTier: "mass_market" as ComparisonTier },

  // Premium / Contemporary
  { name: "COS",           slug: "cos",           originCountry: "Svezia",    marketSegment: "premium" as MarketSegment, comparisonTier: "premium" as ComparisonTier },
  { name: "Massimo Dutti", slug: "massimo-dutti", originCountry: "Spagna",    marketSegment: "premium" as MarketSegment, comparisonTier: "premium" as ComparisonTier },
  { name: "Suitsupply",    slug: "suitsupply",    originCountry: "Paesi Bassi", marketSegment: "premium" as MarketSegment, comparisonTier: "premium" as ComparisonTier },
  { name: "Lacoste",       slug: "lacoste",       originCountry: "Francia",   marketSegment: "premium" as MarketSegment, comparisonTier: "premium" as ComparisonTier },
  { name: "Ralph Lauren",  slug: "ralph-lauren",  originCountry: "USA",       marketSegment: "premium" as MarketSegment, comparisonTier: "premium" as ComparisonTier },
] as const;
