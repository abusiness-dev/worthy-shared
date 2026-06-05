import type {
  ScoreBreakdownV2,
  WorthyScoreV2Input,
  WorthyScoreV2Result,
} from "../../types/scoring";
import { WORTHY_SCORE_V2_WEIGHTS } from "../../types/scoring";
import { verdictFromScore } from "../verdictFromScore";
import { compositionLens } from "./lenses/compositionLens";
import { qprLens } from "./lenses/qprLens";
import { manufacturingLens } from "./lenses/manufacturingLens";

const FULL_WEIGHTS_SUM = Object.values(WORTHY_SCORE_V2_WEIGHTS).reduce((a, b) => a + b, 0);

// Worthy Score v2 — orchestratore a 3 lenti con graceful degradation.
//
// Pesi (somma 1.0):
//   composition     50%  - sempre presente
//   manufacturing   25%  - null se nessuno step di filiera è dichiarato
//   qpr             25%  - sempre presente (default 50 in edge case)
export function calculateWorthyScoreV2(input: WorthyScoreV2Input): WorthyScoreV2Result {
  const compositionScore = compositionLens(input.composition);

  const hasMadeInItaly100 = (input.productCertifications ?? []).includes("made_in_italy_100");
  const manufacturingScore = manufacturingLens({
    productionCountry: input.manufacturing?.productionCountry,
    weavingCountry:    input.manufacturing?.weavingCountry,
    spinningCountry:   input.manufacturing?.spinningCountry,
    dyeingCountry:     input.manufacturing?.dyeingCountry,
    hasMadeInItaly100,
  });

  // Riferimento del QPR: preferisci la median del cluster (allineata al server);
  // fallback alla media di categoria per retro-compatibilità.
  const refQuality = input.category.medianQualityIndex ?? input.category.avgCompositionScore;
  const refPrice   = input.category.medianPrice ?? input.category.avgPrice;
  const refManufacturing = input.category.medianManufacturing ?? null;

  const qprScore = qprLens(
    compositionScore,
    input.price,
    refQuality,
    refPrice,
    manufacturingScore,
    refManufacturing,
  );

  // Aggregazione pesata con rinormalizzazione delle componenti null.
  let weightedSum = 0;
  let usedWeight = 0;

  // composition: sempre presente
  weightedSum += compositionScore * WORTHY_SCORE_V2_WEIGHTS.composition;
  usedWeight  += WORTHY_SCORE_V2_WEIGHTS.composition;

  if (manufacturingScore !== null) {
    weightedSum += manufacturingScore * WORTHY_SCORE_V2_WEIGHTS.manufacturing;
    usedWeight  += WORTHY_SCORE_V2_WEIGHTS.manufacturing;
  }

  // qpr: sempre presente
  weightedSum += qprScore * WORTHY_SCORE_V2_WEIGHTS.qpr;
  usedWeight  += WORTHY_SCORE_V2_WEIGHTS.qpr;

  const raw = weightedSum / usedWeight;
  const final = Math.round(Math.min(100, Math.max(0, raw)));
  const verdict = verdictFromScore(final);
  const confidence = Math.round((usedWeight / FULL_WEIGHTS_SUM) * 100);

  const breakdown: ScoreBreakdownV2 = {
    version: "v2.0",
    lenses: {
      composition:   { score: compositionScore,   used: true },
      manufacturing: { score: manufacturingScore, used: manufacturingScore !== null },
      qpr:           { score: qprScore,           used: true },
    },
    weights: WORTHY_SCORE_V2_WEIGHTS,
    confidence,
    raw: Math.round(raw * 100) / 100,
    final,
    verdict,
  };

  return { score: final, verdict, confidence, breakdown };
}
