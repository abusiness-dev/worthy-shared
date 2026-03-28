import type { ScanType } from "./enums";

export interface ScanHistoryEntry {
  id: string;
  user_id: string;
  product_id: string | null;
  barcode: string;
  scan_type: ScanType;
  found: boolean;
  created_at: string;
}
