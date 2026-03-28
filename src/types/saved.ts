export interface SavedProduct {
  id: string;
  user_id: string;
  product_id: string;
  created_at: string;
}

export interface SavedComparison {
  id: string;
  user_id: string;
  product_ids: string[];
  title: string;
  created_at: string;
}
