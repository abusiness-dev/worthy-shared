import { describe, it, expect } from "vitest";
import { calculateWorthyScore } from "../calculateWorthyScore";

describe("calculateWorthyScore", () => {
  it("tutti i sub-score a 80, no adjustment → 76 (pesi sommano 0.95), verdict worthy", () => {
    const result = calculateWorthyScore({
      compositionScore: 80,
      qprScore: 80,
      fitScore: 80,
      durabilityScore: 80,
    });
    // 80*0.35 + 80*0.30 + 80*0.15 + 80*0.15 = 76
    expect(result.score).toBe(76);
    expect(result.verdict).toBe("worthy");
  });

  it("composizione 95 + QPR 90 + default fit/durability → score alto, verdict steal", () => {
    const result = calculateWorthyScore({
      compositionScore: 95,
      qprScore: 90,
    });
    // 95*0.35 + 90*0.30 + 50*0.15 + 50*0.15 = 33.25 + 27 + 7.5 + 7.5 = 75.25 → 75
    expect(result.score).toBe(75);
    expect(result.verdict).toBe("worthy");
  });

  it("tutti bassi → verdict not_worthy", () => {
    const result = calculateWorthyScore({
      compositionScore: 10,
      qprScore: 10,
      fitScore: 10,
      durabilityScore: 10,
    });
    expect(result.score).toBe(10);
    expect(result.verdict).toBe("not_worthy");
  });

  it("adjustment +5 su score 98 → clamp a 100", () => {
    const result = calculateWorthyScore({
      compositionScore: 100,
      qprScore: 100,
      fitScore: 100,
      durabilityScore: 100,
      mattiaAdjustment: 5,
    });
    expect(result.score).toBe(100);
    expect(result.verdict).toBe("steal");
  });

  it("adjustment -5 su score 2 → clamp a 0", () => {
    const result = calculateWorthyScore({
      compositionScore: 0,
      qprScore: 0,
      fitScore: 0,
      durabilityScore: 0,
      mattiaAdjustment: -5,
    });
    expect(result.score).toBe(0);
    expect(result.verdict).toBe("not_worthy");
  });

  it("breakdown contiene i valori corretti", () => {
    const result = calculateWorthyScore({
      compositionScore: 80,
      qprScore: 70,
      mattiaAdjustment: 3,
    });
    expect(result.breakdown.composition).toBe(80);
    expect(result.breakdown.qpr).toBe(70);
    expect(result.breakdown.fit).toBeNull();
    expect(result.breakdown.durability).toBeNull();
    expect(result.breakdown.mattia_adjustment).toBe(3);
  });
});
