import type { Verdict } from "./enums";

export interface ScoreBreakdown {
  composition: number;
  qpr: number;
  mattia_adjustment: number;
}

export interface WorthyScoreResult {
  score: number;
  verdict: Verdict;
  breakdown: ScoreBreakdown;
}
