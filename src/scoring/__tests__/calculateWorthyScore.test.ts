import { describe, it, expect } from "vitest";
import { calculateWorthyScore } from "../calculateWorthyScore";

describe("calculateWorthyScore", () => {
  it("composition 80 + qpr 80 → 80 (70/30 split), verdict worthy", () => {
    const result = calculateWorthyScore({
      compositionScore: 80,
      qprScore: 80,
    });
    // 80*0.7 + 80*0.3 = 80
    expect(result.score).toBe(80);
    expect(result.verdict).toBe("worthy");
  });

  it("composition 95 + qpr 90 → 94, verdict steal", () => {
    const result = calculateWorthyScore({
      compositionScore: 95,
      qprScore: 90,
    });
    // 95*0.7 + 90*0.3 = 66.5 + 27 = 93.5 → 94
    expect(result.score).toBe(94);
    expect(result.verdict).toBe("steal");
  });

  it("tutti bassi → verdict not_worthy", () => {
    const result = calculateWorthyScore({
      compositionScore: 10,
      qprScore: 10,
    });
    // 10*0.7 + 10*0.3 = 10
    expect(result.score).toBe(10);
    expect(result.verdict).toBe("not_worthy");
  });

  it("100/100 → clamp a 100, verdict steal", () => {
    const result = calculateWorthyScore({
      compositionScore: 100,
      qprScore: 100,
    });
    expect(result.score).toBe(100);
    expect(result.verdict).toBe("steal");
  });

  it("0/0 → 0, verdict not_worthy", () => {
    const result = calculateWorthyScore({
      compositionScore: 0,
      qprScore: 0,
    });
    expect(result.score).toBe(0);
    expect(result.verdict).toBe("not_worthy");
  });

  it("breakdown contiene solo composition e qpr (Mattia rimosso)", () => {
    const result = calculateWorthyScore({
      compositionScore: 80,
      qprScore: 70,
    });
    expect(result.breakdown.composition).toBe(80);
    expect(result.breakdown.qpr).toBe(70);
    expect((result.breakdown as Record<string, unknown>).mattia_adjustment).toBeUndefined();
    expect((result.breakdown as Record<string, unknown>).fit).toBeUndefined();
    expect((result.breakdown as Record<string, unknown>).durability).toBeUndefined();
  });
});
