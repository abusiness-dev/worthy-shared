// Validazione URL contribuiti dal client (affiliate_url, photo_urls, label_photo_url).
//
// NB: questa è validazione applicativa lato client (difesa in profondità + UX).
// La VERA barriera è il trigger DB `validate_product_urls` (migration
// 20260530000001), perché il client usa la anon key e potrebbe scrivere su
// PostgREST bypassando questo TS. Mantieni le due logiche allineate.

const SAFE_HTTPS_URL_RE = /^https:\/\/[^\s]+$/i;
const MAX_URL_LENGTH = 2048;

/** true se la stringa è un URL https:// ben formato (no javascript:, data:, http:, spazi). */
export function isSafeHttpsUrl(url: unknown): boolean {
  if (typeof url !== "string") return false;
  const trimmed = url.trim();
  return trimmed.length > 0 && trimmed.length <= MAX_URL_LENGTH && SAFE_HTTPS_URL_RE.test(trimmed);
}

/** affiliate_url è opzionale; se presente deve essere un URL https:// sicuro. */
export function validateAffiliateUrl(
  url: string | null | undefined,
): { valid: boolean; error?: string } {
  if (url == null || url.trim() === "") return { valid: true };
  if (!isSafeHttpsUrl(url)) {
    return { valid: false, error: "L'affiliate URL deve essere un URL https:// valido" };
  }
  return { valid: true };
}

/** Ogni photo_url non vuoto deve essere un URL https:// sicuro. */
export function validatePhotoUrls(
  urls: readonly (string | null)[] | null | undefined,
): { valid: boolean; error?: string } {
  if (urls == null) return { valid: true };
  if (!Array.isArray(urls)) {
    return { valid: false, error: "photo_urls deve essere un array di URL" };
  }
  for (const u of urls) {
    if (u != null && u.trim() !== "" && !isSafeHttpsUrl(u)) {
      return { valid: false, error: `photo_url non valido (ammessi solo https://): ${u}` };
    }
  }
  return { valid: true };
}
