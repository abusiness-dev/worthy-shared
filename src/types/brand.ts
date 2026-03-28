import type { MarketSegment } from "./enums";

export interface Brand {
  id: string;
  name: string;
  slug: string;
  logo_url: string | null;
  description: string | null;
  origin_country: string | null;
  market_segment: MarketSegment;
  avg_worthy_score: number;
  product_count: number;
  total_scans: number;
  created_at: string;
}

export interface BrandWithStats extends Brand {
  top_category: string | null;
  best_product_name: string | null;
  worst_product_name: string | null;
}
