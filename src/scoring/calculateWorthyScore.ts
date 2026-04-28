import type { WorthyScoreResult } from "../types";
import { verdictFromScore } from "./verdictFromScore";

export interface WorthyScoreInput {
  compositionScore: number;
  qprScore: number;
}

// Formula semplificata: 70% composizione + 30% QPR, clamp 0-100.
// L'override Mattia adjustment è stato rimosso: il calcolo non dipende più da
// mattia_reviews.score_adjustment (la colonna resta nel DB ma è ignorata).
export function calculateWorthyScore(params: WorthyScoreInput): WorthyScoreResult {
  const { compositionScore, qprScore } = params;

  const raw = compositionScore * 0.7 + qprScore * 0.3;
  const score = Math.round(Math.min(100, Math.max(0, raw)));

  return {
    score,
    verdict: verdictFromScore(score),
    breakdown: {
      composition: compositionScore,
      qpr: qprScore,
    },
  };
}
