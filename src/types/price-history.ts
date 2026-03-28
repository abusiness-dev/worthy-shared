import type { PriceSource } from "./enums";

export interface PriceHistory {
  id: string;
  product_id: string;
  price: number;
  recorded_at: string;
  source: PriceSource;
}
