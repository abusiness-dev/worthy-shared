// Tabella fibra → punteggio (0-100). Nomi supportati in italiano e inglese,
// sia con underscore che con spazi, per matchare i formati in ingresso più comuni.

export const FIBER_SCORES: Record<string, number> = {
  // Premium (85-100)
  cashmere: 98,
  seta: 95,
  silk: 95,
  lana_merino: 92,
  "lana merino": 92,
  "merino wool": 92,
  merino: 92,
  cotone_supima: 90,
  "cotone supima": 90,
  "supima cotton": 90,
  cotone_pima: 90,
  "cotone pima": 90,
  "pima cotton": 90,
  cotone_egiziano: 90,
  "cotone egiziano": 90,
  "egyptian cotton": 90,
  lino: 88,
  linen: 88,
  cotone_biologico: 85,
  "cotone biologico": 85,
  "organic cotton": 85,

  // Alto (70-84)
  lyocell: 82,
  tencel: 82,
  lana: 78,
  wool: 78,
  cotone: 72,
  cotton: 72,

  // Medio (50-69)
  modal: 68,
  cupro: 65,
  viscosa: 52,
  viscose: 52,
  rayon: 52,

  // Sintetici (0-49)
  nylon: 45,
  nailon: 45,
  polyamide: 45,
  poliammide: 45,
  poliestere_riciclato: 42,
  "poliestere riciclato": 42,
  "recycled polyester": 42,
  poliestere: 25,
  polyester: 25,
  acrilico: 15,
  acrylic: 15,
};

// Fibre elastiche trattate con regola speciale: ignorate fino al 5%,
// penalizzate 40 tra 6-10% e 20 oltre il 10%.
export const ELASTANE_FIBERS = ["elastane", "elastan", "spandex"];
export const ELASTANE_IGNORE_THRESHOLD = 5;
export const ELASTANE_LOW_THRESHOLD = 10;
export const ELASTANE_SCORE_LOW = 40;
export const ELASTANE_SCORE_HIGH = 20;

export const DEFAULT_FIBER_SCORE = 50;

export function isElastane(fiber: string): boolean {
  return ELASTANE_FIBERS.includes(fiber.toLowerCase());
}

export function elastaneScore(percentage: number): number | null {
  if (percentage <= ELASTANE_IGNORE_THRESHOLD) return null;
  if (percentage <= ELASTANE_LOW_THRESHOLD) return ELASTANE_SCORE_LOW;
  return ELASTANE_SCORE_HIGH;
}
