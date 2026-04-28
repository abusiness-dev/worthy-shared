// Estrae da testo libero PDP/etichetta i campi v2 del Worthy Score:
//   - product_certifications (GOTS, OEKO-TEX, RWS, BCI, ...)
//
// Approccio regex first-match-wins, conservativo: emette solo quando il
// match è inequivocabile (parole chiave specifiche del settore).

export interface ExtractedV2Fields {
  certifications: string[];          // ids di certifications (product-level)
}

interface CertRule { id: string; pattern: RegExp; }

const CERT_RULES: CertRule[] = [
  { id: "gots",                     pattern: /\bgots\b|global\s*organic\s*textile\s*standard/i },
  { id: "rws",                      pattern: /\brws\b|responsible\s*wool\s*standard/i },
  { id: "gcs",                      pattern: /\bgcs\b|good\s*cashmere\s*standard/i },
  { id: "rds",                      pattern: /\brds\b|responsible\s*down\s*standard/i },
  { id: "grs_50",                   pattern: /\bgrs\b|global\s*recycled\s*standard/i },
  { id: "rcs",                      pattern: /recycled\s*claim\s*standard/i },
  { id: "better_cotton_bci",        pattern: /\bbci\b|better\s*cotton\s*initiative|better\s*cotton(?!\s*made)/i },
  { id: "oeko_tex_made_in_green",   pattern: /oeko[\s-]?tex.{0,15}made\s*in\s*green/i },
  { id: "oeko_tex_100",             pattern: /oeko[\s-]?tex.{0,15}(standard\s*)?100|oeko[\s-]?tex(?!\s*made)/i },
  { id: "cradle_to_cradle_gold",    pattern: /cradle\s*to\s*cradle.{0,15}gold/i },
  { id: "cradle_to_cradle_silver",  pattern: /cradle\s*to\s*cradle.{0,15}silver/i },
  { id: "cradle_to_cradle_bronze",  pattern: /cradle\s*to\s*cradle.{0,15}bronze/i },
  { id: "bluesign",                 pattern: /bluesign/i },
  { id: "fair_trade",               pattern: /fair\s*trade/i },
  { id: "sa8000",                   pattern: /\bsa8000\b/i },
  { id: "wrap",                     pattern: /\bwrap\s*certified/i },
  { id: "made_in_italy_100",        pattern: /100%?\s*made\s*in\s*italy|legge\s*206\/2023|italcheck/i },
  { id: "made_green_italy",         pattern: /made\s*green\s*in\s*italy/i },
];

function matchAll(text: string, rules: CertRule[]): string[] {
  const matched = new Set<string>();
  for (const rule of rules) {
    if (rule.pattern.test(text)) matched.add(rule.id);
  }
  return Array.from(matched);
}

/**
 * Estrae i campi v2 da uno o più blocchi di testo concatenati (descrizione PDP,
 * caratteristiche, label etichetta, dettagli composizione). Tutti i campi sono
 * "best-effort": se non match, ritorna array vuoti.
 */
export function extractV2Fields(...textBlocks: (string | null | undefined)[]): ExtractedV2Fields {
  const text = textBlocks.filter(Boolean).join(" \n ").toLowerCase();
  if (!text.trim()) {
    return { certifications: [] };
  }

  return {
    certifications: matchAll(text, CERT_RULES),
  };
}
