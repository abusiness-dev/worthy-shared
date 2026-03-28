import type { DuplicateStatus } from "./enums";

export interface ProductDuplicate {
  id: string;
  product_id: string;
  duplicate_of: string;
  similarity_score: number;
  status: DuplicateStatus;
  resolved_by: string | null;
  created_at: string;
  resolved_at: string | null;
}
