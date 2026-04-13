export type Json =
  | string
  | number
  | boolean
  | null
  | { [key: string]: Json | undefined }
  | Json[]

export type Database = {
  // Allows to automatically instantiate createClient with right options
  // instead of createClient<Database, { PostgrestVersion: 'XX' }>(URL, KEY)
  __InternalSupabase: {
    PostgrestVersion: "14.4"
  }
  public: {
    Tables: {
      audit_log: {
        Row: {
          action: Database["public"]["Enums"]["audit_action"]
          created_at: string
          id: string
          ip_address: unknown
          new_data: Json | null
          old_data: Json | null
          record_id: string
          table_name: string
          user_id: string | null
        }
        Insert: {
          action: Database["public"]["Enums"]["audit_action"]
          created_at?: string
          id?: string
          ip_address?: unknown
          new_data?: Json | null
          old_data?: Json | null
          record_id: string
          table_name: string
          user_id?: string | null
        }
        Update: {
          action?: Database["public"]["Enums"]["audit_action"]
          created_at?: string
          id?: string
          ip_address?: unknown
          new_data?: Json | null
          old_data?: Json | null
          record_id?: string
          table_name?: string
          user_id?: string | null
        }
        Relationships: [
          {
            foreignKeyName: "audit_log_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      badges: {
        Row: {
          benefit: string
          description: string
          icon: string
          id: string
          name: string
          points_required: number
        }
        Insert: {
          benefit: string
          description: string
          icon: string
          id: string
          name: string
          points_required?: number
        }
        Update: {
          benefit?: string
          description?: string
          icon?: string
          id?: string
          name?: string
          points_required?: number
        }
        Relationships: []
      }
      brands: {
        Row: {
          avg_worthy_score: number
          created_at: string
          description: string | null
          id: string
          logo_url: string | null
          market_segment: Database["public"]["Enums"]["market_segment"]
          name: string
          origin_country: string | null
          product_count: number
          slug: string
          total_scans: number
        }
        Insert: {
          avg_worthy_score?: number
          created_at?: string
          description?: string | null
          id?: string
          logo_url?: string | null
          market_segment: Database["public"]["Enums"]["market_segment"]
          name: string
          origin_country?: string | null
          product_count?: number
          slug: string
          total_scans?: number
        }
        Update: {
          avg_worthy_score?: number
          created_at?: string
          description?: string | null
          id?: string
          logo_url?: string | null
          market_segment?: Database["public"]["Enums"]["market_segment"]
          name?: string
          origin_country?: string | null
          product_count?: number
          slug?: string
          total_scans?: number
        }
        Relationships: []
      }
      categories: {
        Row: {
          avg_composition_score: number
          avg_price: number
          icon: string
          id: string
          name: string
          product_count: number
          slug: string
        }
        Insert: {
          avg_composition_score?: number
          avg_price?: number
          icon: string
          id?: string
          name: string
          product_count?: number
          slug: string
        }
        Update: {
          avg_composition_score?: number
          avg_price?: number
          icon?: string
          id?: string
          name?: string
          product_count?: number
          slug?: string
        }
        Relationships: []
      }
      daily_worthy: {
        Row: {
          created_at: string
          editorial_note: string | null
          featured_date: string
          id: string
          position: number
          product_id: string
        }
        Insert: {
          created_at?: string
          editorial_note?: string | null
          featured_date: string
          id?: string
          position?: number
          product_id: string
        }
        Update: {
          created_at?: string
          editorial_note?: string | null
          featured_date?: string
          id?: string
          position?: number
          product_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "daily_worthy_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "daily_worthy_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "trending_products"
            referencedColumns: ["product_id"]
          },
        ]
      }
      mattia_reviews: {
        Row: {
          id: string
          product_id: string
          published_at: string
          review_text: string | null
          score_adjustment: number
          video_thumbnail_url: string | null
          video_url: string
        }
        Insert: {
          id?: string
          product_id: string
          published_at?: string
          review_text?: string | null
          score_adjustment?: number
          video_thumbnail_url?: string | null
          video_url: string
        }
        Update: {
          id?: string
          product_id?: string
          published_at?: string
          review_text?: string | null
          score_adjustment?: number
          video_thumbnail_url?: string | null
          video_url?: string
        }
        Relationships: [
          {
            foreignKeyName: "mattia_reviews_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: true
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "mattia_reviews_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: true
            referencedRelation: "trending_products"
            referencedColumns: ["product_id"]
          },
        ]
      }
      price_history: {
        Row: {
          id: string
          price: number
          product_id: string
          recorded_at: string
          source: Database["public"]["Enums"]["price_source"]
        }
        Insert: {
          id?: string
          price: number
          product_id: string
          recorded_at?: string
          source?: Database["public"]["Enums"]["price_source"]
        }
        Update: {
          id?: string
          price?: number
          product_id?: string
          recorded_at?: string
          source?: Database["public"]["Enums"]["price_source"]
        }
        Relationships: [
          {
            foreignKeyName: "price_history_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "price_history_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "trending_products"
            referencedColumns: ["product_id"]
          },
        ]
      }
      product_duplicates: {
        Row: {
          created_at: string
          duplicate_of: string
          id: string
          product_id: string
          resolved_at: string | null
          resolved_by: string | null
          similarity_score: number
          status: Database["public"]["Enums"]["duplicate_status"]
        }
        Insert: {
          created_at?: string
          duplicate_of: string
          id?: string
          product_id: string
          resolved_at?: string | null
          resolved_by?: string | null
          similarity_score: number
          status?: Database["public"]["Enums"]["duplicate_status"]
        }
        Update: {
          created_at?: string
          duplicate_of?: string
          id?: string
          product_id?: string
          resolved_at?: string | null
          resolved_by?: string | null
          similarity_score?: number
          status?: Database["public"]["Enums"]["duplicate_status"]
        }
        Relationships: [
          {
            foreignKeyName: "product_duplicates_duplicate_of_fkey"
            columns: ["duplicate_of"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_duplicates_duplicate_of_fkey"
            columns: ["duplicate_of"]
            isOneToOne: false
            referencedRelation: "trending_products"
            referencedColumns: ["product_id"]
          },
          {
            foreignKeyName: "product_duplicates_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_duplicates_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "trending_products"
            referencedColumns: ["product_id"]
          },
          {
            foreignKeyName: "product_duplicates_resolved_by_fkey"
            columns: ["resolved_by"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      product_reports: {
        Row: {
          created_at: string
          description: string | null
          id: string
          product_id: string
          reason: Database["public"]["Enums"]["report_reason"]
          status: Database["public"]["Enums"]["report_status"]
          user_id: string
        }
        Insert: {
          created_at?: string
          description?: string | null
          id?: string
          product_id: string
          reason: Database["public"]["Enums"]["report_reason"]
          status?: Database["public"]["Enums"]["report_status"]
          user_id: string
        }
        Update: {
          created_at?: string
          description?: string | null
          id?: string
          product_id?: string
          reason?: Database["public"]["Enums"]["report_reason"]
          status?: Database["public"]["Enums"]["report_status"]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "product_reports_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_reports_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "trending_products"
            referencedColumns: ["product_id"]
          },
          {
            foreignKeyName: "product_reports_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      product_votes: {
        Row: {
          comment: string | null
          created_at: string
          durability_score: number | null
          fit_score: number | null
          id: string
          product_id: string
          score: number
          user_id: string
        }
        Insert: {
          comment?: string | null
          created_at?: string
          durability_score?: number | null
          fit_score?: number | null
          id?: string
          product_id: string
          score: number
          user_id: string
        }
        Update: {
          comment?: string | null
          created_at?: string
          durability_score?: number | null
          fit_score?: number | null
          id?: string
          product_id?: string
          score?: number
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "product_votes_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "product_votes_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "trending_products"
            referencedColumns: ["product_id"]
          },
          {
            foreignKeyName: "product_votes_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      products: {
        Row: {
          affiliate_url: string | null
          brand_id: string
          care_instructions: string | null
          category_id: string
          community_score: number | null
          community_votes_count: number
          composition: Json
          contributed_by: string | null
          country_of_production: string | null
          created_at: string
          ean_barcode: string | null
          gender: Database["public"]["Enums"]["gender"]
          id: string
          is_active: boolean
          label_photo_url: string | null
          name: string
          photo_urls: string[]
          price: number
          scan_count: number
          score_composition: number
          score_durability: number | null
          score_fit: number | null
          score_qpr: number
          slug: string
          updated_at: string
          verdict: Database["public"]["Enums"]["verdict"]
          verification_status: Database["public"]["Enums"]["verification_status"]
          worthy_score: number
        }
        Insert: {
          affiliate_url?: string | null
          brand_id: string
          care_instructions?: string | null
          category_id: string
          community_score?: number | null
          community_votes_count?: number
          composition: Json
          contributed_by?: string | null
          country_of_production?: string | null
          created_at?: string
          ean_barcode?: string | null
          gender?: Database["public"]["Enums"]["gender"]
          id?: string
          is_active?: boolean
          label_photo_url?: string | null
          name: string
          photo_urls?: string[]
          price: number
          scan_count?: number
          score_composition?: number
          score_durability?: number | null
          score_fit?: number | null
          score_qpr?: number
          slug: string
          updated_at?: string
          verdict?: Database["public"]["Enums"]["verdict"]
          verification_status?: Database["public"]["Enums"]["verification_status"]
          worthy_score?: number
        }
        Update: {
          affiliate_url?: string | null
          brand_id?: string
          care_instructions?: string | null
          category_id?: string
          community_score?: number | null
          community_votes_count?: number
          composition?: Json
          contributed_by?: string | null
          country_of_production?: string | null
          created_at?: string
          ean_barcode?: string | null
          gender?: Database["public"]["Enums"]["gender"]
          id?: string
          is_active?: boolean
          label_photo_url?: string | null
          name?: string
          photo_urls?: string[]
          price?: number
          scan_count?: number
          score_composition?: number
          score_durability?: number | null
          score_fit?: number | null
          score_qpr?: number
          slug?: string
          updated_at?: string
          verdict?: Database["public"]["Enums"]["verdict"]
          verification_status?: Database["public"]["Enums"]["verification_status"]
          worthy_score?: number
        }
        Relationships: [
          {
            foreignKeyName: "products_brand_id_fkey"
            columns: ["brand_id"]
            isOneToOne: false
            referencedRelation: "brand_rankings"
            referencedColumns: ["brand_id"]
          },
          {
            foreignKeyName: "products_brand_id_fkey"
            columns: ["brand_id"]
            isOneToOne: false
            referencedRelation: "brands"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "products_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "products_contributed_by_fkey"
            columns: ["contributed_by"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      saved_comparisons: {
        Row: {
          created_at: string
          id: string
          product_ids: string[]
          title: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          product_ids: string[]
          title: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          product_ids?: string[]
          title?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "saved_comparisons_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      saved_products: {
        Row: {
          created_at: string
          id: string
          product_id: string
          user_id: string
        }
        Insert: {
          created_at?: string
          id?: string
          product_id: string
          user_id: string
        }
        Update: {
          created_at?: string
          id?: string
          product_id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "saved_products_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "saved_products_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "trending_products"
            referencedColumns: ["product_id"]
          },
          {
            foreignKeyName: "saved_products_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      scan_history: {
        Row: {
          barcode: string
          created_at: string
          found: boolean
          id: string
          product_id: string | null
          scan_type: Database["public"]["Enums"]["scan_type"]
          user_id: string
        }
        Insert: {
          barcode: string
          created_at?: string
          found?: boolean
          id?: string
          product_id?: string | null
          scan_type: Database["public"]["Enums"]["scan_type"]
          user_id: string
        }
        Update: {
          barcode?: string
          created_at?: string
          found?: boolean
          id?: string
          product_id?: string | null
          scan_type?: Database["public"]["Enums"]["scan_type"]
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "scan_history_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "products"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "scan_history_product_id_fkey"
            columns: ["product_id"]
            isOneToOne: false
            referencedRelation: "trending_products"
            referencedColumns: ["product_id"]
          },
          {
            foreignKeyName: "scan_history_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      user_badges: {
        Row: {
          badge_id: string
          earned_at: string
          user_id: string
        }
        Insert: {
          badge_id: string
          earned_at?: string
          user_id: string
        }
        Update: {
          badge_id?: string
          earned_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_badges_badge_id_fkey"
            columns: ["badge_id"]
            isOneToOne: false
            referencedRelation: "badges"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_badges_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      user_brand_preferences: {
        Row: {
          brand_id: string
          created_at: string
          id: string
          user_id: string
        }
        Insert: {
          brand_id: string
          created_at?: string
          id?: string
          user_id: string
        }
        Update: {
          brand_id?: string
          created_at?: string
          id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_brand_preferences_brand_id_fkey"
            columns: ["brand_id"]
            isOneToOne: false
            referencedRelation: "brand_rankings"
            referencedColumns: ["brand_id"]
          },
          {
            foreignKeyName: "user_brand_preferences_brand_id_fkey"
            columns: ["brand_id"]
            isOneToOne: false
            referencedRelation: "brands"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_brand_preferences_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      user_category_preferences: {
        Row: {
          category_id: string
          created_at: string
          id: string
          user_id: string
        }
        Insert: {
          category_id: string
          created_at?: string
          id?: string
          user_id: string
        }
        Update: {
          category_id?: string
          created_at?: string
          id?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_category_preferences_category_id_fkey"
            columns: ["category_id"]
            isOneToOne: false
            referencedRelation: "categories"
            referencedColumns: ["id"]
          },
          {
            foreignKeyName: "user_category_preferences_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: false
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      user_consents: {
        Row: {
          analytics_consent: boolean
          analytics_consent_at: string | null
          push_consent_at: string | null
          push_notifications: boolean
          tos_accepted: boolean
          tos_accepted_at: string | null
          tos_version: string | null
          updated_at: string
          user_id: string
        }
        Insert: {
          analytics_consent?: boolean
          analytics_consent_at?: string | null
          push_consent_at?: string | null
          push_notifications?: boolean
          tos_accepted?: boolean
          tos_accepted_at?: string | null
          tos_version?: string | null
          updated_at?: string
          user_id: string
        }
        Update: {
          analytics_consent?: boolean
          analytics_consent_at?: string | null
          push_consent_at?: string | null
          push_notifications?: boolean
          tos_accepted?: boolean
          tos_accepted_at?: string | null
          tos_version?: string | null
          updated_at?: string
          user_id?: string
        }
        Relationships: [
          {
            foreignKeyName: "user_consents_user_id_fkey"
            columns: ["user_id"]
            isOneToOne: true
            referencedRelation: "users"
            referencedColumns: ["id"]
          },
        ]
      }
      users: {
        Row: {
          avatar_url: string | null
          created_at: string
          display_name: string | null
          email: string
          error_rate: number
          id: string
          is_premium: boolean
          last_active_date: string | null
          onboarding_completed: boolean
          points: number
          premium_expires_at: string | null
          products_contributed: number
          products_verified: number
          role: Database["public"]["Enums"]["user_role"]
          streak_days: number
          trust_level: Database["public"]["Enums"]["trust_level"]
          updated_at: string
        }
        Insert: {
          avatar_url?: string | null
          created_at?: string
          display_name?: string | null
          email: string
          error_rate?: number
          id: string
          is_premium?: boolean
          last_active_date?: string | null
          onboarding_completed?: boolean
          points?: number
          premium_expires_at?: string | null
          products_contributed?: number
          products_verified?: number
          role?: Database["public"]["Enums"]["user_role"]
          streak_days?: number
          trust_level?: Database["public"]["Enums"]["trust_level"]
          updated_at?: string
        }
        Update: {
          avatar_url?: string | null
          created_at?: string
          display_name?: string | null
          email?: string
          error_rate?: number
          id?: string
          is_premium?: boolean
          last_active_date?: string | null
          onboarding_completed?: boolean
          points?: number
          premium_expires_at?: string | null
          products_contributed?: number
          products_verified?: number
          role?: Database["public"]["Enums"]["user_role"]
          streak_days?: number
          trust_level?: Database["public"]["Enums"]["trust_level"]
          updated_at?: string
        }
        Relationships: []
      }
    }
    Views: {
      brand_rankings: {
        Row: {
          avg_score: number | null
          avg_verdict: Database["public"]["Enums"]["verdict"] | null
          brand_id: string | null
          brand_name: string | null
          brand_slug: string | null
          market_segment: Database["public"]["Enums"]["market_segment"] | null
          product_count: number | null
          total_scans: number | null
        }
        Relationships: []
      }
      trending_products: {
        Row: {
          brand_id: string | null
          brand_name: string | null
          photo_urls: string[] | null
          price: number | null
          product_id: string | null
          product_name: string | null
          product_slug: string | null
          recent_scans: number | null
          verdict: Database["public"]["Enums"]["verdict"] | null
          worthy_score: number | null
        }
        Relationships: [
          {
            foreignKeyName: "products_brand_id_fkey"
            columns: ["brand_id"]
            isOneToOne: false
            referencedRelation: "brand_rankings"
            referencedColumns: ["brand_id"]
          },
          {
            foreignKeyName: "products_brand_id_fkey"
            columns: ["brand_id"]
            isOneToOne: false
            referencedRelation: "brands"
            referencedColumns: ["id"]
          },
        ]
      }
    }
    Functions: {
      calculate_composition_score: { Args: { comp: Json }; Returns: number }
      calculate_qpr: { Args: { p_product_id: string }; Returns: number }
      calculate_worthy_score: {
        Args: { p_product_id: string }
        Returns: number
      }
      find_potential_duplicates: {
        Args: { p_brand_id: string; p_name: string; p_product_id: string }
        Returns: {
          found_product_id: string
          name_similarity: number
        }[]
      }
      show_limit: { Args: never; Returns: number }
      show_trgm: { Args: { "": string }; Returns: string[] }
    }
    Enums: {
      audit_action: "insert" | "update" | "delete"
      duplicate_status: "pending" | "confirmed_duplicate" | "not_duplicate"
      gender: "uomo" | "donna" | "unisex"
      market_segment:
        | "ultra_fast"
        | "fast"
        | "premium_fast"
        | "mid_range"
        | "fast_fashion"
        | "premium"
        | "maison"
      price_source: "user" | "scraper" | "affiliate_feed"
      report_reason:
        | "wrong_composition"
        | "wrong_price"
        | "wrong_brand"
        | "duplicate"
        | "other"
      report_status: "pending" | "confirmed" | "rejected"
      scan_type: "barcode" | "label" | "manual" | "search"
      trust_level: "new" | "contributor" | "trusted" | "banned"
      user_role: "user" | "moderator" | "admin"
      verdict: "steal" | "worthy" | "fair" | "meh" | "not_worthy"
      verification_status: "unverified" | "verified" | "mattia_reviewed"
    }
    CompositeTypes: {
      [_ in never]: never
    }
  }
}

type DatabaseWithoutInternals = Omit<Database, "__InternalSupabase">

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] &
        DefaultSchema["Views"])
    ? (DefaultSchema["Tables"] &
        DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
        Row: infer R
      }
      ? R
      : never
    : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Insert: infer I
      }
      ? I
      : never
    : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never,
> = DefaultSchemaTableNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
    ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
        Update: infer U
      }
      ? U
      : never
    : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never,
> = DefaultSchemaEnumNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
    ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
    : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never,
> = PublicCompositeTypeNameOrOptions extends {
  schema: keyof DatabaseWithoutInternals
}
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
    ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
    : never

export const Constants = {
  public: {
    Enums: {
      audit_action: ["insert", "update", "delete"],
      duplicate_status: ["pending", "confirmed_duplicate", "not_duplicate"],
      gender: ["uomo", "donna", "unisex"],
      market_segment: [
        "ultra_fast",
        "fast",
        "premium_fast",
        "mid_range",
        "fast_fashion",
        "premium",
        "maison",
      ],
      price_source: ["user", "scraper", "affiliate_feed"],
      report_reason: [
        "wrong_composition",
        "wrong_price",
        "wrong_brand",
        "duplicate",
        "other",
      ],
      report_status: ["pending", "confirmed", "rejected"],
      scan_type: ["barcode", "label", "manual", "search"],
      trust_level: ["new", "contributor", "trusted", "banned"],
      user_role: ["user", "moderator", "admin"],
      verdict: ["steal", "worthy", "fair", "meh", "not_worthy"],
      verification_status: ["unverified", "verified", "mattia_reviewed"],
    },
  },
} as const
