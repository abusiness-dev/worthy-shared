import type { ParsedComposition } from "../types.js";
import { mapFiberName } from "./fiber-mapper.js";

/**
 * Parses raw composition text from brand websites into structured data.
 *
 * Handles formats like:
 *   "70% Cotone, 30% Poliestere"
 *   "Cotton 70%, Polyester 25%, Elastane 5%"
 *   "70% cotone · 25% poliestere · 5% elastan"
 *   "Cotone 100%"
 *   "Shell: 80% Cotton, 20% Polyester. Lining: 100% Polyester" (takes first group)
 */

// Matches patterns like "70% Cotone" or "Cotone 70%"
const PERCENTAGE_FIRST = /(\d{1,3})\s*%\s+([a-zA-ZÀ-ÿ\s]+)/g;
const FIBER_FIRST = /([a-zA-ZÀ-ÿ\s]+?)\s+(\d{1,3})\s*%/g;
const INLINE_PATTERN = /(\d{1,3})\s*%\s*([a-zA-ZÀ-ÿ]+(?:\s+[a-zA-ZÀ-ÿ]+)*)/g;

// Header sezione "principale" (il tessuto esterno del capo)
const MAIN_SECTION_RE =
  /\b(?:body|shell|outer|esterno|tessuto\s+principale|main\s+fabric|composizione|composition|tessuto)\b\s*:?\s*([^]*?)(?=\b(?:fodera|lining|bordi|ribbing|trim|rever|interno|inside|cuff|collar)\b|$)/i;

// Header sezione da IGNORARE (fodera, bordi, ecc.)
const SECONDARY_SECTION_RE =
  /\b(?:fodera|lining|bordi|ribbing|trim|rever|interno|inside|cuff|collar|imbottitura|padding)\b\s*:?\s*[^]*/i;

export function parseComposition(text: string): ParsedComposition[] {
  if (!text || !text.trim()) return [];

  let workingText = text;

  // 1) Se trovo un header "principale" (Esterno/Shell/Tessuto principale/...) estraggo
  //    solo quella sezione, fino al prossimo header secondario o fine testo.
  const mainMatch = workingText.match(MAIN_SECTION_RE);
  if (mainMatch && mainMatch[1]) {
    workingText = mainMatch[1];
  } else {
    // 2) Rimuovi eventuali sezioni secondarie (fodera, bordi) anche senza header principale.
    workingText = workingText.replace(SECONDARY_SECTION_RE, "");
    // 3) Prima "sezione" prima di un punto + maiuscola o newline (fallback legacy).
    const firstSection = workingText.split(/\.\s*[A-Z]|\n/)[0];
    if (firstSection) workingText = firstSection;
  }

  // Clean up separators
  workingText = workingText
    .replace(/·/g, ",")
    .replace(/;/g, ",")
    .replace(/\|/g, ",")
    .replace(/-\s/g, ", ");

  let results: ParsedComposition[] = [];

  // Try percentage-first pattern: "70% Cotone"
  results = matchAll(workingText, INLINE_PATTERN);

  // Try fiber-first pattern: "Cotone 70%"
  if (results.length === 0) {
    results = matchAllFiberFirst(workingText, FIBER_FIRST);
  }

  // Deduplicate by fiber name (preserve first occurrence)
  const seen = new Set<string>();
  const deduped: ParsedComposition[] = [];
  for (const r of results) {
    if (!seen.has(r.fiber)) {
      seen.add(r.fiber);
      deduped.push(r);
    }
  }

  // 4) Parsing incrementale: se la somma supera 101% (es. fodera catturata per sbaglio),
  //    tieni solo le prime fibre fino a sommare ~100%.
  const total = deduped.reduce((acc, f) => acc + f.percentage, 0);
  if (total > 101) {
    const truncated: ParsedComposition[] = [];
    let running = 0;
    for (const f of deduped) {
      if (running >= 99) break;
      truncated.push(f);
      running += f.percentage;
      if (running >= 99 && running <= 101) break;
    }
    // Usa truncated solo se arriva in range; altrimenti mantieni deduped (lascia fallire
    // la validation a valle, che è meglio di un risultato dubbio silenziato).
    const truncSum = truncated.reduce((acc, f) => acc + f.percentage, 0);
    if (truncSum >= 99 && truncSum <= 101) return truncated;
  }

  return deduped;
}

function matchAll(text: string, pattern: RegExp): ParsedComposition[] {
  const results: ParsedComposition[] = [];
  const regex = new RegExp(pattern.source, "gi");
  let match: RegExpExecArray | null;

  while ((match = regex.exec(text)) !== null) {
    const percentage = parseInt(match[1], 10);
    const fiber = mapFiberName(match[2]);

    if (percentage > 0 && percentage <= 100 && fiber) {
      results.push({ fiber, percentage });
    }
  }

  return results;
}

function matchAllFiberFirst(
  text: string,
  pattern: RegExp
): ParsedComposition[] {
  const results: ParsedComposition[] = [];
  const regex = new RegExp(pattern.source, "gi");
  let match: RegExpExecArray | null;

  while ((match = regex.exec(text)) !== null) {
    const fiber = mapFiberName(match[1]);
    const percentage = parseInt(match[2], 10);

    if (percentage > 0 && percentage <= 100 && fiber) {
      results.push({ fiber, percentage });
    }
  }

  return results;
}
