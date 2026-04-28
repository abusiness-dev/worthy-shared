export const POINTS = {
  scan_existing: 2,
  contribute_product: 15,
  confirm_data: 5,
  report_confirmed: 10,
  first_scan_of_day: 3,
  streak_7_days: 25,
  referral: 20,
} as const;

export const RATE_LIMITS = {
  products_per_day: 20,
  scans_per_hour: 60,
  votes_per_hour: 30,
  reports_per_day: 10,
  label_scans_per_hour: 15,
} as const;

export const VALIDATION = {
  product_name_min: 3,
  product_name_max: 200,
  price_min: 0.01,
  price_max: 500,
  composition_fibers_min: 1,
  composition_fibers_max: 8,
  composition_sum_target: 100,
  composition_sum_tolerance: 1,
  vote_score_min: 1,
  vote_score_max: 10,
} as const;
