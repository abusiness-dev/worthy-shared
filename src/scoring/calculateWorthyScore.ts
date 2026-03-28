import type { WorthyScoreResult } from "../types";
import { verdictFromScore } from "./verdictFromScore";

export interface WorthyScoreInput {
  compositionScore: number;
  qprScore: number;
  fitScore?: number;
  durabilityScore?: number;
  mattiaAdjustment?: number;
}

export function calculateWorthyScore(params: WorthyScoreInput): WorthyScoreResult {
  const {
    compositionScore,
    qprScore,
    fitScore = 50,
    durabilityScore = 50,
    mattiaAdjustment = 0,
  } = params;

  const raw =
    compositionScore * 0.35 +
    qprScore * 0.30 +
    fitScore * 0.15 +
    durabilityScore * 0.15 +
    mattiaAdjustment;

  const score = Math.round(Math.min(100, Math.max(0, raw)));

  return {
    score,
    verdict: verdictFromScore(score),
    breakdown: {
      composition: compositionScore,
      qpr: qprScore,
      fit: params.fitScore ?? null,
      durability: params.durabilityScore ?? null,
      mattia_adjustment: mattiaAdjustment,
    },
  };
}
