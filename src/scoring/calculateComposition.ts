import type { Composition } from "../types";
import { FIBER_SCORES, NEUTRAL_FIBERS, NEUTRAL_THRESHOLD, DEFAULT_FIBER_SCORE } from "./fiberScores";

export function calculateCompositionScore(composition: Composition[]): number {
  if (composition.length === 0) return 50;

  const activeFibers = composition.filter((c) => {
    const isNeutral = NEUTRAL_FIBERS.includes(c.fiber.toLowerCase());
    return !(isNeutral && c.percentage <= NEUTRAL_THRESHOLD);
  });

  if (activeFibers.length === 0) return 50;

  const totalPercentage = activeFibers.reduce((sum, c) => sum + c.percentage, 0);

  if (totalPercentage === 0) return 50;

  const weightedSum = activeFibers.reduce((sum, c) => {
    const score = FIBER_SCORES[c.fiber.toLowerCase()] ?? DEFAULT_FIBER_SCORE;
    return sum + score * c.percentage;
  }, 0);

  return Math.round(Math.min(100, Math.max(0, weightedSum / totalPercentage)));
}
