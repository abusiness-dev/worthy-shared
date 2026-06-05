// Categorie SUPPORTATE dal Worthy Score (solo abbigliamento tessile).
// Calzature, intimo/calze, costumi, accessori e activewear sono ESCLUSE: non
// compaiono qui (quindi nemmeno nei dropdown app) e a DB sono bloccate dal flag
// categories.is_supported + trigger reject_unsupported_category (migration
// 20260605000005). I prodotti legacy in quelle categorie sono stati rimossi
// (migration 20260605000006).
export const CATEGORIES = [
  // Categorie legacy (preservate per compatibilità con prodotti esistenti)
  { slug: "t-shirt", name: "T-Shirt", icon: "👕" },
  { slug: "felpe", name: "Felpe", icon: "🧥" },
  { slug: "jeans", name: "Jeans", icon: "👖" },
  { slug: "pantaloni", name: "Pantaloni", icon: "👖" },
  { slug: "giacche", name: "Giacche", icon: "🧥" },
  { slug: "camicie", name: "Camicie", icon: "👔" },

  // T-shirt & Top
  { slug: "t-shirt-basic", name: "T-shirt basic", icon: "👕" },
  { slug: "t-shirt-oversize", name: "T-shirt oversize", icon: "👕" },
  { slug: "polo", name: "Polo", icon: "👕" },
  { slug: "canotta", name: "Canotte", icon: "🩱" },

  // Camicie
  { slug: "camicia", name: "Camicie", icon: "👔" },

  // Felpe & Maglioni
  { slug: "felpa-cappuccio", name: "Felpe con cappuccio", icon: "🧥" },
  { slug: "felpa-girocollo", name: "Felpe girocollo", icon: "🧥" },
  { slug: "maglione", name: "Maglioni", icon: "🧶" },
  { slug: "cardigan", name: "Cardigan", icon: "🧶" },

  // Giacche
  { slug: "bomber", name: "Bomber", icon: "🧥" },
  { slug: "parka", name: "Parka", icon: "🧥" },
  { slug: "blazer", name: "Blazer", icon: "🧥" },
  { slug: "piumino", name: "Piumini", icon: "🧥" },
  { slug: "giubbotto", name: "Giubbotti", icon: "🧥" },

  // Pantaloni
  { slug: "chinos", name: "Chinos", icon: "👖" },
  { slug: "cargo", name: "Cargo", icon: "👖" },
  { slug: "jogger", name: "Jogger", icon: "👖" },
  { slug: "pantaloni-eleganti", name: "Pantaloni eleganti", icon: "👖" },

  // Jeans
  { slug: "jeans-slim", name: "Jeans slim", icon: "👖" },
  { slug: "jeans-regular", name: "Jeans regular", icon: "👖" },
  { slug: "jeans-wide", name: "Jeans wide leg", icon: "👖" },

  // Shorts
  { slug: "shorts", name: "Shorts", icon: "🩳" },
  { slug: "shorts-sportivi", name: "Shorts sportivi", icon: "🩳" },
] as const;

export type CategorySlug = (typeof CATEGORIES)[number]["slug"];
