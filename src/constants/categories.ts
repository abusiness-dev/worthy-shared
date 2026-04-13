export const CATEGORIES = [
  // Categorie legacy (9 originali) — preservate per compatibilità con prodotti esistenti
  { slug: "t-shirt", name: "T-Shirt", icon: "\uD83D\uDC55" },
  { slug: "felpe", name: "Felpe", icon: "\uD83E\uDDE5" },
  { slug: "jeans", name: "Jeans", icon: "\uD83D\uDC56" },
  { slug: "pantaloni", name: "Pantaloni", icon: "\uD83D\uDC56" },
  { slug: "giacche", name: "Giacche", icon: "\uD83E\uDDE5" },
  { slug: "sneakers", name: "Sneakers", icon: "\uD83D\uDC5F" },
  { slug: "camicie", name: "Camicie", icon: "\uD83D\uDC54" },
  { slug: "intimo", name: "Intimo", icon: "\uD83A\uDE72" },
  { slug: "accessori", name: "Accessori", icon: "\uD83E\uDDE3" },

  // T-shirt & Top
  { slug: "t-shirt-basic", name: "T-shirt basic", icon: "\uD83D\uDC55" },
  { slug: "t-shirt-oversize", name: "T-shirt oversize", icon: "\uD83D\uDC55" },
  { slug: "polo", name: "Polo", icon: "\uD83D\uDC55" },
  { slug: "canotta", name: "Canotte", icon: "\uD83E\uDE71" },
  { slug: "top-sportivo", name: "Top sportivi", icon: "\uD83D\uDCAA" },

  // Camicie
  { slug: "camicia", name: "Camicie", icon: "\uD83D\uDC54" },

  // Felpe & Maglioni
  { slug: "felpa-cappuccio", name: "Felpe con cappuccio", icon: "\uD83E\uDDE5" },
  { slug: "felpa-girocollo", name: "Felpe girocollo", icon: "\uD83E\uDDE5" },
  { slug: "maglione", name: "Maglioni", icon: "\uD83E\uDDF6" },
  { slug: "cardigan", name: "Cardigan", icon: "\uD83E\uDDF6" },

  // Giacche
  { slug: "bomber", name: "Bomber", icon: "\uD83E\uDDE5" },
  { slug: "parka", name: "Parka", icon: "\uD83E\uDDE5" },
  { slug: "blazer", name: "Blazer", icon: "\uD83E\uDDE5" },
  { slug: "piumino", name: "Piumini", icon: "\uD83E\uDDE5" },
  { slug: "giubbotto", name: "Giubbotti", icon: "\uD83E\uDDE5" },

  // Pantaloni
  { slug: "chinos", name: "Chinos", icon: "\uD83D\uDC56" },
  { slug: "cargo", name: "Cargo", icon: "\uD83D\uDC56" },
  { slug: "jogger", name: "Jogger", icon: "\uD83D\uDC56" },
  { slug: "pantaloni-eleganti", name: "Pantaloni eleganti", icon: "\uD83D\uDC56" },

  // Jeans
  { slug: "jeans-slim", name: "Jeans slim", icon: "\uD83D\uDC56" },
  { slug: "jeans-regular", name: "Jeans regular", icon: "\uD83D\uDC56" },
  { slug: "jeans-wide", name: "Jeans wide leg", icon: "\uD83D\uDC56" },

  // Shorts
  { slug: "shorts", name: "Shorts", icon: "\uD83E\uDE73" },
  { slug: "shorts-sportivi", name: "Shorts sportivi", icon: "\uD83E\uDE73" },

  // Intimo & calze (intimo slug già presente nelle legacy)
  { slug: "calzini", name: "Calzini", icon: "\uD83E\uDDE6" },

  // Scarpe (sneakers slug già presente nelle legacy)
  { slug: "scarpe-eleganti", name: "Scarpe eleganti", icon: "\uD83D\uDC5E" },

  // Accessori
  { slug: "cappelli", name: "Cappelli", icon: "\uD83E\uDDE2" },
  { slug: "sciarpe", name: "Sciarpe", icon: "\uD83E\uDDE3" },
  { slug: "cinture", name: "Cinture", icon: "\uD83D\uDC54" },
  { slug: "borse", name: "Borse", icon: "\uD83D\uDC5C" },

  // Costumi
  { slug: "costume", name: "Costumi", icon: "\uD83E\uDE71" },

  // Activewear
  { slug: "leggings", name: "Leggings", icon: "\uD83E\uDDB5" },
  { slug: "tuta", name: "Tute sportive", icon: "\uD83C\uDFC3" },
] as const;

export type CategorySlug = (typeof CATEGORIES)[number]["slug"];
