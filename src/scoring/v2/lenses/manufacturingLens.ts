import { manufacturingScoreFor } from "../../../constants/countries";

export interface ManufacturingInput {
  productionCountry?: string | null;
  weavingCountry?: string | null;
  spinningCountry?: string | null;
  dyeingCountry?: string | null;
  hasMadeInItaly100?: boolean;
}

const STEP_WEIGHTS = {
  production: 0.50,  // last substantial transformation: peso maggiore
  weaving:    0.25,
  spinning:   0.15,
  dyeing:     0.10,
} as const;

// Manufacturing lens (peso 15% del Worthy Score v2).
// Media pesata sui 4 step di filiera: country_of_production conta più di
// weaving/spinning/dyeing (è la "last substantial transformation" e firma il
// Made in...). Bonus +8 se il prodotto ha la certificazione "100% Made in Italy".
// Null se nessuno step è dichiarato (graceful degradation).
export function manufacturingLens(input: ManufacturingInput): number | null {
  let weightedSum = 0;
  let totalWeight = 0;

  const addStep = (iso2: string | null | undefined, weight: number) => {
    if (!iso2) return;
    const score = manufacturingScoreFor(iso2);
    if (score === null) return;
    weightedSum += score * weight;
    totalWeight += weight;
  };

  addStep(input.productionCountry, STEP_WEIGHTS.production);
  addStep(input.weavingCountry,    STEP_WEIGHTS.weaving);
  addStep(input.spinningCountry,   STEP_WEIGHTS.spinning);
  addStep(input.dyeingCountry,     STEP_WEIGHTS.dyeing);

  if (totalWeight === 0) return null;

  let result = weightedSum / totalWeight;

  if (input.hasMadeInItaly100) {
    result += 8;
  }

  return Math.min(100, Math.max(0, result));
}
