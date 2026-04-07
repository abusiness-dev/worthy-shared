import type { Gender, VerificationStatus, Verdict } from "./enums";
import type { Brand } from "./brand";
import type { Category } from "./category";
import type { MattiaReview } from "./review";

export interface Composition {
  fiber: string;
  percentage: number;
}

export interface Product {
  id: string;
  ean_barcode: string | null;
  brand_id: string;
  category_id: string;
  name: string;
  slug: string;
  gender: Gender;
  price: number;
  composition: Composition[];
  country_of_production: string | null;
  care_instructions: string | null;
  photo_urls: string[];
  label_photo_url: string | null;
  worthy_score: number;
  score_composition: number;
  score_qpr: number;
  score_fit: number | null;
  score_durability: number | null;
  verdict: Verdict;
  community_score: number | null;
  community_votes_count: number;
  verification_status: VerificationStatus;
  scan_count: number;
  contributed_by: string | null;
  affiliate_url: string | null;
  is_active: boolean;
  created_at: string;
  updated_at: string;
}

export interface ProductInsert {
  ean_barcode?: string | null;
  brand_id: string;
  category_id: string;
  name: string;
  slug: string;
  gender?: Gender;
  price: number;
  composition: Composition[];
  country_of_production?: string | null;
  care_instructions?: string | null;
  photo_urls?: string[];
  label_photo_url?: string | null;
  contributed_by?: string | null;
  affiliate_url?: string | null;
}

export interface ProductUpdate {
  ean_barcode?: string | null;
  brand_id?: string;
  category_id?: string;
  name?: string;
  gender?: Gender;
  price?: number;
  composition?: Composition[];
  country_of_production?: string | null;
  care_instructions?: string | null;
  photo_urls?: string[];
  label_photo_url?: string | null;
  worthy_score?: number;
  score_composition?: number;
  score_qpr?: number;
  score_fit?: number | null;
  score_durability?: number | null;
  verdict?: Verdict;
  community_score?: number | null;
  community_votes_count?: number;
  verification_status?: VerificationStatus;
  scan_count?: number;
  affiliate_url?: string | null;
  is_active?: boolean;
}

export interface ProductWithRelations extends Product {
  brand: Brand;
  category: Category;
  mattia_review: MattiaReview | null;
}
