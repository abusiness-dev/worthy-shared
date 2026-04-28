// Normalizza stringhe libere di paese ("Made in Italy", "ITALY", "italia",
// "Italia 🇮🇹") in codici ISO 3166-1 alpha-2 ("IT").
//
// Usato dallo scraper per popolare country_of_production_iso2 e gli step di
// filiera (spinning_iso2, weaving_iso2, dyeing_iso2) usati dalla
// manufacturing_lens del Worthy Score v2.

const COUNTRY_MAP: Record<string, string> = {
  // ITALIA
  italia: "IT", italy: "IT", italie: "IT", italian: "IT", "made in italy": "IT", "fatto in italia": "IT", "prodotto in italia": "IT",

  // EUROPA premium
  giappone: "JP", japan: "JP", "made in japan": "JP",
  svizzera: "CH", switzerland: "CH", suisse: "CH",
  germania: "DE", germany: "DE", deutschland: "DE", "made in germany": "DE",
  portogallo: "PT", portugal: "PT", "made in portugal": "PT",
  austria: "AT",
  francia: "FR", france: "FR", "made in france": "FR", francaise: "FR",
  belgio: "BE", belgium: "BE", belgique: "BE",
  "paesi bassi": "NL", olanda: "NL", netherlands: "NL", holland: "NL",
  "regno unito": "GB", "united kingdom": "GB", uk: "GB", britain: "GB", england: "GB", inghilterra: "GB", "made in britain": "GB",
  "stati uniti": "US", "united states": "US", usa: "US", "u.s.a.": "US", america: "US", "made in usa": "US",
  spagna: "ES", spain: "ES", españa: "ES", "made in spain": "ES",
  danimarca: "DK", denmark: "DK",
  svezia: "SE", sweden: "SE",
  norvegia: "NO", norway: "NO",
  finlandia: "FI", finland: "FI",
  "corea del sud": "KR", "south korea": "KR", korea: "KR",
  turchia: "TR", turkey: "TR", türkiye: "TR", turkiye: "TR", "made in turkey": "TR",
  romania: "RO",
  ungheria: "HU", hungary: "HU",
  "repubblica ceca": "CZ", "czech republic": "CZ", cechia: "CZ",
  polonia: "PL", poland: "PL",

  // ASIA / TIER 3-4
  taiwan: "TW",
  bulgaria: "BG",
  vietnam: "VN", "viet nam": "VN", "made in vietnam": "VN",
  cina: "CN", china: "CN", "made in china": "CN", "p.r.c.": "CN",
  thailandia: "TH", thailand: "TH",
  india: "IN", "made in india": "IN",
  messico: "MX", mexico: "MX",
  brasile: "BR", brazil: "BR", brasil: "BR",
  israele: "IL", israel: "IL",
  tunisia: "TN",
  egitto: "EG", egypt: "EG",
  pakistan: "PK",
  malesia: "MY", malaysia: "MY",
  indonesia: "ID",
  marocco: "MA", morocco: "MA", maroc: "MA",
  iran: "IR",
  kazakistan: "KZ", kazakhstan: "KZ",
  "sri lanka": "LK", srilanka: "LK",
  filippine: "PH", philippines: "PH",
  bangladesh: "BD", "made in bangladesh": "BD",
  nepal: "NP",
  cambogia: "KH", cambodia: "KH",
  etiopia: "ET", ethiopia: "ET",
  haiti: "HT",
  myanmar: "MM", birmania: "MM", burma: "MM",

  // ORIGINI FIBRA (anche se NON manufacturing)
  australia: "AU",
  "nuova zelanda": "NZ", "new zealand": "NZ",
  mongolia: "MN",
  "antigua e barbuda": "AG", antigua: "AG",
  afghanistan: "AF",
  perù: "PE", peru: "PE",
};

/**
 * Normalizza una stringa libera di paese a ISO2. Ritorna `null` se la stringa
 * è vuota o non corrisponde a nessun paese conosciuto. Tollerante a:
 * - prefissi "Made in"/"Prodotto in"/"Fatto in"
 * - emoji bandiera (rimosse)
 * - punteggiatura/spazi extra
 * - case
 */
export function normalizeCountry(raw: string | null | undefined): string | null {
  if (!raw) return null;

  const cleaned = raw
    .toLowerCase()
    .replace(/[\u{1F1E6}-\u{1F1FF}]+/gu, "")  // emoji bandiere
    .replace(/[.,;:!?()[\]{}"]/g, " ")
    .replace(/\s+/g, " ")
    .trim();

  if (!cleaned) return null;

  // Match diretto
  const direct = COUNTRY_MAP[cleaned];
  if (direct) return direct;

  // Strip prefissi comuni
  const stripped = cleaned
    .replace(/^(made in |prodotto in |fatto in |origin |origine |country of origin |country |paese )/i, "")
    .trim();

  if (stripped !== cleaned) {
    const m = COUNTRY_MAP[stripped];
    if (m) return m;
  }

  // Last resort: substring match (es. "Made in italy of finest wool" → italy)
  for (const [key, iso2] of Object.entries(COUNTRY_MAP)) {
    if (key.length >= 4 && cleaned.includes(key)) {
      return iso2;
    }
  }

  return null;
}
