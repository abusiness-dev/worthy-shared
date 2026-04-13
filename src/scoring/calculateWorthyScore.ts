import type { WorthyScoreResult } from "../types";
import { verdictFromScore } from "./verdictFromScore";

export interface WorthyScoreInput {
  compositionScore: number;
  qprScore: number;
  mattiaAdjustment?: number;
}

// Formula semplificata: 70% composizione + 30% QPR + Mattia (±5), clamp 0-100.
// Le ex dimensioni vestibilità/durabilità sono state rimosse perché prive di dati reali.
export function calculateWorthyScore(params: WorthyScoreInput): WorthyScoreResult {
  const { compositionScore, qprScore, mattiaAdjustment = 0 } = params;

  const raw = compositionScore * 0.7 + qprScore * 0.3 + mattiaAdjustment;
  const score = Math.round(Math.min(100, Math.max(0, raw)));

  return {
    score,
    verdict: verdictFromScore(score),
    breakdown: {
      composition: compositionScore,
      qpr: qprScore,
      mattia_adjustment: mattiaAdjustment,
    },
  };
}
