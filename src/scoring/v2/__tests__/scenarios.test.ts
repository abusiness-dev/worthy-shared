import { describe, it, expect } from "vitest";
import { calculateWorthyScoreV2 } from "../calculateWorthyScoreV2";
import type { WorthyScoreV2Input } from "../../../types/scoring";

// Scenari simbolo end-to-end. Pesi:
//   composition 0.50, manufacturing 0.25, qpr 0.20, sustainability 0.05
// Formula: raw = Σ (component × weight) / Σ (weight) [solo componenti non-null]

describe("Worthy Score v2 - scenari simbolo", () => {
  it("scenario 1 - cotone fast-fashion Bangladesh 25€ → fair", () => {
    const input: WorthyScoreV2Input = {
      composition: [{ fiber: "cotton", percentage: 100 }],
      price: 25,
      category: { avgCompositionScore: 60, avgPrice: 20 },
      manufacturing: { productionCountry: "BD" },
    };
    const r = calculateWorthyScoreV2(input);
    expect(r.score).toBeGreaterThanOrEqual(50);
    expect(r.score).toBeLessThanOrEqual(60);
    expect(r.verdict).toBe("fair");
    expect(r.confidence).toBe(95);
  });

  it("scenario 2 - cotone egiziano Italy 80€ → worthy", () => {
    const input: WorthyScoreV2Input = {
      composition: [{ fiber: "egyptian cotton", percentage: 100 }],
      price: 80,
      category: { avgCompositionScore: 70, avgPrice: 60 },
      manufacturing: { productionCountry: "IT" },
    };
    const r = calculateWorthyScoreV2(input);
    expect(r.score).toBeGreaterThanOrEqual(78);
    expect(r.score).toBeLessThanOrEqual(86);
    expect(r.verdict).toBe("worthy");
    expect(r.confidence).toBe(95);
  });

  it("scenario 3 - lana merino RWS Italy 200€ → worthy", () => {
    const input: WorthyScoreV2Input = {
      composition: [{ fiber: "merino wool", percentage: 100 }],
      price: 200,
      category: { avgCompositionScore: 78, avgPrice: 100 },
      manufacturing: { productionCountry: "IT" },
      productCertifications: ["rws"],
    };
    const r = calculateWorthyScoreV2(input);
    expect(r.score).toBeGreaterThanOrEqual(70);
    expect(r.score).toBeLessThanOrEqual(78);
    expect(r.verdict).toBe("worthy");
    expect(r.confidence).toBe(100);
  });

  it("scenario 4 - lana cinese 60€ → worthy (qpr alto compensa filiera bassa)", () => {
    const input: WorthyScoreV2Input = {
      composition: [{ fiber: "wool", percentage: 100 }],
      price: 60,
      category: { avgCompositionScore: 78, avgPrice: 100 },
      manufacturing: { productionCountry: "CN" },
    };
    const r = calculateWorthyScoreV2(input);
    expect(r.score).toBeGreaterThanOrEqual(72);
    expect(r.score).toBeLessThanOrEqual(80);
  });

  it("scenario 5 - Shein 100% PET Cina 12€ → meh", () => {
    const input: WorthyScoreV2Input = {
      composition: [{ fiber: "polyester", percentage: 100 }],
      price: 12,
      category: { avgCompositionScore: 60, avgPrice: 20 },
      manufacturing: { productionCountry: "CN" },
    };
    const r = calculateWorthyScoreV2(input);
    expect(r.score).toBeGreaterThanOrEqual(28);
    expect(r.score).toBeLessThanOrEqual(36);
    expect(r.verdict).toBe("meh");
  });

  it("scenario 6 - cashmere Mongolia GCS Italy 1200€ → worthy", () => {
    const input: WorthyScoreV2Input = {
      composition: [{ fiber: "cashmere", percentage: 100 }],
      price: 1200,
      category: { avgCompositionScore: 78, avgPrice: 100 },
      manufacturing: { productionCountry: "IT" },
      productCertifications: ["gcs", "made_in_italy_100"],
    };
    const r = calculateWorthyScoreV2(input);
    expect(r.score).toBeGreaterThanOrEqual(72);
    expect(r.score).toBeLessThanOrEqual(82);
    expect(r.verdict).toBe("worthy");
  });

  it("scenario 7 - capo legacy (solo composition+price) → confidence 70", () => {
    const input: WorthyScoreV2Input = {
      composition: [
        { fiber: "cotton", percentage: 70 },
        { fiber: "polyester", percentage: 30 },
      ],
      price: 25,
      category: { avgCompositionScore: 60, avgPrice: 20 },
    };
    const r = calculateWorthyScoreV2(input);
    expect(r.confidence).toBe(70);
    expect(r.breakdown.lenses.composition.used).toBe(true);
    expect(r.breakdown.lenses.qpr.used).toBe(true);
    expect(r.breakdown.lenses.manufacturing.used).toBe(false);
    expect(r.breakdown.lenses.sustainability.used).toBe(false);
  });
});

describe("Worthy Score v2 - graceful degradation", () => {
  it("solo composition+qpr (manufacturing+sustainability null) - nessun crash", () => {
    const r = calculateWorthyScoreV2({
      composition: [{ fiber: "cotton", percentage: 100 }],
      price: 30,
      category: { avgCompositionScore: 60, avgPrice: 25 },
    });
    expect(r.score).toBeGreaterThan(0);
    expect(r.score).toBeLessThanOrEqual(100);
    expect(r.confidence).toBe(70);
  });

  it("confidence 100% solo se TUTTE le 4 lenti hanno dati", () => {
    const r = calculateWorthyScoreV2({
      composition: [{ fiber: "merino wool", percentage: 100 }],
      price: 200,
      category: { avgCompositionScore: 78, avgPrice: 100 },
      manufacturing: { productionCountry: "IT" },
      productCertifications: ["rws"],
    });
    expect(r.confidence).toBe(100);
  });
});

describe("Worthy Score v2 - breakdown", () => {
  it("breakdown espone le 4 lenti con i pesi nuovi", () => {
    const r = calculateWorthyScoreV2({
      composition: [{ fiber: "cotton", percentage: 100 }],
      price: 30,
      category: { avgCompositionScore: 60, avgPrice: 25 },
      manufacturing: { productionCountry: "IT" },
      productCertifications: ["gots"],
    });
    expect(r.breakdown.weights).toEqual({
      composition: 0.50,
      manufacturing: 0.25,
      qpr: 0.20,
      sustainability: 0.05,
    });
    expect(Object.keys(r.breakdown.lenses).sort()).toEqual([
      "composition",
      "manufacturing",
      "qpr",
      "sustainability",
    ]);
  });
});
