// Tab della nav bar (5 tab): search (home+ricerca), top-rated (classifiche),
// scan (scanner), coach (placeholder AI), saved (salvati+profilo).
export const NAV_TABS = ["search", "top-rated", "scan", "coach", "saved"] as const;

export type NavTab = (typeof NAV_TABS)[number];

// Step del flusso di onboarding, in ordine di navigazione.
export const ONBOARDING_STEPS = [
  "welcome",
  "value_prop_1",
  "value_prop_2",
  "brand_selection",
  "category_selection",
  "notifications",
  "complete",
] as const;

export type OnboardingStep = (typeof ONBOARDING_STEPS)[number];
