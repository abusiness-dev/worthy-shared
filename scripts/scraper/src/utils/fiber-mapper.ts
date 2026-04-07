/**
 * Maps fiber names from brand websites to the canonical names
 * recognized by the @worthy/shared scoring engine.
 *
 * The scorer accepts both Italian and English names (case-insensitive),
 * so we normalize to lowercase Italian names for consistency.
 */

const FIBER_ALIASES: Record<string, string> = {
  // Italian standard
  cotone: "cotone",
  "cotone biologico": "cotone biologico",
  "cotone organico": "cotone biologico",
  "cotone bio": "cotone biologico",
  "cotone supima": "cotone supima",
  "cotone pima": "cotone pima",
  "cotone egiziano": "cotone egiziano",
  poliestere: "poliestere",
  "poliestere riciclato": "poliestere riciclato",
  elastan: "elastan",
  elastane: "elastan",
  "lana merino": "lana merino",
  lana: "lana merino",
  viscosa: "viscosa",
  lino: "lino",
  seta: "seta",
  nylon: "nylon",
  nailon: "nylon",
  poliammide: "nylon",
  acrilico: "acrilico",
  modal: "modal",
  lyocell: "lyocell",
  tencel: "tencel",
  cashmere: "cashmere",
  cachemire: "cashmere",
  rayon: "viscosa",

  // English variants (from H&M, Uniqlo, COS)
  cotton: "cotone",
  "organic cotton": "cotone biologico",
  "supima cotton": "cotone supima",
  "pima cotton": "cotone pima",
  "egyptian cotton": "cotone egiziano",
  polyester: "poliestere",
  "recycled polyester": "poliestere riciclato",
  spandex: "elastan",
  wool: "lana merino",
  "merino wool": "lana merino",
  viscose: "viscosa",
  linen: "lino",
  silk: "seta",
  polyamide: "nylon",
  acrylic: "acrilico",

  // French variants (sometimes on labels)
  coton: "cotone",
  polyamid: "nylon",
  "polyester recycle": "poliestere riciclato",
  "polyester recyclé": "poliestere riciclato",
  soie: "seta",
  lin: "lino",
  laine: "lana merino",
  "laine merinos": "lana merino",

  // Spanish variants (Zara, Massimo Dutti)
  algodón: "cotone",
  algodon: "cotone",
  "algodón orgánico": "cotone biologico",
  poliéster: "poliestere",
  elastano: "elastan",
  seda: "seta",
  "poliéster reciclado": "poliestere riciclato",
};

export function mapFiberName(raw: string): string {
  const normalized = raw.trim().toLowerCase();
  return FIBER_ALIASES[normalized] ?? normalized;
}
