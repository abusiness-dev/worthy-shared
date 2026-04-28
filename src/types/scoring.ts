import type { Verdict } from "./enums";

export interface ScoreBreakdown {
  composition: number;
  qpr: number;
}

export interface WorthyScoreResult {
  score: number;
  verdict: Verdict;
  breakdown: ScoreBreakdown;
}

// ============================================================
// Worthy Score v2 - tipi multi-lente con graceful degradation
// ============================================================

export type WorthyScoreLensName =
  | "composition"
  | "manufacturing"
  | "qpr"
  | "sustainability";

export interface LensResult {
  score: number | null;  // null = lente esclusa
  used: boolean;         // score !== null
}

// Pesi delle 4 lenti finali (somma 1.0).
export const WORTHY_SCORE_V2_WEIGHTS = {
  composition:    0.50,
  manufacturing:  0.25,
  qpr:            0.20,
  sustainability: 0.05,
} as const;

export interface ScoreBreakdownV2 {
  version: "v2.0";
  lenses: Record<WorthyScoreLensName, LensResult>;
  weights: typeof WORTHY_SCORE_V2_WEIGHTS;
  confidence: number;    // 0-100, frazione di pesi usati × 100
  raw: number;           // valore prima del clamp/round
  final: number;         // valore finale 0-100
  verdict: Verdict;
}

export interface WorthyScoreV2Input {
  // Sempre richiesti
  composition: { fiber: string; percentage: number }[];
  price: number;
  category: { avgCompositionScore: number; avgPrice: number };

  // Opzionali (graceful degradation se assenti)
  manufacturing?: {
    productionCountry?: string | null;  // ISO2
    weavingCountry?: string | null;
    spinningCountry?: string | null;
    dyeingCountry?: string | null;
  };
  productCertifications?: string[];       // certification ids (product-level)
  brandCertifications?: string[];         // certification ids (brand-level)
}

export interface WorthyScoreV2Result {
  score: number;
  verdict: Verdict;
  confidence: number;
  breakdown: ScoreBreakdownV2;
}
