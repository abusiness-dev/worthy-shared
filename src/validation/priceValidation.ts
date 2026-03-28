import type { Composition } from "../types";
import { calculateCompositionScore } from "../scoring";

export function validatePrice(
  price: number,
  composition?: Composition[],
): { valid: boolean; plausible: boolean; warning?: string } {
  if (price < 0.01 || price > 500) {
    return { valid: false, plausible: false };
  }

  if (!composition || composition.length === 0) {
    return { valid: true, plausible: true };
  }

  const score = calculateCompositionScore(composition);

  if (score > 85 && price < 5) {
    return {
      valid: true,
      plausible: false,
      warning: "Composizione premium a un prezzo molto basso — verifica che il prezzo sia corretto",
    };
  }

  if (score <= 30 && price > 100) {
    return {
      valid: true,
      plausible: false,
      warning: "Composizione di bassa qualità a un prezzo molto alto — verifica che il prezzo sia corretto",
    };
  }

  return { valid: true, plausible: true };
}
