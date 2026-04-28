export { FIBERS } from "./fibers";
export type { FiberId, FiberTier } from "./fibers";
export { BADGES } from "./badges";
export type { BadgeId } from "./badges";
export { CATEGORIES } from "./categories";
export type { CategorySlug } from "./categories";
export { LAUNCH_BRANDS } from "./brands";
export { VERDICTS } from "./verdicts";
export { POINTS, RATE_LIMITS, VALIDATION } from "./limits";
export { MARKET_SEGMENTS } from "./marketSegments";
export { NAV_TABS, ONBOARDING_STEPS } from "./navigation";
export type { NavTab, OnboardingStep } from "./navigation";
export {
  FIBER_DESCRIPTIONS,
  getElastaneDescription,
  getFiberDescription,
} from "./fiberDescriptions";

// Worthy Score v2 - lookup tables
export { COUNTRIES, getCountry, manufacturingScoreFor } from "./countries";
export type { Country, CountryIso2 } from "./countries";
export { CERTIFICATIONS, getCertification, bonusFor } from "./certifications";
export type { Certification, CertificationId, CertificationScope } from "./certifications";
