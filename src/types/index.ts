export type {
  VerificationStatus,
  Verdict,
  TrustLevel,
  UserRole,
  MarketSegment,
  ScanType,
  ReportReason,
  ReportStatus,
  DuplicateStatus,
  AuditAction,
  PriceSource,
  Gender,
} from "./enums";

export type { Composition, Product, ProductInsert, ProductUpdate, ProductWithRelations } from "./product";
export type { Brand, BrandWithStats } from "./brand";
export type { User, UserProfile, UserBrandPreference, UserCategoryPreference } from "./user";
export type { Category } from "./category";
export type { ProductVote, VoteInsert } from "./vote";
export type { MattiaReview, ReviewInsert } from "./review";
export type { ProductReport } from "./report";
export type { Badge, UserBadge } from "./badge";
export type { ScanHistoryEntry } from "./scan";
export type { DailyWorthy } from "./daily";
export type { UserConsent } from "./consent";
export type { ProductDuplicate } from "./duplicate";
export type { AuditLogEntry } from "./audit";
export type { ScoreBreakdown, WorthyScoreResult } from "./scoring";
export type { PriceHistory } from "./price-history";
export type { SavedProduct, SavedComparison } from "./saved";
