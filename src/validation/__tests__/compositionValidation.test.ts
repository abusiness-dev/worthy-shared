import { describe, it, expect } from "vitest";
import { validateComposition } from "../compositionValidation";

describe("validateComposition", () => {
  it("100% cotone → valid", () => {
    const result = validateComposition([{ fiber: "cotone", percentage: 100 }]);
    expect(result.valid).toBe(true);
    expect(result.errors).toHaveLength(0);
  });

  it("70% cotone + 30% poliestere = 100% → valid", () => {
    const result = validateComposition([
      { fiber: "cotone", percentage: 70 },
      { fiber: "poliestere", percentage: 30 },
    ]);
    expect(result.valid).toBe(true);
  });

  it("70% cotone + 25% poliestere = 95% → NOT valid", () => {
    const result = validateComposition([
      { fiber: "cotone", percentage: 70 },
      { fiber: "poliestere", percentage: 25 },
    ]);
    expect(result.valid).toBe(false);
    expect(result.errors.some((e) => e.includes("100%"))).toBe(true);
  });

  it("70% cotone + 31% poliestere = 101% → valid (entro tolleranza)", () => {
    const result = validateComposition([
      { fiber: "cotone", percentage: 70 },
      { fiber: "poliestere", percentage: 31 },
    ]);
    expect(result.valid).toBe(true);
  });

  it("array vuoto → NOT valid", () => {
    const result = validateComposition([]);
    expect(result.valid).toBe(false);
    expect(result.errors.some((e) => e.includes("almeno una fibra"))).toBe(true);
  });

  it("9 fibre → NOT valid (max 8)", () => {
    const fibers = Array.from({ length: 9 }, (_, i) => ({
      fiber: `fibra_${i}`,
      percentage: i < 8 ? 12 : 4,
    }));
    const result = validateComposition(fibers);
    expect(result.valid).toBe(false);
    expect(result.errors.some((e) => e.includes("massimo 8"))).toBe(true);
  });

  it("fibra con percentage 0 → NOT valid", () => {
    const result = validateComposition([{ fiber: "cotone", percentage: 0 }]);
    expect(result.valid).toBe(false);
    expect(result.errors.some((e) => e.includes("maggiore di 0"))).toBe(true);
  });

  it("fibra duplicata → NOT valid", () => {
    const result = validateComposition([
      { fiber: "cotone", percentage: 50 },
      { fiber: "cotone", percentage: 50 },
    ]);
    expect(result.valid).toBe(false);
    expect(result.errors.some((e) => e.includes("duplicate"))).toBe(true);
  });
});
