import type { Verdict } from "../types";

export const VERDICTS = {
  steal: {
    min: 86,
    max: 100,
    label: "Steal",
    emoji: "\uD83D\uDD25",
    description: "Affare incredibile",
  },
  worthy: {
    min: 71,
    max: 85,
    label: "Worthy",
    emoji: "\u2705",
    description: "Vale il prezzo",
  },
  fair: {
    min: 51,
    max: 70,
    label: "Fair",
    emoji: "\uD83D\uDE10",
    description: "Nella media",
  },
  meh: {
    min: 31,
    max: 50,
    label: "Meh",
    emoji: "\uD83D\uDC4E",
    description: "Sotto la media",
  },
  not_worthy: {
    min: 0,
    max: 30,
    label: "Not Worthy",
    emoji: "\uD83D\uDEA9",
    description: "Non vale il prezzo",
  },
} as const satisfies Record<Verdict, { min: number; max: number; label: string; emoji: string; description: string }>;
