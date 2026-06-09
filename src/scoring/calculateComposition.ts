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

      // Coercizione difensiva: una percentage mancante/NaN/<=0 (composizione
      // malformata da OCR/scraper/JSONB) verrebbe altrimenti propagata come NaN
      // fino al worthy_score. Scarta l'elemento, allineato al guard SQL.
      const pct = Number(c.percentage);
      if (!Number.isFinite(pct) || pct <= 0) return null;

      if (isElastane(fiber)) {
        if (pct <= ELASTANE_IGNORE_THRESHOLD) return null;
        return { percentage: pct, score: elastaneScore(pct)! };
      }

      const score = FIBER_SCORES[fiber] ?? DEFAULT_FIBER_SCORE;
      return { percentage: pct, score };
    })
    .filter((x): x is { percentage: number; score: number } => x !== null);

  if (scored.length === 0) return 50;

  const totalPercentage = scored.reduce((sum, c) => sum + c.percentage, 0);
  if (totalPercentage === 0) return 50;

  const weightedSum = scored.reduce((sum, c) => sum + c.score * c.percentage, 0);

  return Math.round(Math.min(100, Math.max(0, weightedSum / totalPercentage)));
}
