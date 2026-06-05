import { describe, it, expect } from "vitest";
import { calculateQPR, computeQualityIndex } from "../calculateQPR";

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

// Parità con SQL calculate_qpr_cluster (v6): sigmoid 0.025, clamp [15,95],
// quality_index nel numeratore, bonus manufacturing.
describe("calculateQPR — parità SQL", () => {
  it("clamp superiore: raw altissimo → 95 (non 100)", () => {
    // raw = (95/10)/(50/50)*100 = 950 → sigmoid≈100 → clamp 95
    expect(calculateQPR(95, 10, 50, 50)).toBe(95);
  });

  it("clamp inferiore: raw bassissimo → 15 (non 0)", () => {
    // raw = (20/200)/(80/20)*100 = 2.5 → sigmoid≈8 → clamp 15
    expect(calculateQPR(20, 200, 80, 20)).toBe(15);
  });

  it("punto di flesso: raw = 100 → ~50", () => {
    // (70/100)/(70/100)*100 = 100 → sigmoid(100) = 50
    expect(calculateQPR(70, 100, 70, 100)).toBe(50);
  });

  it("quality_index: manufacturing alto alza il QPR (numeratore)", () => {
    const noManuf = calculateQPR(70, 100, 70, 100);
    const withManuf = calculateQPR(70, 100, 70, 100, 90, null);
    expect(withManuf).toBeGreaterThan(noManuf);
  });

  it("bonus manufacturing: scarto positivo vs mediana cluster → QPR più alto", () => {
    const bonusPos = calculateQPR(70, 100, 70, 100, 90, 60); // manuf 90 vs ref 60 → +9
    const noBonus = calculateQPR(70, 100, 70, 100, 90, 90); // scarto 0
    expect(bonusPos).toBeGreaterThan(noBonus);
    expect(bonusPos - noBonus).toBe(9);
  });
});

describe("computeQualityIndex", () => {
  it("manufacturing assente → ritorna composition", () => {
    expect(computeQualityIndex(80, null)).toBe(80);
    expect(computeQualityIndex(80, undefined)).toBe(80);
  });

  it("manufacturing presente → 2/3 comp + 1/3 manuf", () => {
    // (80*0.5 + 60*0.25) / 0.75 = 55 / 0.75 = 73.33
    expect(computeQualityIndex(80, 60)).toBeCloseTo(73.33, 1);
  });
});
