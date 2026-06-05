export type VerificationStatus = "unverified" | "verified" | "mattia_reviewed";

export type Verdict = "steal" | "worthy" | "fair" | "meh" | "not_worthy";

export type TrustLevel = "new" | "contributor" | "trusted" | "banned";

export type UserRole = "user" | "moderator" | "admin";

// Segmento di mercato legacy del brand. Resta in schema come attributo, ma NON
// guida più il QPR cluster-based: la dimensione di confronto è ComparisonTier.
export type MarketSegment = "ultra_fast" | "fast_fashion" | "premium" | "maison";

// Lega di confronto del brand — asse di clustering del QPR (categoria × lega).
// Editabile come dato (tabella comparison_tiers), ordinata per posizionamento.
//   mass_market < premium < luxury < maison
export type ComparisonTier = "mass_market" | "premium" | "luxury" | "maison";

export type ScanType = "barcode" | "label" | "manual" | "search";

export type ReportReason =
  | "wrong_composition"
  | "wrong_price"
  | "wrong_brand"
  | "duplicate"
  | "other";

export type ReportStatus = "pending" | "confirmed" | "rejected";

export type DuplicateStatus = "pending" | "confirmed_duplicate" | "not_duplicate";

export type AuditAction = "insert" | "update" | "delete";

export type PriceSource = "user" | "scraper" | "affiliate_feed";

export type Gender = "uomo" | "donna" | "unisex";
