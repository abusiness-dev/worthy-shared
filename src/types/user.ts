import type { TrustLevel, UserRole } from "./enums";

export interface User {
  id: string;
  email: string;
  display_name: string | null;
  avatar_url: string | null;
  points: number;
  trust_level: TrustLevel;
  role: UserRole;
  products_contributed: number;
  products_verified: number;
  error_rate: number;
  streak_days: number;
  last_active_date: string | null;
  is_premium: boolean;
  premium_expires_at: string | null;
  onboarding_completed: boolean;
  created_at: string;
  updated_at: string;
}

export interface UserBrandPreference {
  id: string;
  user_id: string;
  brand_id: string;
  created_at: string;
}

export interface UserCategoryPreference {
  id: string;
  user_id: string;
  category_id: string;
  created_at: string;
}

export interface UserProfile
  extends Pick<
    User,
    | "id"
    | "display_name"
    | "avatar_url"
    | "points"
    | "trust_level"
    | "products_contributed"
    | "streak_days"
    | "is_premium"
  > {}
