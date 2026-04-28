import type { Composition } from "../../../types";
import { calculateCompositionScore } from "../../calculateComposition";

// Composition lens (peso 40% del Worthy Score v2).
// Riusa il calcolo v1 invariato: media pesata sui FIBER_SCORES con regola
// elastane (≤5% ignorato, 6-10% → 40, >10% → 20). Default 50 se composition vuota.
// È sempre presente (mai null): non innesca rinormalizzazione.
export function compositionLens(composition: Composition[]): number {
  return calculateCompositionScore(composition);
}
