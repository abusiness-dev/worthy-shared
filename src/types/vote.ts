export interface ProductVote {
  id: string;
  product_id: string;
  user_id: string;
  score: number;
  fit_score: number | null;
  durability_score: number | null;
  comment: string | null;
  created_at: string;
}

export interface VoteInsert {
  product_id: string;
  user_id: string;
  score: number;
  fit_score?: number | null;
  durability_score?: number | null;
  comment?: string | null;
}
