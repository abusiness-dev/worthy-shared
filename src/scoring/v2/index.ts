// Worthy Score v2 - public API.
// L'engine v1 resta in src/scoring/ ed è esportato sotto il namespace canonico
// (calculateWorthyScore, calculateCompositionScore, calculateQPR). v2 affianca
// v1 durante F3 (dual-write) e diventa default in F5 (switch).

export { calculateWorthyScoreV2 } from "./calculateWorthyScoreV2";
export { compositionLens } from "./lenses/compositionLens";
export { qprLens } from "./lenses/qprLens";
export { manufacturingLens } from "./lenses/manufacturingLens";
export { sustainabilityLens } from "./lenses/sustainabilityLens";
export type { ManufacturingInput } from "./lenses/manufacturingLens";
export type { SustainabilityLensInput } from "./lenses/sustainabilityLens";
