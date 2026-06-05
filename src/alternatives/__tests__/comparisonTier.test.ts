import { describe, it, expect } from "vitest";
import { isEligibleAlternative, type AlternativeProduct } from "../index";
import {
  isTierAdjacent,
  tierProximity,
  COMPARISON_TIER_ORDER,
} from "../../constants/comparisonTiers";

function product(over: Partial<AlternativeProduct> = {}): AlternativeProduct {
  return {
    id: "x",
    worthy_score: 70,
    price: 100,
    gender: "unisex",
    composition: null,
    market_segment: null,
    comparison_tier: null,
    brand_id: "b",
    category_id: "c1",
    category_family: "t-shirt",
    ...over,
  };
}

describe("comparison_tier — helper ordinali", () => {
  it("ordine: mass_market < premium < luxury < maison", () => {
    expect(COMPARISON_TIER_ORDER).toEqual({
      mass_market: 0,
      premium: 1,
      luxury: 2,
      maison: 3,
    });
  });

  it("adiacenza ±1; lega ignota non blocca", () => {
    expect(isTierAdjacent("premium", "luxury")).toBe(true);
    expect(isTierAdjacent("premium", "maison")).toBe(false); // distanza 2
    expect(isTierAdjacent("mass_market", "maison")).toBe(false); // distanza 3
    expect(isTierAdjacent(null, "maison")).toBe(true);
  });

  it("prossimità: stessa lega = 1, estremi = 0", () => {
    expect(tierProximity("premium", "premium")).toBe(1);
    expect(tierProximity("mass_market", "maison")).toBe(0);
    expect(tierProximity(null, "premium")).toBe(0.5);
  });
});

describe("isEligibleAlternative — adiacenza per comparison_tier", () => {
  const ref = product({ id: "r", worthy_score: 60, comparison_tier: "premium", market_segment: "premium" });

  it("lega adiacente (premium→luxury) ⇒ ammissibile", () => {
    const cand = product({ id: "a", worthy_score: 70, comparison_tier: "luxury" });
    expect(isEligibleAlternative(ref, cand)).toBe(true);
  });

  it("lega distante 2 (premium→maison) ⇒ non ammissibile", () => {
    const cand = product({ id: "a", worthy_score: 70, comparison_tier: "maison" });
    expect(isEligibleAlternative(ref, cand)).toBe(false);
  });

  it("comparison_tier ha precedenza su market_segment", () => {
    // Leghe distanti 3 (non adiacenti) anche se i market_segment coinciderebbero.
    const refMass = product({ id: "r", worthy_score: 60, comparison_tier: "mass_market", market_segment: "maison" });
    const cand = product({ id: "a", worthy_score: 70, comparison_tier: "maison", market_segment: "maison" });
    expect(isEligibleAlternative(refMass, cand)).toBe(false);
  });
});
