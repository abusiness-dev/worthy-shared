// Anagrafica paesi per la manufacturing_lens del Worthy Score v2.
// Fonte di verità in produzione: tabella `countries` (vedi migrations 20260427000002).
// Questo file è il mirror locale per il calcolo client-side del package @worthy/shared.

export interface Country {
  iso2: string;
  name_it: string;
  region: "EU" | "Asia" | "Americas" | "Africa" | "Oceania";
  manufacturing_tier: 1 | 2 | 3 | 4;
  manufacturing_score: number;
}

export const COUNTRIES: Record<string, Country> = {
  // Tier 1
  IT: { iso2: "IT", name_it: "Italia",     region: "EU",   manufacturing_tier: 1, manufacturing_score: 95 },
  JP: { iso2: "JP", name_it: "Giappone",   region: "Asia", manufacturing_tier: 1, manufacturing_score: 92 },
  CH: { iso2: "CH", name_it: "Svizzera",   region: "EU",   manufacturing_tier: 1, manufacturing_score: 90 },

  // Tier 2
  DE: { iso2: "DE", name_it: "Germania",         region: "EU",       manufacturing_tier: 2, manufacturing_score: 82 },
  PT: { iso2: "PT", name_it: "Portogallo",       region: "EU",       manufacturing_tier: 2, manufacturing_score: 80 },
  AT: { iso2: "AT", name_it: "Austria",          region: "EU",       manufacturing_tier: 2, manufacturing_score: 80 },
  FR: { iso2: "FR", name_it: "Francia",          region: "EU",       manufacturing_tier: 2, manufacturing_score: 80 },
  BE: { iso2: "BE", name_it: "Belgio",           region: "EU",       manufacturing_tier: 2, manufacturing_score: 78 },
  NL: { iso2: "NL", name_it: "Paesi Bassi",      region: "EU",       manufacturing_tier: 2, manufacturing_score: 78 },
  GB: { iso2: "GB", name_it: "Regno Unito",      region: "EU",       manufacturing_tier: 2, manufacturing_score: 78 },
  US: { iso2: "US", name_it: "Stati Uniti",      region: "Americas", manufacturing_tier: 2, manufacturing_score: 78 },
  ES: { iso2: "ES", name_it: "Spagna",           region: "EU",       manufacturing_tier: 2, manufacturing_score: 78 },
  DK: { iso2: "DK", name_it: "Danimarca",        region: "EU",       manufacturing_tier: 2, manufacturing_score: 75 },
  SE: { iso2: "SE", name_it: "Svezia",           region: "EU",       manufacturing_tier: 2, manufacturing_score: 75 },
  NO: { iso2: "NO", name_it: "Norvegia",         region: "EU",       manufacturing_tier: 2, manufacturing_score: 75 },
  FI: { iso2: "FI", name_it: "Finlandia",        region: "EU",       manufacturing_tier: 2, manufacturing_score: 75 },
  KR: { iso2: "KR", name_it: "Corea del Sud",    region: "Asia",     manufacturing_tier: 2, manufacturing_score: 75 },
  TR: { iso2: "TR", name_it: "Turchia",          region: "Asia",     manufacturing_tier: 2, manufacturing_score: 72 },
  RO: { iso2: "RO", name_it: "Romania",          region: "EU",       manufacturing_tier: 2, manufacturing_score: 70 },
  HU: { iso2: "HU", name_it: "Ungheria",         region: "EU",       manufacturing_tier: 2, manufacturing_score: 70 },
  CZ: { iso2: "CZ", name_it: "Repubblica Ceca",  region: "EU",       manufacturing_tier: 2, manufacturing_score: 70 },
  PL: { iso2: "PL", name_it: "Polonia",          region: "EU",       manufacturing_tier: 2, manufacturing_score: 70 },
  AU: { iso2: "AU", name_it: "Australia",        region: "Oceania",  manufacturing_tier: 2, manufacturing_score: 70 },
  NZ: { iso2: "NZ", name_it: "Nuova Zelanda",    region: "Oceania",  manufacturing_tier: 2, manufacturing_score: 70 },

  // Tier 3
  TW: { iso2: "TW", name_it: "Taiwan",     region: "Asia",     manufacturing_tier: 3, manufacturing_score: 65 },
  BG: { iso2: "BG", name_it: "Bulgaria",   region: "EU",       manufacturing_tier: 3, manufacturing_score: 60 },
  VN: { iso2: "VN", name_it: "Vietnam",    region: "Asia",     manufacturing_tier: 3, manufacturing_score: 58 },
  CN: { iso2: "CN", name_it: "Cina",       region: "Asia",     manufacturing_tier: 3, manufacturing_score: 55 },
  TH: { iso2: "TH", name_it: "Thailandia", region: "Asia",     manufacturing_tier: 3, manufacturing_score: 55 },
  PE: { iso2: "PE", name_it: "Perù",       region: "Americas", manufacturing_tier: 3, manufacturing_score: 55 },
  IN: { iso2: "IN", name_it: "India",      region: "Asia",     manufacturing_tier: 3, manufacturing_score: 52 },
  MX: { iso2: "MX", name_it: "Messico",    region: "Americas", manufacturing_tier: 3, manufacturing_score: 52 },
  BR: { iso2: "BR", name_it: "Brasile",    region: "Americas", manufacturing_tier: 3, manufacturing_score: 52 },
  IL: { iso2: "IL", name_it: "Israele",    region: "Asia",     manufacturing_tier: 3, manufacturing_score: 50 },
  TN: { iso2: "TN", name_it: "Tunisia",    region: "Africa",   manufacturing_tier: 3, manufacturing_score: 50 },
  EG: { iso2: "EG", name_it: "Egitto",     region: "Africa",   manufacturing_tier: 3, manufacturing_score: 50 },
  PK: { iso2: "PK", name_it: "Pakistan",   region: "Asia",     manufacturing_tier: 3, manufacturing_score: 50 },
  MN: { iso2: "MN", name_it: "Mongolia",   region: "Asia",     manufacturing_tier: 3, manufacturing_score: 50 },
  AG: { iso2: "AG", name_it: "Antigua e Barbuda", region: "Americas", manufacturing_tier: 3, manufacturing_score: 50 },
  MY: { iso2: "MY", name_it: "Malesia",    region: "Asia",     manufacturing_tier: 3, manufacturing_score: 48 },
  ID: { iso2: "ID", name_it: "Indonesia",  region: "Asia",     manufacturing_tier: 3, manufacturing_score: 45 },
  MA: { iso2: "MA", name_it: "Marocco",    region: "Africa",   manufacturing_tier: 3, manufacturing_score: 45 },
  IR: { iso2: "IR", name_it: "Iran",       region: "Asia",     manufacturing_tier: 3, manufacturing_score: 45 },
  KZ: { iso2: "KZ", name_it: "Kazakistan", region: "Asia",     manufacturing_tier: 3, manufacturing_score: 45 },
  LK: { iso2: "LK", name_it: "Sri Lanka",  region: "Asia",     manufacturing_tier: 3, manufacturing_score: 45 },
  PH: { iso2: "PH", name_it: "Filippine",  region: "Asia",     manufacturing_tier: 3, manufacturing_score: 42 },

  // Tier 4
  AF: { iso2: "AF", name_it: "Afghanistan", region: "Asia",   manufacturing_tier: 4, manufacturing_score: 35 },
  BD: { iso2: "BD", name_it: "Bangladesh",  region: "Asia",   manufacturing_tier: 4, manufacturing_score: 30 },
  NP: { iso2: "NP", name_it: "Nepal",       region: "Asia",   manufacturing_tier: 4, manufacturing_score: 30 },
  KH: { iso2: "KH", name_it: "Cambogia",    region: "Asia",   manufacturing_tier: 4, manufacturing_score: 25 },
  ET: { iso2: "ET", name_it: "Etiopia",     region: "Africa", manufacturing_tier: 4, manufacturing_score: 25 },
  HT: { iso2: "HT", name_it: "Haiti",       region: "Americas", manufacturing_tier: 4, manufacturing_score: 25 },
  MM: { iso2: "MM", name_it: "Myanmar",     region: "Asia",   manufacturing_tier: 4, manufacturing_score: 20 },
};

export type CountryIso2 = keyof typeof COUNTRIES;

export function getCountry(iso2: string | null | undefined): Country | undefined {
  if (!iso2) return undefined;
  return COUNTRIES[iso2.toUpperCase()];
}

export function manufacturingScoreFor(iso2: string | null | undefined): number | null {
  const country = getCountry(iso2);
  return country ? country.manufacturing_score : null;
}
