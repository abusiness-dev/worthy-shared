import { bonusFor } from "../../../constants/certifications";

export interface SustainabilityLensInput {
  productCertifications: string[];
  brandCertifications: string[];
}

// Sustainability lens (peso 5% del Worthy Score v2).
// Somma cumulativa dei bonus_points di product_certifications + brand_certifications,
// capped a 100. È un bonus opt-in: null se nessuna certificazione è presente
// (la lente viene esclusa dalla rinormalizzazione, evitando di penalizzare
// capi senza certificazioni esplicite).
export function sustainabilityLens(input: SustainabilityLensInput): number | null {
  const total =
    input.productCertifications.reduce((sum, id) => sum + bonusFor(id), 0) +
    input.brandCertifications.reduce((sum, id) => sum + bonusFor(id), 0);

  if (total === 0) return null;

  return Math.min(100, Math.max(0, total));
}
