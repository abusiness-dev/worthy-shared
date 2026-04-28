export {
  FIBER_SCORES,
  DEFAULT_FIBER_SCORE,
  ELASTANE_FIBERS,
  ELASTANE_IGNORE_THRESHOLD,
  ELASTANE_LOW_THRESHOLD,
  ELASTANE_SCORE_LOW,
  ELASTANE_SCORE_HIGH,
  isElastane,
  elastaneScore,
} from "./fiberScores";
export { calculateCompositionScore } from "./calculateComposition";
export { calculateQPR } from "./calculateQPR";
export { calculateWorthyScore } from "./calculateWorthyScore";
export type { WorthyScoreInput } from "./calculateWorthyScore";
export { verdictFromScore } from "./verdictFromScore";

// Worthy Score v2 (vedi src/scoring/v2/)
export {
  calculateWorthyScoreV2,
  compositionLens,
  qprLens,
  manufacturingLens,
  sustainabilityLens,
} from "./v2";
export type {
  ManufacturingInput,
  SustainabilityLensInput,
} from "./v2";
