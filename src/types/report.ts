import type { ReportReason, ReportStatus } from "./enums";

export interface ProductReport {
  id: string;
  product_id: string;
  user_id: string;
  reason: ReportReason;
  description: string | null;
  status: ReportStatus;
  created_at: string;
}
