// Tipi I/O della edge function `match-product-by-tag` (fallback fuzzy
// quando lo scanner barcode di worthy-app non trova il prodotto).

export interface MatchProductByTagInput {
  image_base64: string;
  media_type?: "image/jpeg" | "image/png" | "image/webp" | "image/gif";
}

export interface PhotoSearchDetected {
  brand: string;
  name: string;
  confidence: number;
}

export interface PhotoSearchCandidate {
  product_id: string;
  slug: string;
  name: string;
  brand_name: string;
  photo_url: string | null;
  sim: number;
}

export interface MatchProductByTagOutput {
  detected: PhotoSearchDetected;
  candidates: PhotoSearchCandidate[];
  _meta?: { cached?: boolean; model?: string };
}
