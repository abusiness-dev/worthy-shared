// Regole di selezione delle "alternative migliori" — logica pura condivisa.
//
// Fonte di verità UNICA, riusata dalla pagina prodotto e dal tab Alternative di
// worthy-app (e disponibile a worthy-admin). Nessuna UI, nessun network.
//
// Principio: un'alternativa è ammissibile (hard-filter) o non lo è; lo SCORE è il
// criterio primario, fibra/prezzo/segmento sono pertinenza/tie-break. Un'alternativa
// non è MAI peggiore del riferimento ("da uguale in su, mai più basso").

import type { ComparisonTier, Composition, Gender, MarketSegment } from "../types";
import { verdictFromScore } from "../scoring";
import { segmentDistance, isSegmentAdjacent } from "../constants/marketSegments";
import { COMPARISON_TIER_ORDER, isTierAdjacent, tierProximity } from "../constants/comparisonTiers";

// ── Tipi normalizzati ────────────────────────────────────────
export interface AlternativeProduct {
  id: string;
  worthy_score: number;
  price: number | null;
  gender: Gender | string | null;
  composition: Composition[] | null;
  market_segment: MarketSegment | null;
  /** Lega di confronto del brand (asse del QPR). Preferita a market_segment per
   *  l'adiacenza/prossimità di posizionamento; fallback a market_segment se assente. */
  comparison_tier?: ComparisonTier | string | null;
  brand_id: string | null;
  category_id: string | null;
  /** Famiglia di categoria (Ondata 3). Fallback a category_id se assente. */
  category_family?: string | null;
}

export interface AlternativeCandidate extends AlternativeProduct {
  /** Overlap dei token col nome del riferimento (0..1), precalcolato dal chiamante.
   *  La similarità testuale resta in worthy-app (lib/nameSimilarity); qui è solo un
   *  segnale di tie-break per non duplicare la tokenizzazione nel pacchetto shared. */
  nameOverlap?: number;
}

export interface RankedAlternative {
  /** Punteggio di ranking [0..1] usato per l'ordinamento. */
  rank: number;
  /** Differenza di Worthy Score rispetto al riferimento (>= 0 per costruzione). */
  scoreDelta: number;
}

// ── Costanti regola ──────────────────────────────────────────
/** Sopra questo score un capo è "già buono" (verdict worthy/steal): nel tab non genera alternative. */
export const SOURCE_GOOD_FLOOR = 71;
/** Floor assoluto di qualità: un'alternativa non scende mai sotto verdict 'fair' (51). */
export const MIN_VERDICT_FLOOR = 51;
/** Bonus minimo stesso-brand nel ranking — mai un override. */
export const SAME_BRAND_BONUS = 0.05;
/** Cap superiore di fascia prezzo. Nessun cap inferiore: più economico E migliore è desiderato. */
export const PRICE_RATIO_MAX = 2.5;

// ── Helper puri ──────────────────────────────────────────────

/** Gender compatibile col riferimento: null/unisex su un lato ⇒ ammesso. */
export function gendersCompatible(
  a: Gender | string | null | undefined,
  b: Gender | string | null | undefined,
): boolean {
  if (!a || !b) return true;
  const ga = a.toLowerCase();
  const gb = b.toLowerCase();
  if (ga === "unisex" || gb === "unisex") return true;
  return ga === gb;
}

/** Vicinanza di prezzo [0..1]. Dato mancante ⇒ neutro (0.5), non penalizzante. */
export function priceProximity(
  current: number | null | undefined,
  alt: number | null | undefined,
): number {
  const c = current ?? 0;
  const a = alt ?? 0;
  if (c <= 0 || a <= 0) return 0.5;
  const diff = Math.abs(c - a) / c;
  return Math.max(0, 1 - Math.min(diff, 1));
}

/** Le 2 fibre dominanti (lowercase), ordinate per percentuale. */
function dominantFibers(composition: Composition[] | null | undefined): string[] {
  if (!composition || composition.length === 0) return [];
  return [...composition]
    .sort((x, y) => y.percentage - x.percentage)
    .slice(0, 2)
    .map((c) => c.fiber.toLowerCase().trim());
}

/** Similarità di composizione [0..1] basata sulle fibre dominanti. */
export function fiberSimilarity(
  a: Composition[] | null | undefined,
  b: Composition[] | null | undefined,
): number {
  const da = dominantFibers(a);
  const db = dominantFibers(b);
  const da0 = da[0];
  const db0 = db[0];
  if (da0 === undefined || db0 === undefined) return 0;
  if (da0 === db0) return 1;
  if (da.slice(0, 2).includes(db0) || db.slice(0, 2).includes(da0)) return 0.5;
  return 0;
}

/** Prossimità di segmento [0..1]. Segmento ignoto ⇒ neutro (0.5). */
export function segmentProximity(
  a: MarketSegment | null | undefined,
  b: MarketSegment | null | undefined,
): number {
  const d = segmentDistance(a, b);
  if (d === null) return 0.5;
  return 1 - d / 3;
}

/** Lega valida e nota (chiave di COMPARISON_TIER_ORDER). */
function knownTier(t: unknown): ComparisonTier | null {
  return typeof t === "string" && t in COMPARISON_TIER_ORDER ? (t as ComparisonTier) : null;
}

/** Adiacenza di posizionamento: usa comparison_tier se nota su entrambi, altrimenti
 *  fallback al market_segment legacy. Posizione ignota ⇒ non blocca. */
function positionalAdjacent(ref: AlternativeProduct, cand: AlternativeProduct): boolean {
  const rt = knownTier(ref.comparison_tier);
  const ct = knownTier(cand.comparison_tier);
  if (rt && ct) return isTierAdjacent(rt, ct);
  return isSegmentAdjacent(ref.market_segment, cand.market_segment);
}

/** Prossimità di posizionamento [0..1]: comparison_tier se nota, altrimenti segmento. */
function positionalProximity(ref: AlternativeProduct, cand: AlternativeProduct): number {
  const rt = knownTier(ref.comparison_tier);
  const ct = knownTier(cand.comparison_tier);
  if (rt && ct) return tierProximity(rt, ct);
  return segmentProximity(ref.market_segment, cand.market_segment);
}

/** Un capo è "già buono" (non merita alternative) se verdict worthy o steal. */
export function isAlreadyGood(score: number): boolean {
  const v = verdictFromScore(score);
  return v === "worthy" || v === "steal";
}

/** Un'alternativa rispetta il floor di qualità se verdict almeno 'fair'. */
export function meetsQualityFloor(score: number): boolean {
  const v = verdictFromScore(score);
  return v === "fair" || v === "worthy" || v === "steal";
}

function familyKey(p: AlternativeProduct): string | null {
  return p.category_family ?? p.category_id;
}

// ── Ammissibilità (hard-filter) ──────────────────────────────
// Un candidato è un'alternativa valida solo se TUTTE le condizioni valgono.
export function isEligibleAlternative(
  ref: AlternativeProduct,
  cand: AlternativeProduct,
): boolean {
  // Mai se stesso.
  if (cand.id === ref.id) return false;

  // Stessa famiglia/categoria (fallback a category_id finché la famiglia non esiste).
  const rf = familyKey(ref);
  const cf = familyKey(cand);
  if (rf == null || cf == null || rf !== cf) return false;

  // Gender compatibile col riferimento.
  if (!gendersCompatible(ref.gender, cand.gender)) return false;

  // Score gate: mai più basso del riferimento (da uguale in su).
  if (cand.worthy_score < ref.worthy_score) return false;

  // Floor di qualità assoluto: mai sotto 'fair'.
  if (!meetsQualityFloor(cand.worthy_score)) return false;

  // Lega compatibile (uguale o adiacente di 1; ignota non blocca).
  if (!positionalAdjacent(ref, cand)) return false;

  // Cap prezzo superiore (solo se entrambi i prezzi noti). Nessun cap inferiore.
  const rp = ref.price ?? 0;
  const cp = cand.price ?? 0;
  if (rp > 0 && cp > 0 && cp / rp > PRICE_RATIO_MAX) return false;

  return true;
}

// ── Ranking ──────────────────────────────────────────────────
// Tra i SOLI ammissibili. Lo score pesa di più (0.45) ed è anche hard-filter a monte,
// quindi la qualità non compete più con fibra/prezzo: questi sono pertinenza/tie-break.
export function rankAlternative(
  ref: AlternativeProduct,
  cand: AlternativeCandidate,
): number {
  const scoreNorm = Math.max(0, Math.min(1, cand.worthy_score / 100));
  const priceSim = priceProximity(ref.price, cand.price);
  const fiberSim = fiberSimilarity(ref.composition, cand.composition);
  const segSim = positionalProximity(ref, cand);
  const nameOv = cand.nameOverlap ?? 0;
  const sameBrand = ref.brand_id != null && cand.brand_id === ref.brand_id ? 1 : 0;

  return (
    0.45 * scoreNorm +
    0.2 * priceSim +
    0.15 * fiberSim +
    0.1 * segSim +
    0.05 * nameOv +
    SAME_BRAND_BONUS * sameBrand
  );
}

// Ordina per rank desc con tie-break espliciti e deterministici.
function compareAlternatives(
  ref: AlternativeProduct,
  a: AlternativeCandidate,
  b: AlternativeCandidate,
): number {
  const rb = rankAlternative(ref, b);
  const ra = rankAlternative(ref, a);
  if (rb !== ra) return rb - ra;

  if (b.worthy_score !== a.worthy_score) return b.worthy_score - a.worthy_score;

  const pb = priceProximity(ref.price, b.price);
  const pa = priceProximity(ref.price, a.price);
  if (pb !== pa) return pb - pa;

  const sb = positionalProximity(ref, b);
  const sa = positionalProximity(ref, a);
  if (sb !== sa) return sb - sa;

  // Stessa category_id esatta prima (anche quando matchano per famiglia).
  const ea = a.category_id != null && a.category_id === ref.category_id ? 1 : 0;
  const eb = b.category_id != null && b.category_id === ref.category_id ? 1 : 0;
  if (eb !== ea) return eb - ea;

  const fb = fiberSimilarity(ref.composition, b.composition);
  const fa = fiberSimilarity(ref.composition, a.composition);
  if (fb !== fa) return fb - fa;

  return a.id < b.id ? -1 : a.id > b.id ? 1 : 0;
}

/** Ordina i candidati GIÀ ammissibili e ritorna i migliori `limit` con rank e
 *  scoreDelta. Da usare quando l'ammissibilità è già garantita a monte (es. dalla
 *  RPC get_better_alternatives): non riapplica gli hard-filter, solo il ranking. */
export function rankBestCandidates<T extends AlternativeCandidate>(
  ref: AlternativeProduct,
  candidates: readonly T[],
  opts: { limit?: number } = {},
): (T & RankedAlternative)[] {
  const limit = opts.limit ?? 5;
  const sorted = [...candidates].sort((a, b) => compareAlternatives(ref, a, b));
  return sorted.slice(0, limit).map((c) => ({
    ...c,
    rank: rankAlternative(ref, c),
    scoreDelta: Math.round(c.worthy_score - ref.worthy_score),
  }));
}

/** Filtra gli ammissibili, ordina e ritorna i migliori `limit` con rank e scoreDelta. */
export function pickBestAlternatives<T extends AlternativeCandidate>(
  ref: AlternativeProduct,
  candidates: readonly T[],
  opts: { limit?: number } = {},
): (T & RankedAlternative)[] {
  const eligible = candidates.filter((c) => isEligibleAlternative(ref, c));
  return rankBestCandidates(ref, eligible, opts);
}

/** Migliore alternativa singola, o null se non esiste un candidato ammissibile. */
export function bestAlternative<T extends AlternativeCandidate>(
  ref: AlternativeProduct,
  candidates: readonly T[],
): (T & RankedAlternative) | null {
  return pickBestAlternatives(ref, candidates, { limit: 1 })[0] ?? null;
}
