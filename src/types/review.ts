export interface MattiaReview {
  id: string;
  product_id: string;
  video_url: string;
  video_thumbnail_url: string | null;
  score_adjustment: number;
  review_text: string | null;
  published_at: string;
}

export interface ReviewInsert {
  product_id: string;
  video_url: string;
  video_thumbnail_url?: string | null;
  score_adjustment: number;
  review_text?: string | null;
}
