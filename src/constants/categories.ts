export const CATEGORIES = [
  { slug: "t-shirt", name: "T-Shirt", icon: "\uD83D\uDC55" },
  { slug: "felpe", name: "Felpe", icon: "\uD83E\uDDE5" },
  { slug: "jeans", name: "Jeans", icon: "\uD83D\uDC56" },
  { slug: "pantaloni", name: "Pantaloni", icon: "\uD83D\uDC56" },
  { slug: "giacche", name: "Giacche", icon: "\uD83E\uDDE5" },
  { slug: "sneakers", name: "Sneakers", icon: "\uD83D\uDC5F" },
  { slug: "camicie", name: "Camicie", icon: "\uD83D\uDC54" },
  { slug: "intimo", name: "Intimo", icon: "\uD83A\uDE72" },
  { slug: "accessori", name: "Accessori", icon: "\uD83E\uDDE3" },
] as const;

export type CategorySlug = (typeof CATEGORIES)[number]["slug"];
