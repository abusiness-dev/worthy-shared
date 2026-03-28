import { describe, it, expect } from "vitest";
import { calculateCompositionScore } from "../calculateComposition";

describe("calculateCompositionScore", () => {
  it("100% cotone → 75", () => {
    expect(calculateCompositionScore([{ fiber: "cotone", percentage: 100 }])).toBe(75);
  });

  it("100% cashmere → 98", () => {
    expect(calculateCompositionScore([{ fiber: "cashmere", percentage: 100 }])).toBe(98);
  });

  it("100% poliestere → 30", () => {
    expect(calculateCompositionScore([{ fiber: "poliestere", percentage: 100 }])).toBe(30);
  });

  it("70% cotone + 30% poliestere → ~61-62", () => {
    const score = calculateCompositionScore([
      { fiber: "cotone", percentage: 70 },
      { fiber: "poliestere", percentage: 30 },
    ]);
    expect(score).toBeGreaterThanOrEqual(61);
    expect(score).toBeLessThanOrEqual(62);
  });

  it("95% cotone + 5% elastan → elastan ignorato, score 75", () => {
    expect(
      calculateCompositionScore([
        { fiber: "cotone", percentage: 95 },
        { fiber: "elastane", percentage: 5 },
      ]),
    ).toBe(75);
  });

  it("90% cotone + 10% elastan → elastan conteggiato", () => {
    const score = calculateCompositionScore([
      { fiber: "cotone", percentage: 90 },
      { fiber: "elastane", percentage: 10 },
    ]);
    // elastan = DEFAULT 50, so weighted: (75*90 + 50*10) / 100 = 72.5 → 73
    expect(score).not.toBe(75);
    expect(score).toBe(73);
  });

  it("composizione vuota → 50", () => {
    expect(calculateCompositionScore([])).toBe(50);
  });

  it("fibra sconosciuta → default 50", () => {
    expect(calculateCompositionScore([{ fiber: "mithril", percentage: 100 }])).toBe(50);
  });
});
