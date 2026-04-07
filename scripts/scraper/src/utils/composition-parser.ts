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

export function parseComposition(text: string): ParsedComposition[] {
  if (!text || !text.trim()) return [];

  // If there are section headers like "Shell:", "Lining:", "Body:", take only the first section
  // or the "Body:" / "Shell:" section
  let workingText = text;
  const sectionMatch = text.match(
    /(?:body|shell|tessuto|composizione|composition)\s*:\s*([^.]+)/i
  );
  if (sectionMatch) {
    workingText = sectionMatch[1];
  } else {
    // Take first section before a period or newline that starts a new section
    const firstSection = text.split(/\.\s*[A-Z]|\n/)[0];
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

  // Deduplicate by fiber name
  const seen = new Set<string>();
  const deduped: ParsedComposition[] = [];
  for (const r of results) {
    if (!seen.has(r.fiber)) {
      seen.add(r.fiber);
      deduped.push(r);
    }
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
