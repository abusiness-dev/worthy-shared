import { describe, it, expect } from "vitest";
import { validatePrice } from "../priceValidation";

describe("validatePrice", () => {
  it("prezzo 9.90 senza composizione → valid, plausible", () => {
    const result = validatePrice(9.90);
    expect(result.valid).toBe(true);
    expect(result.plausible).toBe(true);
  });

  it("prezzo -1 → NOT valid", () => {
    const result = validatePrice(-1);
    expect(result.valid).toBe(false);
  });

  it("prezzo 600 → NOT valid", () => {
    const result = validatePrice(600);
    expect(result.valid).toBe(false);
  });

  it("cashmere 100% a €3 → valid ma NOT plausible", () => {
    const result = validatePrice(3, [{ fiber: "cashmere", percentage: 100 }]);
    expect(result.valid).toBe(true);
    expect(result.plausible).toBe(false);
    expect(result.warning).toBeDefined();
  });

  it("poliestere 100% a €200 → valid ma NOT plausible", () => {
    const result = validatePrice(200, [{ fiber: "poliestere", percentage: 100 }]);
    expect(result.valid).toBe(true);
    expect(result.plausible).toBe(false);
    expect(result.warning).toBeDefined();
  });

  it("cotone 100% a €15 → valid e plausible", () => {
    const result = validatePrice(15, [{ fiber: "cotone", percentage: 100 }]);
    expect(result.valid).toBe(true);
    expect(result.plausible).toBe(true);
    expect(result.warning).toBeUndefined();
  });
});
