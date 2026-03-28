import type { Verdict } from "../types";

export function verdictFromScore(score: number): Verdict {
  if (score >= 86) return "steal";
  if (score >= 71) return "worthy";
  if (score >= 51) return "fair";
  if (score >= 31) return "meh";
  return "not_worthy";
}
