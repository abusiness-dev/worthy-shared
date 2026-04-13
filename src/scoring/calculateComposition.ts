import type { Composition } from "../types";
import {
  FIBER_SCORES,
  DEFAULT_FIBER_SCORE,
  isElastane,
  elastaneScore,
  ELASTANE_IGNORE_THRESHOLD,
} from "./fiberScores";

export function calculateCompositionScore(composition: Composition[]): number {
  if (composition.length === 0) return 50;

  const scored = composition
    .map((c) => {
      const fiber = c.fiber.toLowerCase();

      if (isElastane(fiber)) {
        if (c.percentage <= ELASTANE_IGNORE_THRESHOLD) return null;
        return { percentage: c.percentage, score: elastaneScore(c.percentage)! };
      }

      const score = FIBER_SCORES[fiber] ?? DEFAULT_FIBER_SCORE;
      return { percentage: c.percentage, score };
    })
    .filter((x): x is { percentage: number; score: number } => x !== null);

  if (scored.length === 0) return 50;

  const totalPercentage = scored.reduce((sum, c) => sum + c.percentage, 0);
  if (totalPercentage === 0) return 50;

  const weightedSum = scored.reduce((sum, c) => sum + c.score * c.percentage, 0);

  return Math.round(Math.min(100, Math.max(0, weightedSum / totalPercentage)));
}
