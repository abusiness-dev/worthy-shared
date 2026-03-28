export type VerificationStatus = "unverified" | "verified" | "mattia_reviewed";

export type Verdict = "steal" | "worthy" | "fair" | "meh" | "not_worthy";

export type TrustLevel = "new" | "contributor" | "trusted" | "banned";

export type UserRole = "user" | "moderator" | "admin";

export type MarketSegment = "ultra_fast" | "fast" | "premium_fast" | "mid_range";

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
