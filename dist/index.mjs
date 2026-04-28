// src/scoring/fiberScores.ts
var FIBER_SCORES = {
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
  acrylic: 15
};
var ELASTANE_FIBERS = ["elastane", "elastan", "spandex"];
var ELASTANE_IGNORE_THRESHOLD = 5;
var ELASTANE_LOW_THRESHOLD = 10;
var ELASTANE_SCORE_LOW = 40;
var ELASTANE_SCORE_HIGH = 20;
var DEFAULT_FIBER_SCORE = 50;
function isElastane(fiber) {
  return ELASTANE_FIBERS.includes(fiber.toLowerCase());
}
function elastaneScore(percentage) {
  if (percentage <= ELASTANE_IGNORE_THRESHOLD) return null;
  if (percentage <= ELASTANE_LOW_THRESHOLD) return ELASTANE_SCORE_LOW;
  return ELASTANE_SCORE_HIGH;
}

// src/scoring/calculateComposition.ts
function calculateCompositionScore(composition) {
  if (composition.length === 0) return 50;
  const scored = composition.map((c) => {
    const fiber = c.fiber.toLowerCase();
    if (isElastane(fiber)) {
      if (c.percentage <= ELASTANE_IGNORE_THRESHOLD) return null;
      return { percentage: c.percentage, score: elastaneScore(c.percentage) };
    }
    const score = FIBER_SCORES[fiber] ?? DEFAULT_FIBER_SCORE;
    return { percentage: c.percentage, score };
  }).filter((x) => x !== null);
  if (scored.length === 0) return 50;
  const totalPercentage = scored.reduce((sum, c) => sum + c.percentage, 0);
  if (totalPercentage === 0) return 50;
  const weightedSum = scored.reduce((sum, c) => sum + c.score * c.percentage, 0);
  return Math.round(Math.min(100, Math.max(0, weightedSum / totalPercentage)));
}

// src/scoring/calculateQPR.ts
function sigmoid(x) {
  return 100 / (1 + Math.exp(-0.05 * (x - 100)));
}
function calculateQPR(compScore, price, refScore, refPrice) {
  if (price <= 0 || refPrice <= 0 || refScore <= 0) return 50;
  const raw = compScore / price / (refScore / refPrice) * 100;
  return Math.round(Math.min(100, Math.max(0, sigmoid(raw))));
}

// src/scoring/verdictFromScore.ts
function verdictFromScore(score) {
  if (score >= 86) return "steal";
  if (score >= 71) return "worthy";
  if (score >= 51) return "fair";
  if (score >= 31) return "meh";
  return "not_worthy";
}

// src/scoring/calculateWorthyScore.ts
function calculateWorthyScore(params) {
  const { compositionScore, qprScore } = params;
  const raw = compositionScore * 0.7 + qprScore * 0.3;
  const score = Math.round(Math.min(100, Math.max(0, raw)));
  return {
    score,
    verdict: verdictFromScore(score),
    breakdown: {
      composition: compositionScore,
      qpr: qprScore
    }
  };
}

// src/types/scoring.ts
var WORTHY_SCORE_V2_WEIGHTS = {
  composition: 0.5,
  manufacturing: 0.25,
  qpr: 0.2,
  sustainability: 0.05
};

// src/scoring/v2/lenses/compositionLens.ts
function compositionLens(composition) {
  return calculateCompositionScore(composition);
}

// src/scoring/v2/lenses/qprLens.ts
function qprLens(compositionScore, price, refCompositionScore, refPrice) {
  return calculateQPR(compositionScore, price, refCompositionScore, refPrice);
}

// src/constants/countries.ts
var COUNTRIES = {
  // Tier 1
  IT: { iso2: "IT", name_it: "Italia", region: "EU", manufacturing_tier: 1, manufacturing_score: 95 },
  JP: { iso2: "JP", name_it: "Giappone", region: "Asia", manufacturing_tier: 1, manufacturing_score: 92 },
  CH: { iso2: "CH", name_it: "Svizzera", region: "EU", manufacturing_tier: 1, manufacturing_score: 90 },
  // Tier 2
  DE: { iso2: "DE", name_it: "Germania", region: "EU", manufacturing_tier: 2, manufacturing_score: 82 },
  PT: { iso2: "PT", name_it: "Portogallo", region: "EU", manufacturing_tier: 2, manufacturing_score: 80 },
  AT: { iso2: "AT", name_it: "Austria", region: "EU", manufacturing_tier: 2, manufacturing_score: 80 },
  FR: { iso2: "FR", name_it: "Francia", region: "EU", manufacturing_tier: 2, manufacturing_score: 80 },
  BE: { iso2: "BE", name_it: "Belgio", region: "EU", manufacturing_tier: 2, manufacturing_score: 78 },
  NL: { iso2: "NL", name_it: "Paesi Bassi", region: "EU", manufacturing_tier: 2, manufacturing_score: 78 },
  GB: { iso2: "GB", name_it: "Regno Unito", region: "EU", manufacturing_tier: 2, manufacturing_score: 78 },
  US: { iso2: "US", name_it: "Stati Uniti", region: "Americas", manufacturing_tier: 2, manufacturing_score: 78 },
  ES: { iso2: "ES", name_it: "Spagna", region: "EU", manufacturing_tier: 2, manufacturing_score: 78 },
  DK: { iso2: "DK", name_it: "Danimarca", region: "EU", manufacturing_tier: 2, manufacturing_score: 75 },
  SE: { iso2: "SE", name_it: "Svezia", region: "EU", manufacturing_tier: 2, manufacturing_score: 75 },
  NO: { iso2: "NO", name_it: "Norvegia", region: "EU", manufacturing_tier: 2, manufacturing_score: 75 },
  FI: { iso2: "FI", name_it: "Finlandia", region: "EU", manufacturing_tier: 2, manufacturing_score: 75 },
  KR: { iso2: "KR", name_it: "Corea del Sud", region: "Asia", manufacturing_tier: 2, manufacturing_score: 75 },
  TR: { iso2: "TR", name_it: "Turchia", region: "Asia", manufacturing_tier: 2, manufacturing_score: 72 },
  RO: { iso2: "RO", name_it: "Romania", region: "EU", manufacturing_tier: 2, manufacturing_score: 70 },
  HU: { iso2: "HU", name_it: "Ungheria", region: "EU", manufacturing_tier: 2, manufacturing_score: 70 },
  CZ: { iso2: "CZ", name_it: "Repubblica Ceca", region: "EU", manufacturing_tier: 2, manufacturing_score: 70 },
  PL: { iso2: "PL", name_it: "Polonia", region: "EU", manufacturing_tier: 2, manufacturing_score: 70 },
  AU: { iso2: "AU", name_it: "Australia", region: "Oceania", manufacturing_tier: 2, manufacturing_score: 70 },
  NZ: { iso2: "NZ", name_it: "Nuova Zelanda", region: "Oceania", manufacturing_tier: 2, manufacturing_score: 70 },
  // Tier 3
  TW: { iso2: "TW", name_it: "Taiwan", region: "Asia", manufacturing_tier: 3, manufacturing_score: 65 },
  BG: { iso2: "BG", name_it: "Bulgaria", region: "EU", manufacturing_tier: 3, manufacturing_score: 60 },
  VN: { iso2: "VN", name_it: "Vietnam", region: "Asia", manufacturing_tier: 3, manufacturing_score: 58 },
  CN: { iso2: "CN", name_it: "Cina", region: "Asia", manufacturing_tier: 3, manufacturing_score: 55 },
  TH: { iso2: "TH", name_it: "Thailandia", region: "Asia", manufacturing_tier: 3, manufacturing_score: 55 },
  PE: { iso2: "PE", name_it: "Per\xF9", region: "Americas", manufacturing_tier: 3, manufacturing_score: 55 },
  IN: { iso2: "IN", name_it: "India", region: "Asia", manufacturing_tier: 3, manufacturing_score: 52 },
  MX: { iso2: "MX", name_it: "Messico", region: "Americas", manufacturing_tier: 3, manufacturing_score: 52 },
  BR: { iso2: "BR", name_it: "Brasile", region: "Americas", manufacturing_tier: 3, manufacturing_score: 52 },
  IL: { iso2: "IL", name_it: "Israele", region: "Asia", manufacturing_tier: 3, manufacturing_score: 50 },
  TN: { iso2: "TN", name_it: "Tunisia", region: "Africa", manufacturing_tier: 3, manufacturing_score: 50 },
  EG: { iso2: "EG", name_it: "Egitto", region: "Africa", manufacturing_tier: 3, manufacturing_score: 50 },
  PK: { iso2: "PK", name_it: "Pakistan", region: "Asia", manufacturing_tier: 3, manufacturing_score: 50 },
  MN: { iso2: "MN", name_it: "Mongolia", region: "Asia", manufacturing_tier: 3, manufacturing_score: 50 },
  AG: { iso2: "AG", name_it: "Antigua e Barbuda", region: "Americas", manufacturing_tier: 3, manufacturing_score: 50 },
  MY: { iso2: "MY", name_it: "Malesia", region: "Asia", manufacturing_tier: 3, manufacturing_score: 48 },
  ID: { iso2: "ID", name_it: "Indonesia", region: "Asia", manufacturing_tier: 3, manufacturing_score: 45 },
  MA: { iso2: "MA", name_it: "Marocco", region: "Africa", manufacturing_tier: 3, manufacturing_score: 45 },
  IR: { iso2: "IR", name_it: "Iran", region: "Asia", manufacturing_tier: 3, manufacturing_score: 45 },
  KZ: { iso2: "KZ", name_it: "Kazakistan", region: "Asia", manufacturing_tier: 3, manufacturing_score: 45 },
  LK: { iso2: "LK", name_it: "Sri Lanka", region: "Asia", manufacturing_tier: 3, manufacturing_score: 45 },
  PH: { iso2: "PH", name_it: "Filippine", region: "Asia", manufacturing_tier: 3, manufacturing_score: 42 },
  // Tier 4
  AF: { iso2: "AF", name_it: "Afghanistan", region: "Asia", manufacturing_tier: 4, manufacturing_score: 35 },
  BD: { iso2: "BD", name_it: "Bangladesh", region: "Asia", manufacturing_tier: 4, manufacturing_score: 30 },
  NP: { iso2: "NP", name_it: "Nepal", region: "Asia", manufacturing_tier: 4, manufacturing_score: 30 },
  KH: { iso2: "KH", name_it: "Cambogia", region: "Asia", manufacturing_tier: 4, manufacturing_score: 25 },
  ET: { iso2: "ET", name_it: "Etiopia", region: "Africa", manufacturing_tier: 4, manufacturing_score: 25 },
  HT: { iso2: "HT", name_it: "Haiti", region: "Americas", manufacturing_tier: 4, manufacturing_score: 25 },
  MM: { iso2: "MM", name_it: "Myanmar", region: "Asia", manufacturing_tier: 4, manufacturing_score: 20 }
};
function getCountry(iso2) {
  if (!iso2) return void 0;
  return COUNTRIES[iso2.toUpperCase()];
}
function manufacturingScoreFor(iso2) {
  const country = getCountry(iso2);
  return country ? country.manufacturing_score : null;
}

// src/scoring/v2/lenses/manufacturingLens.ts
var STEP_WEIGHTS = {
  production: 0.5,
  // last substantial transformation: peso maggiore
  weaving: 0.25,
  spinning: 0.15,
  dyeing: 0.1
};
function manufacturingLens(input) {
  let weightedSum = 0;
  let totalWeight = 0;
  const addStep = (iso2, weight) => {
    if (!iso2) return;
    const score = manufacturingScoreFor(iso2);
    if (score === null) return;
    weightedSum += score * weight;
    totalWeight += weight;
  };
  addStep(input.productionCountry, STEP_WEIGHTS.production);
  addStep(input.weavingCountry, STEP_WEIGHTS.weaving);
  addStep(input.spinningCountry, STEP_WEIGHTS.spinning);
  addStep(input.dyeingCountry, STEP_WEIGHTS.dyeing);
  if (totalWeight === 0) return null;
  let result = weightedSum / totalWeight;
  if (input.hasMadeInItaly100) {
    result += 8;
  }
  return Math.min(100, Math.max(0, result));
}

// src/constants/certifications.ts
var CERTIFICATIONS = {
  // Fiber-level
  gots: { id: "gots", display_name: "GOTS (Global Organic Textile Standard)", scope: "fiber", bonus_points: 15 },
  rws: { id: "rws", display_name: "RWS (Responsible Wool Standard)", scope: "fiber", bonus_points: 12 },
  gcs: { id: "gcs", display_name: "GCS (Good Cashmere Standard)", scope: "fiber", bonus_points: 12 },
  grs_50: { id: "grs_50", display_name: "GRS 50%+ (Global Recycled Standard)", scope: "fiber", bonus_points: 10 },
  rds: { id: "rds", display_name: "RDS (Responsible Down Standard)", scope: "fiber", bonus_points: 10 },
  better_cotton_bci: { id: "better_cotton_bci", display_name: "Better Cotton Initiative (BCI)", scope: "fiber", bonus_points: 6 },
  rcs: { id: "rcs", display_name: "RCS (Recycled Claim Standard)", scope: "fiber", bonus_points: 6 },
  // Product-level
  oeko_tex_100: { id: "oeko_tex_100", display_name: "OEKO-TEX Standard 100", scope: "product", bonus_points: 5 },
  oeko_tex_made_in_green: { id: "oeko_tex_made_in_green", display_name: "OEKO-TEX Made in Green", scope: "product", bonus_points: 12 },
  cradle_to_cradle_gold: { id: "cradle_to_cradle_gold", display_name: "Cradle to Cradle Gold", scope: "product", bonus_points: 14 },
  cradle_to_cradle_silver: { id: "cradle_to_cradle_silver", display_name: "Cradle to Cradle Silver", scope: "product", bonus_points: 10 },
  cradle_to_cradle_bronze: { id: "cradle_to_cradle_bronze", display_name: "Cradle to Cradle Bronze", scope: "product", bonus_points: 6 },
  // Process-level
  bluesign: { id: "bluesign", display_name: "Bluesign System Partner", scope: "process", bonus_points: 10 },
  fair_trade: { id: "fair_trade", display_name: "Fair Trade Certified", scope: "process", bonus_points: 10 },
  sa8000: { id: "sa8000", display_name: "SA8000 (Social Accountability)", scope: "process", bonus_points: 8 },
  wrap: { id: "wrap", display_name: "WRAP (Worldwide Responsible Accredited Production)", scope: "process", bonus_points: 6 },
  // Brand-level
  b_corp_80plus: { id: "b_corp_80plus", display_name: "B Corp (80+ score)", scope: "brand", bonus_points: 8 },
  "1_percent_for_planet": { id: "1_percent_for_planet", display_name: "1% for the Planet", scope: "brand", bonus_points: 4 },
  // Manufacturing-level
  made_in_italy_100: { id: "made_in_italy_100", display_name: "100% Made in Italy", scope: "manufacturing", bonus_points: 8 },
  made_green_italy: { id: "made_green_italy", display_name: "Made Green in Italy", scope: "manufacturing", bonus_points: 10 }
};
function getCertification(id) {
  if (!id) return void 0;
  return CERTIFICATIONS[id];
}
function bonusFor(id) {
  const cert = getCertification(id);
  return cert ? cert.bonus_points : 0;
}

// src/scoring/v2/lenses/sustainabilityLens.ts
function sustainabilityLens(input) {
  const total = input.productCertifications.reduce((sum, id) => sum + bonusFor(id), 0) + input.brandCertifications.reduce((sum, id) => sum + bonusFor(id), 0);
  if (total === 0) return null;
  return Math.min(100, Math.max(0, total));
}

// src/scoring/v2/calculateWorthyScoreV2.ts
var FULL_WEIGHTS_SUM = Object.values(WORTHY_SCORE_V2_WEIGHTS).reduce((a, b) => a + b, 0);
function calculateWorthyScoreV2(input) {
  const compositionScore = compositionLens(input.composition);
  const hasMadeInItaly100 = (input.productCertifications ?? []).includes("made_in_italy_100");
  const manufacturingScore = manufacturingLens({
    productionCountry: input.manufacturing?.productionCountry,
    weavingCountry: input.manufacturing?.weavingCountry,
    spinningCountry: input.manufacturing?.spinningCountry,
    dyeingCountry: input.manufacturing?.dyeingCountry,
    hasMadeInItaly100
  });
  const qprScore = qprLens(
    compositionScore,
    input.price,
    input.category.avgCompositionScore,
    input.category.avgPrice
  );
  const sustainabilityScore = sustainabilityLens({
    productCertifications: input.productCertifications ?? [],
    brandCertifications: input.brandCertifications ?? []
  });
  let weightedSum = 0;
  let usedWeight = 0;
  weightedSum += compositionScore * WORTHY_SCORE_V2_WEIGHTS.composition;
  usedWeight += WORTHY_SCORE_V2_WEIGHTS.composition;
  if (manufacturingScore !== null) {
    weightedSum += manufacturingScore * WORTHY_SCORE_V2_WEIGHTS.manufacturing;
    usedWeight += WORTHY_SCORE_V2_WEIGHTS.manufacturing;
  }
  weightedSum += qprScore * WORTHY_SCORE_V2_WEIGHTS.qpr;
  usedWeight += WORTHY_SCORE_V2_WEIGHTS.qpr;
  if (sustainabilityScore !== null) {
    weightedSum += sustainabilityScore * WORTHY_SCORE_V2_WEIGHTS.sustainability;
    usedWeight += WORTHY_SCORE_V2_WEIGHTS.sustainability;
  }
  const raw = weightedSum / usedWeight;
  const final = Math.round(Math.min(100, Math.max(0, raw)));
  const verdict = verdictFromScore(final);
  const confidence = Math.round(usedWeight / FULL_WEIGHTS_SUM * 100);
  const breakdown = {
    version: "v2.0",
    lenses: {
      composition: { score: compositionScore, used: true },
      manufacturing: { score: manufacturingScore, used: manufacturingScore !== null },
      qpr: { score: qprScore, used: true },
      sustainability: { score: sustainabilityScore, used: sustainabilityScore !== null }
    },
    weights: WORTHY_SCORE_V2_WEIGHTS,
    confidence,
    raw: Math.round(raw * 100) / 100,
    final,
    verdict
  };
  return { score: final, verdict, confidence, breakdown };
}

// src/constants/fibers.ts
var FIBERS = [
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
  { id: "spandex", nameIT: "Spandex", score: 0, tier: "neutro" }
];

// src/constants/badges.ts
var BADGES = [
  {
    id: "fashion_scout",
    name: "Fashion Scout",
    description: "Hai iniziato a contribuire!",
    icon: "\u{1F50D}",
    pointsRequired: 50,
    benefit: "Badge visibile sul profilo"
  },
  {
    id: "style_expert",
    name: "Style Expert",
    description: "Contributor esperto",
    icon: "\u2B50",
    pointsRequired: 200,
    benefit: "Accesso anticipato nuove review"
  },
  {
    id: "database_hero",
    name: "Database Hero",
    description: "Il database ti ringrazia",
    icon: "\u{1F3C6}",
    pointsRequired: 500,
    benefit: "Prodotti senza revisione"
  },
  {
    id: "worthy_legend",
    name: "Worthy Legend",
    description: "Leggenda della community",
    icon: "\u{1F451}",
    pointsRequired: 1e3,
    benefit: "Menzione stories Mattia"
  },
  {
    id: "top_contributor",
    name: "Top Contributor",
    description: "Top 10 del mese",
    icon: "\u{1F947}",
    pointsRequired: 0,
    benefit: "Badge esclusivo + shoutout"
  }
];

// src/constants/categories.ts
var CATEGORIES = [
  // Categorie legacy (9 originali) — preservate per compatibilità con prodotti esistenti
  { slug: "t-shirt", name: "T-Shirt", icon: "\u{1F455}" },
  { slug: "felpe", name: "Felpe", icon: "\u{1F9E5}" },
  { slug: "jeans", name: "Jeans", icon: "\u{1F456}" },
  { slug: "pantaloni", name: "Pantaloni", icon: "\u{1F456}" },
  { slug: "giacche", name: "Giacche", icon: "\u{1F9E5}" },
  { slug: "sneakers", name: "Sneakers", icon: "\u{1F45F}" },
  { slug: "camicie", name: "Camicie", icon: "\u{1F454}" },
  { slug: "intimo", name: "Intimo", icon: "\u{1EA72}" },
  { slug: "accessori", name: "Accessori", icon: "\u{1F9E3}" },
  // T-shirt & Top
  { slug: "t-shirt-basic", name: "T-shirt basic", icon: "\u{1F455}" },
  { slug: "t-shirt-oversize", name: "T-shirt oversize", icon: "\u{1F455}" },
  { slug: "polo", name: "Polo", icon: "\u{1F455}" },
  { slug: "canotta", name: "Canotte", icon: "\u{1FA71}" },
  { slug: "top-sportivo", name: "Top sportivi", icon: "\u{1F4AA}" },
  // Camicie
  { slug: "camicia", name: "Camicie", icon: "\u{1F454}" },
  // Felpe & Maglioni
  { slug: "felpa-cappuccio", name: "Felpe con cappuccio", icon: "\u{1F9E5}" },
  { slug: "felpa-girocollo", name: "Felpe girocollo", icon: "\u{1F9E5}" },
  { slug: "maglione", name: "Maglioni", icon: "\u{1F9F6}" },
  { slug: "cardigan", name: "Cardigan", icon: "\u{1F9F6}" },
  // Giacche
  { slug: "bomber", name: "Bomber", icon: "\u{1F9E5}" },
  { slug: "parka", name: "Parka", icon: "\u{1F9E5}" },
  { slug: "blazer", name: "Blazer", icon: "\u{1F9E5}" },
  { slug: "piumino", name: "Piumini", icon: "\u{1F9E5}" },
  { slug: "giubbotto", name: "Giubbotti", icon: "\u{1F9E5}" },
  // Pantaloni
  { slug: "chinos", name: "Chinos", icon: "\u{1F456}" },
  { slug: "cargo", name: "Cargo", icon: "\u{1F456}" },
  { slug: "jogger", name: "Jogger", icon: "\u{1F456}" },
  { slug: "pantaloni-eleganti", name: "Pantaloni eleganti", icon: "\u{1F456}" },
  // Jeans
  { slug: "jeans-slim", name: "Jeans slim", icon: "\u{1F456}" },
  { slug: "jeans-regular", name: "Jeans regular", icon: "\u{1F456}" },
  { slug: "jeans-wide", name: "Jeans wide leg", icon: "\u{1F456}" },
  // Shorts
  { slug: "shorts", name: "Shorts", icon: "\u{1FA73}" },
  { slug: "shorts-sportivi", name: "Shorts sportivi", icon: "\u{1FA73}" },
  // Intimo & calze (intimo slug già presente nelle legacy)
  { slug: "calzini", name: "Calzini", icon: "\u{1F9E6}" },
  // Scarpe (sneakers slug già presente nelle legacy)
  { slug: "scarpe-eleganti", name: "Scarpe eleganti", icon: "\u{1F45E}" },
  // Accessori
  { slug: "cappelli", name: "Cappelli", icon: "\u{1F9E2}" },
  { slug: "sciarpe", name: "Sciarpe", icon: "\u{1F9E3}" },
  { slug: "cinture", name: "Cinture", icon: "\u{1F454}" },
  { slug: "borse", name: "Borse", icon: "\u{1F45C}" },
  // Costumi
  { slug: "costume", name: "Costumi", icon: "\u{1FA71}" },
  // Activewear
  { slug: "leggings", name: "Leggings", icon: "\u{1F9B5}" },
  { slug: "tuta", name: "Tute sportive", icon: "\u{1F3C3}" }
];

// src/constants/brands.ts
var LAUNCH_BRANDS = [
  { name: "Zara", slug: "zara", originCountry: "Spagna", marketSegment: "fast" },
  { name: "H&M", slug: "h-and-m", originCountry: "Svezia", marketSegment: "fast" },
  { name: "Uniqlo", slug: "uniqlo", originCountry: "Giappone", marketSegment: "fast" },
  { name: "Shein", slug: "shein", originCountry: "Cina", marketSegment: "ultra_fast" },
  { name: "Bershka", slug: "bershka", originCountry: "Spagna", marketSegment: "fast" },
  { name: "Pull&Bear", slug: "pull-and-bear", originCountry: "Spagna", marketSegment: "fast" },
  { name: "Stradivarius", slug: "stradivarius", originCountry: "Spagna", marketSegment: "fast" },
  { name: "Primark", slug: "primark", originCountry: "Irlanda", marketSegment: "ultra_fast" },
  { name: "ASOS", slug: "asos", originCountry: "UK", marketSegment: "fast" },
  { name: "Mango", slug: "mango", originCountry: "Spagna", marketSegment: "fast" },
  { name: "COS", slug: "cos", originCountry: "Svezia", marketSegment: "premium_fast" },
  { name: "Massimo Dutti", slug: "massimo-dutti", originCountry: "Spagna", marketSegment: "premium_fast" }
];

// src/constants/verdicts.ts
var VERDICTS = {
  steal: {
    min: 86,
    max: 100,
    label: "Steal",
    emoji: "\u{1F525}",
    description: "Affare incredibile"
  },
  worthy: {
    min: 71,
    max: 85,
    label: "Worthy",
    emoji: "\u2705",
    description: "Vale il prezzo"
  },
  fair: {
    min: 51,
    max: 70,
    label: "Fair",
    emoji: "\u{1F610}",
    description: "Nella media"
  },
  meh: {
    min: 31,
    max: 50,
    label: "Meh",
    emoji: "\u{1F44E}",
    description: "Sotto la media"
  },
  not_worthy: {
    min: 0,
    max: 30,
    label: "Not Worthy",
    emoji: "\u{1F6A9}",
    description: "Non vale il prezzo"
  }
};

// src/constants/limits.ts
var POINTS = {
  scan_existing: 2,
  contribute_product: 15,
  confirm_data: 5,
  report_confirmed: 10,
  first_scan_of_day: 3,
  streak_7_days: 25,
  referral: 20
};
var RATE_LIMITS = {
  products_per_day: 20,
  scans_per_hour: 60,
  votes_per_hour: 30,
  reports_per_day: 10,
  label_scans_per_hour: 15
};
var VALIDATION = {
  product_name_min: 3,
  product_name_max: 200,
  price_min: 0.01,
  price_max: 500,
  composition_fibers_min: 1,
  composition_fibers_max: 8,
  composition_sum_target: 100,
  composition_sum_tolerance: 1,
  vote_score_min: 1,
  vote_score_max: 10
};

// src/constants/marketSegments.ts
var MARKET_SEGMENTS = [
  { id: "ultra_fast", label: "Ultra Fast Fashion" },
  { id: "fast_fashion", label: "Fast Fashion" },
  { id: "premium", label: "Premium" },
  { id: "maison", label: "Maison" }
];

// src/constants/navigation.ts
var NAV_TABS = ["search", "top-rated", "scan", "coach", "saved"];
var ONBOARDING_STEPS = [
  "welcome",
  "value_prop_1",
  "value_prop_2",
  "brand_selection",
  "category_selection",
  "notifications",
  "complete"
];

// src/constants/fiberDescriptions.ts
var FIBER_DESCRIPTIONS = {
  cashmere: "Fibra pregiata, morbidissima e calda. La migliore per maglieria.",
  seta: "Fibra naturale lussuosa, traspirante e ipoallergenica.",
  silk: "Fibra naturale lussuosa, traspirante e ipoallergenica.",
  lana_merino: "Lana fine, termoregolante e non pizzica.",
  "lana merino": "Lana fine, termoregolante e non pizzica.",
  "merino wool": "Lana fine, termoregolante e non pizzica.",
  merino: "Lana fine, termoregolante e non pizzica.",
  cotone_supima: "Cotone a fibra lunga, morbidezza e durata superiori.",
  "cotone supima": "Cotone a fibra lunga, morbidezza e durata superiori.",
  "supima cotton": "Cotone a fibra lunga, morbidezza e durata superiori.",
  cotone_pima: "Cotone a fibra lunga, morbidezza e durata superiori.",
  "cotone pima": "Cotone a fibra lunga, morbidezza e durata superiori.",
  "pima cotton": "Cotone a fibra lunga, morbidezza e durata superiori.",
  cotone_egiziano: "Cotone a fibra lunga, morbidezza e durata superiori.",
  "cotone egiziano": "Cotone a fibra lunga, morbidezza e durata superiori.",
  "egyptian cotton": "Cotone a fibra lunga, morbidezza e durata superiori.",
  lino: "Fibra naturale resistente, fresca e traspirante. Ideale per l'estate.",
  linen: "Fibra naturale resistente, fresca e traspirante. Ideale per l'estate.",
  cotone_biologico: "Cotone coltivato senza pesticidi, buona qualit\xE0 di base.",
  "cotone biologico": "Cotone coltivato senza pesticidi, buona qualit\xE0 di base.",
  "organic cotton": "Cotone coltivato senza pesticidi, buona qualit\xE0 di base.",
  lyocell: "Semi-sintetica sostenibile, morbida e biodegradabile.",
  tencel: "Semi-sintetica sostenibile, morbida e biodegradabile.",
  lana: "Fibra naturale calda e isolante, durevole se lavata con cura.",
  wool: "Fibra naturale calda e isolante, durevole se lavata con cura.",
  cotone: "Fibra naturale di base, buona traspirabilit\xE0 ma qualit\xE0 variabile.",
  cotton: "Fibra naturale di base, buona traspirabilit\xE0 ma qualit\xE0 variabile.",
  modal: "Derivata dal legno, morbida e assorbente.",
  cupro: "Semi-sintetica dal cotone, drappeggio simile alla seta.",
  viscosa: "Semi-sintetica economica, processo chimico pesante.",
  viscose: "Semi-sintetica economica, processo chimico pesante.",
  rayon: "Semi-sintetica economica, processo chimico pesante.",
  nylon: "Sintetico resistente ma scarsa traspirabilit\xE0.",
  nailon: "Sintetico resistente ma scarsa traspirabilit\xE0.",
  poliammide: "Sintetico resistente ma scarsa traspirabilit\xE0.",
  polyamide: "Sintetico resistente ma scarsa traspirabilit\xE0.",
  poliestere_riciclato: "Sintetico riciclato, meglio del vergine ma resta plastica.",
  "poliestere riciclato": "Sintetico riciclato, meglio del vergine ma resta plastica.",
  "recycled polyester": "Sintetico riciclato, meglio del vergine ma resta plastica.",
  poliestere: "Sintetico economico, non traspira e genera microplastiche.",
  polyester: "Sintetico economico, non traspira e genera microplastiche.",
  acrilico: "Il peggior sintetico: pilling rapido, non traspira, non dura.",
  acrylic: "Il peggior sintetico: pilling rapido, non traspira, non dura."
};
var ELASTANE_FIBERS2 = ["elastane", "elastan", "spandex"];
function getElastaneDescription(percentage) {
  if (percentage <= 5) {
    return "Aggiunta minima per elasticit\xE0, non impatta la qualit\xE0.";
  }
  return "Percentuale elevata, pu\xF2 ridurre la durabilit\xE0 nel tempo.";
}
function getFiberDescription(fiber, percentage) {
  const key = fiber.toLowerCase();
  if (ELASTANE_FIBERS2.includes(key)) {
    return getElastaneDescription(percentage);
  }
  return FIBER_DESCRIPTIONS[key] ?? null;
}

// src/validation/productValidation.ts
var UUID_RE = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
var HTML_TAG_RE = /<[^>]+>/;
var URL_RE = /https?:\/\/\S+/i;
function validateProduct(data) {
  const errors = [];
  if (!data.name || data.name.trim().length === 0) {
    errors.push("Il nome del prodotto \xE8 obbligatorio");
  } else {
    const name = data.name.trim();
    if (name.length < 3) errors.push("Il nome del prodotto deve avere almeno 3 caratteri");
    if (name.length > 200) errors.push("Il nome del prodotto non pu\xF2 superare 200 caratteri");
    if (HTML_TAG_RE.test(name)) errors.push("Il nome del prodotto non pu\xF2 contenere tag HTML");
    if (URL_RE.test(name)) errors.push("Il nome del prodotto non pu\xF2 contenere URL");
  }
  if (!data.brand_id) {
    errors.push("Il brand \xE8 obbligatorio");
  } else if (!UUID_RE.test(data.brand_id)) {
    errors.push("Il brand_id non \xE8 un UUID valido");
  }
  if (!data.category_id) {
    errors.push("La categoria \xE8 obbligatoria");
  } else if (!UUID_RE.test(data.category_id)) {
    errors.push("Il category_id non \xE8 un UUID valido");
  }
  if (data.price == null) {
    errors.push("Il prezzo \xE8 obbligatorio");
  } else {
    if (data.price <= 0) errors.push("Il prezzo deve essere maggiore di zero");
    if (data.price >= 500) errors.push("Il prezzo non pu\xF2 superare \u20AC500");
  }
  if (!data.composition || !Array.isArray(data.composition) || data.composition.length === 0) {
    errors.push("La composizione \xE8 obbligatoria e deve contenere almeno una fibra");
  }
  return { valid: errors.length === 0, errors };
}

// src/validation/compositionValidation.ts
function validateComposition(fibers) {
  const errors = [];
  if (fibers.length === 0) {
    errors.push("La composizione deve contenere almeno una fibra");
    return { valid: false, errors };
  }
  if (fibers.length > 8) {
    errors.push("La composizione pu\xF2 contenere al massimo 8 fibre");
  }
  for (const fiber of fibers) {
    if (!fiber.fiber || fiber.fiber.trim().length === 0) {
      errors.push("Ogni fibra deve avere un nome");
    }
    if (fiber.percentage <= 0) {
      errors.push(`La percentuale di "${fiber.fiber}" deve essere maggiore di 0`);
    }
    if (fiber.percentage > 100) {
      errors.push(`La percentuale di "${fiber.fiber}" non pu\xF2 superare 100%`);
    }
  }
  const names = fibers.map((f) => f.fiber.toLowerCase().trim());
  const uniqueNames = new Set(names);
  if (uniqueNames.size !== names.length) {
    errors.push("La composizione contiene fibre duplicate");
  }
  const sum = fibers.reduce((acc, f) => acc + f.percentage, 0);
  if (sum < 99 || sum > 101) {
    errors.push(`La somma delle percentuali deve essere 100% (attuale: ${sum}%)`);
  }
  return { valid: errors.length === 0, errors };
}

// src/validation/priceValidation.ts
function validatePrice(price, composition) {
  if (price < 0.01 || price > 500) {
    return { valid: false, plausible: false };
  }
  if (!composition || composition.length === 0) {
    return { valid: true, plausible: true };
  }
  const score = calculateCompositionScore(composition);
  if (score > 85 && price < 5) {
    return {
      valid: true,
      plausible: false,
      warning: "Composizione premium a un prezzo molto basso \u2014 verifica che il prezzo sia corretto"
    };
  }
  if (score <= 30 && price > 100) {
    return {
      valid: true,
      plausible: false,
      warning: "Composizione di bassa qualit\xE0 a un prezzo molto alto \u2014 verifica che il prezzo sia corretto"
    };
  }
  return { valid: true, plausible: true };
}

// src/validation/barcodeValidation.ts
var DIGITS_RE = /^\d+$/;
function eanCheckDigit(digits) {
  let sum = 0;
  for (let i = 0; i < digits.length; i++) {
    sum += digits[i] * (i % 2 === 0 ? 1 : 3);
  }
  return (10 - sum % 10) % 10;
}
function isValidEAN13(code) {
  if (code.length !== 13 || !DIGITS_RE.test(code)) return false;
  const digits = Array.from(code, Number);
  const check = digits.pop();
  return eanCheckDigit(digits) === check;
}
function isValidUPC(code) {
  if (code.length !== 12 || !DIGITS_RE.test(code)) return false;
  const digits = Array.from(code, Number);
  const check = digits.pop();
  let sum = 0;
  for (let i = 0; i < digits.length; i++) {
    sum += digits[i] * (i % 2 === 0 ? 3 : 1);
  }
  const expected = (10 - sum % 10) % 10;
  return expected === check;
}
function isValidBarcode(code) {
  return isValidEAN13(code) || isValidUPC(code);
}
export {
  BADGES,
  CATEGORIES,
  CERTIFICATIONS,
  COUNTRIES,
  DEFAULT_FIBER_SCORE,
  ELASTANE_FIBERS,
  ELASTANE_IGNORE_THRESHOLD,
  ELASTANE_LOW_THRESHOLD,
  ELASTANE_SCORE_HIGH,
  ELASTANE_SCORE_LOW,
  FIBERS,
  FIBER_DESCRIPTIONS,
  FIBER_SCORES,
  LAUNCH_BRANDS,
  MARKET_SEGMENTS,
  NAV_TABS,
  ONBOARDING_STEPS,
  POINTS,
  RATE_LIMITS,
  VALIDATION,
  VERDICTS,
  bonusFor,
  calculateCompositionScore,
  calculateQPR,
  calculateWorthyScore,
  calculateWorthyScoreV2,
  compositionLens,
  elastaneScore,
  getCertification,
  getCountry,
  getElastaneDescription,
  getFiberDescription,
  isElastane,
  isValidBarcode,
  isValidEAN13,
  isValidUPC,
  manufacturingLens,
  manufacturingScoreFor,
  qprLens,
  sustainabilityLens,
  validateComposition,
  validatePrice,
  validateProduct,
  verdictFromScore
};
//# sourceMappingURL=index.mjs.map