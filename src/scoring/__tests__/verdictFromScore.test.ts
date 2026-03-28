import { describe, it, expect } from "vitest";
import { verdictFromScore } from "../verdictFromScore";

describe("verdictFromScore", () => {
  it("100 → steal", () => {
    expect(verdictFromScore(100)).toBe("steal");
  });

  it("86 → steal", () => {
    expect(verdictFromScore(86)).toBe("steal");
  });

  it("85 → worthy", () => {
    expect(verdictFromScore(85)).toBe("worthy");
  });

  it("71 → worthy", () => {
    expect(verdictFromScore(71)).toBe("worthy");
  });

  it("70 → fair", () => {
    expect(verdictFromScore(70)).toBe("fair");
  });

  it("51 → fair", () => {
    expect(verdictFromScore(51)).toBe("fair");
  });

  it("50 → meh", () => {
    expect(verdictFromScore(50)).toBe("meh");
  });

  it("31 → meh", () => {
    expect(verdictFromScore(31)).toBe("meh");
  });

  it("30 → not_worthy", () => {
    expect(verdictFromScore(30)).toBe("not_worthy");
  });

  it("0 → not_worthy", () => {
    expect(verdictFromScore(0)).toBe("not_worthy");
  });
});
