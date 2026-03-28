import { describe, it, expect } from "vitest";
import { calculateQPR } from "../calculateQPR";

describe("calculateQPR", () => {
  it("compScore alto + prezzo basso → QPR alto", () => {
    // compScore 90, price 15, avg score 60, avg price 30
    // raw = (90/15) / (60/30) * 100 = 6/2 * 100 = 300
    // sigmoid(300) → very close to 100
    const qpr = calculateQPR(90, 15, 60, 30);
    expect(qpr).toBeGreaterThanOrEqual(80);
  });

  it("compScore basso + prezzo alto → QPR basso", () => {
    // compScore 30, price 100, avg score 60, avg price 30
    // raw = (30/100) / (60/30) * 100 = 0.3/2 * 100 = 15
    // sigmoid(15) → low
    const qpr = calculateQPR(30, 100, 60, 30);
    expect(qpr).toBeLessThanOrEqual(40);
  });

  it("prezzo 0 → 50", () => {
    expect(calculateQPR(80, 0, 60, 30)).toBe(50);
  });

  it("media categoria prezzo 0 → 50", () => {
    expect(calculateQPR(80, 20, 60, 0)).toBe(50);
  });

  it("media categoria score 0 → 50", () => {
    expect(calculateQPR(80, 20, 0, 30)).toBe(50);
  });
});
