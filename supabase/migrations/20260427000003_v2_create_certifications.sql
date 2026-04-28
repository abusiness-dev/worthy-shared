-- Worthy Score v2 - Tabella anagrafica certificazioni tessili.
--
-- Ogni certificazione contribuisce al sustainability_lens (peso 5% sul totale)
-- con bonus_points cumulativi (capped a 100). Le certificazioni hanno scope
-- diversi: alcune sono fiber-level (GOTS, RWS, GCS, GRS), altre process-level
-- (Bluesign, Fair Trade), altre product-level (OEKO-TEX), altre brand-level
-- (B Corp). Lo scope guida il join: product_certifications oppure
-- brand_certifications.
--
-- I bonus_points sono curati basandosi su credibilità e rigore (audit
-- third-party, requisiti minimi misurabili). Revisionabili via UPDATE.

CREATE TABLE certifications (
  id            text     PRIMARY KEY,
  display_name  text     NOT NULL,
  scope         text     NOT NULL CHECK (scope IN ('fiber', 'process', 'brand', 'product', 'manufacturing')),
  bonus_points  smallint NOT NULL CHECK (bonus_points BETWEEN 0 AND 30),
  notes         text
);

COMMENT ON TABLE certifications IS 'Certificazioni accreditate; bonus_points alimenta sustainability_lens (cap 100).';
COMMENT ON COLUMN certifications.scope IS 'fiber: cotone/lana/cashmere; process: tintura/lavorazione; product: prodotto finito; brand: azienda; manufacturing: paese di produzione';
COMMENT ON COLUMN certifications.bonus_points IS 'Punti aggiunti al sustainability_lens (revisionabili).';

-- ============================================================
-- Seed
-- ============================================================

-- Fiber-level
INSERT INTO certifications (id, display_name, scope, bonus_points, notes) VALUES
  ('gots',                   'GOTS (Global Organic Textile Standard)', 'fiber', 15, '70%+ organic; chemical control; ILO social criteria; annual third-party audit'),
  ('rws',                    'RWS (Responsible Wool Standard)',         'fiber', 12, 'Animal welfare, no mulesing, chain of custody; Patagonia, Icebreaker'),
  ('gcs',                    'GCS (Good Cashmere Standard)',            'fiber', 12, 'Cashmere goat welfare, anti-overgrazing; Aid by Trade Foundation'),
  ('grs_50',                 'GRS 50%+ (Global Recycled Standard)',     'fiber', 10, '50%+ recycled content; chain of custody; chemical restrictions'),
  ('rds',                    'RDS (Responsible Down Standard)',         'fiber', 10, 'Live-pluck-free, force-feed-free down certification'),
  ('better_cotton_bci',      'Better Cotton Initiative (BCI)',          'fiber', 6,  'Mass-balance system; pesticide reduction; più scalabile di Organic'),
  ('rcs',                    'RCS (Recycled Claim Standard)',           'fiber', 6,  '5-100% recycled content; meno rigoroso di GRS');

-- Product-level
INSERT INTO certifications (id, display_name, scope, bonus_points, notes) VALUES
  ('oeko_tex_100',              'OEKO-TEX Standard 100',         'product', 5,  'Test sostanze nocive su prodotto finito; safety chimica'),
  ('oeko_tex_made_in_green',    'OEKO-TEX Made in Green',        'product', 12, 'Standard 100 + STeP audit di processo + traceability QR'),
  ('cradle_to_cradle_gold',     'Cradle to Cradle Gold',         'product', 14, 'Material health + circular design; 5 categorie di impatto'),
  ('cradle_to_cradle_silver',   'Cradle to Cradle Silver',       'product', 10, NULL),
  ('cradle_to_cradle_bronze',   'Cradle to Cradle Bronze',       'product', 6,  NULL);

-- Process-level
INSERT INTO certifications (id, display_name, scope, bonus_points, notes) VALUES
  ('bluesign',                  'Bluesign System Partner',       'process', 10, 'Reduced environmental impact; chemical management; Arc''teryx, Schoeller'),
  ('fair_trade',                'Fair Trade Certified',          'process', 10, 'Worker welfare, fair wages; Patagonia 90%+ FTC factories'),
  ('sa8000',                    'SA8000 (Social Accountability)','process', 8,  'ILO labor standards, worker rights audit'),
  ('wrap',                      'WRAP (Worldwide Responsible Accredited Production)','process', 6, 'Apparel labor compliance');

-- Brand-level
INSERT INTO certifications (id, display_name, scope, bonus_points, notes) VALUES
  ('b_corp_80plus',             'B Corp (80+ score)',            'brand',   8,  'Holistic business impact; Patagonia 151/200, Ganni high luxury'),
  ('1_percent_for_planet',      '1% for the Planet',             'brand',   4,  'Environmental giving commitment');

-- Manufacturing-level
INSERT INTO certifications (id, display_name, scope, bonus_points, notes) VALUES
  ('made_in_italy_100',         '100% Made in Italy (legge 206/2023)', 'manufacturing', 8,  'Filiera integralmente italiana, controlli RINA Italcheck'),
  ('made_green_italy',          'Made Green in Italy',                 'manufacturing', 10, 'Italian sustainability + traceability QR');
