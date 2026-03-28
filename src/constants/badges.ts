export const BADGES = [
  {
    id: "fashion_scout",
    name: "Fashion Scout",
    description: "Hai iniziato a contribuire!",
    icon: "\uD83D\uDD0D",
    pointsRequired: 50,
    benefit: "Badge visibile sul profilo",
  },
  {
    id: "style_expert",
    name: "Style Expert",
    description: "Contributor esperto",
    icon: "\u2B50",
    pointsRequired: 200,
    benefit: "Accesso anticipato nuove review",
  },
  {
    id: "database_hero",
    name: "Database Hero",
    description: "Il database ti ringrazia",
    icon: "\uD83C\uDFC6",
    pointsRequired: 500,
    benefit: "Prodotti senza revisione",
  },
  {
    id: "worthy_legend",
    name: "Worthy Legend",
    description: "Leggenda della community",
    icon: "\uD83D\uDC51",
    pointsRequired: 1000,
    benefit: "Menzione stories Mattia",
  },
  {
    id: "top_contributor",
    name: "Top Contributor",
    description: "Top 10 del mese",
    icon: "\uD83E\uDD47",
    pointsRequired: 0,
    benefit: "Badge esclusivo + shoutout",
  },
] as const;

export type BadgeId = (typeof BADGES)[number]["id"];
