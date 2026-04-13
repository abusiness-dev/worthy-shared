// Descrizioni italiane delle fibre, usate dalle FiberCard nell'app.
// Le chiavi coprono sia la forma con underscore (slug) sia quella con spazi (IT/EN)
// per matchare i formati riconosciuti da FIBER_SCORES.

export const FIBER_DESCRIPTIONS: Record<string, string> = {
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

  cotone_biologico: "Cotone coltivato senza pesticidi, buona qualità di base.",
  "cotone biologico": "Cotone coltivato senza pesticidi, buona qualità di base.",
  "organic cotton": "Cotone coltivato senza pesticidi, buona qualità di base.",

  lyocell: "Semi-sintetica sostenibile, morbida e biodegradabile.",
  tencel: "Semi-sintetica sostenibile, morbida e biodegradabile.",

  lana: "Fibra naturale calda e isolante, durevole se lavata con cura.",
  wool: "Fibra naturale calda e isolante, durevole se lavata con cura.",

  cotone: "Fibra naturale di base, buona traspirabilità ma qualità variabile.",
  cotton: "Fibra naturale di base, buona traspirabilità ma qualità variabile.",

  modal: "Derivata dal legno, morbida e assorbente.",

  cupro: "Semi-sintetica dal cotone, drappeggio simile alla seta.",

  viscosa: "Semi-sintetica economica, processo chimico pesante.",
  viscose: "Semi-sintetica economica, processo chimico pesante.",
  rayon: "Semi-sintetica economica, processo chimico pesante.",

  nylon: "Sintetico resistente ma scarsa traspirabilità.",
  nailon: "Sintetico resistente ma scarsa traspirabilità.",
  poliammide: "Sintetico resistente ma scarsa traspirabilità.",
  polyamide: "Sintetico resistente ma scarsa traspirabilità.",

  poliestere_riciclato: "Sintetico riciclato, meglio del vergine ma resta plastica.",
  "poliestere riciclato": "Sintetico riciclato, meglio del vergine ma resta plastica.",
  "recycled polyester": "Sintetico riciclato, meglio del vergine ma resta plastica.",

  poliestere: "Sintetico economico, non traspira e genera microplastiche.",
  polyester: "Sintetico economico, non traspira e genera microplastiche.",

  acrilico: "Il peggior sintetico: pilling rapido, non traspira, non dura.",
  acrylic: "Il peggior sintetico: pilling rapido, non traspira, non dura.",
};

// Descrizioni a soglia per l'elastane: cambia con la percentuale nel prodotto,
// quindi non è un semplice lookup ma una funzione.
const ELASTANE_FIBERS = ["elastane", "elastan", "spandex"];

export function getElastaneDescription(percentage: number): string {
  if (percentage <= 5) {
    return "Aggiunta minima per elasticità, non impatta la qualità.";
  }
  return "Percentuale elevata, può ridurre la durabilità nel tempo.";
}

// Helper: descrizione unificata data fibra + percentuale.
// Ritorna null se non esiste una descrizione per la fibra.
export function getFiberDescription(fiber: string, percentage: number): string | null {
  const key = fiber.toLowerCase();
  if (ELASTANE_FIBERS.includes(key)) {
    return getElastaneDescription(percentage);
  }
  return FIBER_DESCRIPTIONS[key] ?? null;
}
