// Anagrafica certificazioni tessili per la sustainability_lens del Worthy Score v2.
// Fonte di verità in produzione: tabella `certifications` (vedi migration 20260427000003).
// Allineato ai seed SQL.

export type CertificationScope = "fiber" | "process" | "brand" | "product" | "manufacturing";

export interface Certification {
  id: string;
  display_name: string;
  scope: CertificationScope;
  bonus_points: number;
}

export const CERTIFICATIONS: Record<string, Certification> = {
  // Fiber-level
  gots:                { id: "gots",                display_name: "GOTS (Global Organic Textile Standard)", scope: "fiber", bonus_points: 15 },
  rws:                 { id: "rws",                 display_name: "RWS (Responsible Wool Standard)",         scope: "fiber", bonus_points: 12 },
  gcs:                 { id: "gcs",                 display_name: "GCS (Good Cashmere Standard)",            scope: "fiber", bonus_points: 12 },
  grs_50:              { id: "grs_50",              display_name: "GRS 50%+ (Global Recycled Standard)",     scope: "fiber", bonus_points: 10 },
  rds:                 { id: "rds",                 display_name: "RDS (Responsible Down Standard)",         scope: "fiber", bonus_points: 10 },
  better_cotton_bci:   { id: "better_cotton_bci",   display_name: "Better Cotton Initiative (BCI)",          scope: "fiber", bonus_points: 6 },
  rcs:                 { id: "rcs",                 display_name: "RCS (Recycled Claim Standard)",           scope: "fiber", bonus_points: 6 },

  // Product-level
  oeko_tex_100:           { id: "oeko_tex_100",           display_name: "OEKO-TEX Standard 100",   scope: "product", bonus_points: 5 },
  oeko_tex_made_in_green: { id: "oeko_tex_made_in_green", display_name: "OEKO-TEX Made in Green",  scope: "product", bonus_points: 12 },
  cradle_to_cradle_gold:  { id: "cradle_to_cradle_gold",  display_name: "Cradle to Cradle Gold",   scope: "product", bonus_points: 14 },
  cradle_to_cradle_silver:{ id: "cradle_to_cradle_silver",display_name: "Cradle to Cradle Silver", scope: "product", bonus_points: 10 },
  cradle_to_cradle_bronze:{ id: "cradle_to_cradle_bronze",display_name: "Cradle to Cradle Bronze", scope: "product", bonus_points: 6 },

  // Process-level
  bluesign:    { id: "bluesign",    display_name: "Bluesign System Partner",                    scope: "process", bonus_points: 10 },
  fair_trade:  { id: "fair_trade",  display_name: "Fair Trade Certified",                       scope: "process", bonus_points: 10 },
  sa8000:      { id: "sa8000",      display_name: "SA8000 (Social Accountability)",             scope: "process", bonus_points: 8 },
  wrap:        { id: "wrap",        display_name: "WRAP (Worldwide Responsible Accredited Production)", scope: "process", bonus_points: 6 },

  // Brand-level
  b_corp_80plus:        { id: "b_corp_80plus",        display_name: "B Corp (80+ score)",   scope: "brand", bonus_points: 8 },
  "1_percent_for_planet": { id: "1_percent_for_planet", display_name: "1% for the Planet", scope: "brand", bonus_points: 4 },

  // Manufacturing-level
  made_in_italy_100: { id: "made_in_italy_100", display_name: "100% Made in Italy",  scope: "manufacturing", bonus_points: 8 },
  made_green_italy:  { id: "made_green_italy",  display_name: "Made Green in Italy", scope: "manufacturing", bonus_points: 10 },
};

export type CertificationId = keyof typeof CERTIFICATIONS;

export function getCertification(id: string | null | undefined): Certification | undefined {
  if (!id) return undefined;
  return CERTIFICATIONS[id];
}

export function bonusFor(id: string | null | undefined): number {
  const cert = getCertification(id);
  return cert ? cert.bonus_points : 0;
}
