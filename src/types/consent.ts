export interface UserConsent {
  user_id: string;
  tos_accepted: boolean;
  tos_accepted_at: string | null;
  tos_version: string | null;
  push_notifications: boolean;
  push_consent_at: string | null;
  analytics_consent: boolean;
  analytics_consent_at: string | null;
  updated_at: string;
}
