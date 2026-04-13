export const FIBERS = [
  { id: "cashmere", nameIT: "Cashmere", score: 98, tier: "premium" },
  { id: "silk", nameIT: "Seta", score: 95, tier: "premium" },
  { id: "merino_wool", nameIT: "Lana Merino", score: 92, tier: "premium" },
  { id: "supima_cotton", nameIT: "Cotone Supima", score: 90, tier: "premium" },
  { id: "pima_cotton", nameIT: "Cotone Pima", score: 90, tier: "premium" },
  { id: "egyptian_cotton", nameIT: "Cotone Egiziano", score: 90, tier: "premium" },
  { id: "linen", nameIT: "Lino", score: 88, tier: "alto" },
  { id: "organic_cotton", nameIT: "Cotone Biologico", score: 85, tier: "alto" },
  { id: "lyocell", nameIT: "Lyocell", score: 82, tier: "alto" },
  { id: "tencel", nameIT: "Tencel", score: 82, tier: "alto" },
  { id: "wool", nameIT: "Lana", score: 78, tier: "alto" },
  { id: "cotton", nameIT: "Cotone", score: 72, tier: "medio_alto" },
  { id: "modal", nameIT: "Modal", score: 68, tier: "medio_alto" },
  { id: "cupro", nameIT: "Cupro", score: 65, tier: "medio_alto" },
  { id: "viscose", nameIT: "Viscosa", score: 52, tier: "medio" },
  { id: "rayon", nameIT: "Rayon", score: 52, tier: "medio" },
  { id: "nylon", nameIT: "Nylon", score: 45, tier: "medio" },
  { id: "polyamide", nameIT: "Poliammide", score: 45, tier: "medio" },
  { id: "recycled_polyester", nameIT: "Poliestere Riciclato", score: 42, tier: "medio_basso" },
  { id: "polyester", nameIT: "Poliestere", score: 25, tier: "basso" },
  { id: "acrylic", nameIT: "Acrilico", score: 15, tier: "basso" },
  { id: "elastane", nameIT: "Elastan", score: 0, tier: "neutro" },
  { id: "spandex", nameIT: "Spandex", score: 0, tier: "neutro" },
] as const;

export type FiberId = (typeof FIBERS)[number]["id"];
export type FiberTier = (typeof FIBERS)[number]["tier"];
