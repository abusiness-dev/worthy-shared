import { describe, it, expect } from "vitest";
import { calculateCompositionScore } from "../calculateComposition";

describe("calculateCompositionScore", () => {
  it("100% cotone → 72", () => {
    expect(calculateCompositionScore([{ fiber: "cotone", percentage: 100 }])).toBe(72);
  });

  it("100% cashmere → 98", () => {
    expect(calculateCompositionScore([{ fiber: "cashmere", percentage: 100 }])).toBe(98);
  });

  it("100% poliestere → 25", () => {
    expect(calculateCompositionScore([{ fiber: "poliestere", percentage: 100 }])).toBe(25);
  });

  it("70% cotone + 30% poliestere → 58", () => {
    // (72*70 + 25*30) / 100 = 57.9 → 58
    expect(
      calculateCompositionScore([
        { fiber: "cotone", percentage: 70 },
        { fiber: "poliestere", percentage: 30 },
      ]),
    ).toBe(58);
  });

  it("95% cotone + 5% elastan → elastan ignorato, score 72", () => {
    expect(
      calculateCompositionScore([
        { fiber: "cotone", percentage: 95 },
        { fiber: "elastane", percentage: 5 },
      ]),
    ).toBe(72);
  });

  it("90% cotone + 10% elastan → elastan penalizzato a 40 (soglia 6-10%)", () => {
    // (72*90 + 40*10) / 100 = 68.8 → 69
    expect(
      calculateCompositionScore([
        { fiber: "cotone", percentage: 90 },
        { fiber: "elastane", percentage: 10 },
      ]),
    ).toBe(69);
  });

  it("85% cotone + 15% elastan → elastan penalizzato a 20 (soglia >10%)", () => {
    // (72*85 + 20*15) / 100 = 64.2 → 64
    expect(
      calculateCompositionScore([
        { fiber: "cotone", percentage: 85 },
        { fiber: "elastane", percentage: 15 },
      ]),
    ).toBe(64);
  });

  it("composizione vuota → 50", () => {
    expect(calculateCompositionScore([])).toBe(50);
  });

  it("fibra sconosciuta → default 50", () => {
    expect(calculateCompositionScore([{ fiber: "mithril", percentage: 100 }])).toBe(50);
  });

  // Robustezza su composizione malformata (OCR/scraper/JSONB): la percentage non
  // valida non deve propagarsi come NaN fino al worthy_score. Allineato al guard SQL.
  it("percentage mancante → fibra scartata (nessuna valida → 50)", () => {
    // @ts-expect-error percentage assente di proposito (dato malformato)
    expect(calculateCompositionScore([{ fiber: "cotone" }])).toBe(50);
  });

  it("percentage 0 o negativa → fibra scartata", () => {
    expect(
      calculateCompositionScore([
        { fiber: "cotone", percentage: 0 },
        { fiber: "poliestere", percentage: -10 },
      ]),
    ).toBe(50);
  });

  it("mix valido + malformato → considera solo le fibre valide", () => {
    // solo cotone 100 valido → 72 (poliestere con NaN scartato)
    expect(
      calculateCompositionScore([
        { fiber: "cotone", percentage: 100 },
        { fiber: "poliestere", percentage: NaN },
      ]),
    ).toBe(72);
  });
});
