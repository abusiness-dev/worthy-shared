-- Worthy Score v2 - Tabella anagrafica origini fibra.
--
-- Modella la differenza qualitativa tra "lana australiana RWS" e "lana cinese
-- generica", oppure tra "cotone egiziano Giza" e "cotone Upland". Ogni origine
-- ha uno score 0-100 usato dalla origin_lens (peso 20% sul totale Worthy
-- Score v2). L'origin_score è curato dalla ricerca industriale e revisionabile
-- via UPDATE.
--
-- L'origine ha sempre un fiber_id di riferimento ("wool", "cotton", "cashmere",
-- "linen", "silk"). country_iso2 è opzionale: alcune origini (BCI, GOTS
-- generico) sono multi-country e restano NULL. certification_id è opzionale:
-- alcune origini sono certificate-bound (es. "wool_au_merino_rws" implica RWS),
-- altre sono solo geografiche.

CREATE TABLE fiber_origins (
  id               text     PRIMARY KEY,
  fiber_id         text     NOT NULL,
  country_iso2     char(2)  REFERENCES countries(iso2) ON DELETE SET NULL,
  variety          text,
  certification_id text     REFERENCES certifications(id) ON DELETE SET NULL,
  origin_score     smallint NOT NULL CHECK (origin_score BETWEEN 0 AND 100),
  display_label    text     NOT NULL,
  notes            text
);

COMMENT ON TABLE fiber_origins IS 'Origini geografiche/certificate delle fibre (lana australiana, cotone egiziano, etc); alimenta origin_lens.';
COMMENT ON COLUMN fiber_origins.fiber_id     IS 'Riferimento testuale all''id fibra (vedi src/constants/fibers.ts): wool, cotton, cashmere, linen, silk, polyester, nylon';
COMMENT ON COLUMN fiber_origins.origin_score IS 'Score 0-100 dell''origine; revisionabile.';

-- ============================================================
-- Seed
-- ============================================================

-- LANA
INSERT INTO fiber_origins (id, fiber_id, country_iso2, variety, certification_id, origin_score, display_label, notes) VALUES
  ('wool_au_merino_rws',       'wool',    'AU', 'Merino',          'rws',  95, 'Lana Merino Australiana RWS',  '17-21 micron ultra-fine; gold standard mondiale'),
  ('wool_nz_merino',           'wool',    'NZ', 'Merino',           NULL,  88, 'Lana Merino Neozelandese',     'Subset minore della produzione NZ; qualità comparabile a AU'),
  ('wool_it_biella',           'wool',    'IT', 'Biella processed', NULL,  90, 'Lana lavorata a Biella',        'Filiera verticale completa; mills Zegna, VBC, Drago'),
  ('wool_uk_shetland',         'wool',    'GB', 'Shetland',         NULL,  85, 'Shetland scozzese',             'Fibra rara naturalmente colorata'),
  ('wool_eu_generic',          'wool',     NULL, NULL,              NULL,  60, 'Lana europea generica',         NULL),
  ('wool_cn_generic',          'wool',    'CN', NULL,               NULL,  35, 'Lana cinese generica',          'Coarse, mercato bulk fast fashion'),
  ('wool_other',               'wool',     NULL, NULL,              NULL,  50, 'Lana - origine non specificata', 'Default fallback');

-- CASHMERE
INSERT INTO fiber_origins (id, fiber_id, country_iso2, variety, certification_id, origin_score, display_label, notes) VALUES
  ('cashmere_mn_gcs',          'cashmere','MN', 'Gobi',             'gcs', 98, 'Cashmere Mongolia GCS',         '14-16.5 micron; clima freddo estremo; gold standard'),
  ('cashmere_mn',              'cashmere','MN', 'Gobi',              NULL,  92, 'Cashmere Mongolia',             'No GCS ma origine Mongolia genuina'),
  ('cashmere_cn_inner',        'cashmere','CN', 'Inner Mongolia',    NULL,  75, 'Cashmere Inner Mongolia',       'Volume dominante (60% globale); qualità A+ disponibile ma less consistent'),
  ('cashmere_ir',              'cashmere','IR',  NULL,               NULL,  55, 'Cashmere iraniano',             'Commodity'),
  ('cashmere_af',              'cashmere','AF',  NULL,               NULL,  50, 'Cashmere afgano',               'Commodity'),
  ('cashmere_kz',              'cashmere','KZ',  NULL,               NULL,  55, 'Cashmere kazako',               'Commodity'),
  ('cashmere_other',           'cashmere',NULL,  NULL,               NULL,  60, 'Cashmere - origine non specificata', 'Default fallback');

-- COTONE
INSERT INTO fiber_origins (id, fiber_id, country_iso2, variety, certification_id, origin_score, display_label, notes) VALUES
  ('cotton_ag_sea_island',     'cotton', 'AG', 'Sea Island',         NULL, 100, 'Sea Island Cotton',            '45-50mm staple; più lungo del mondo; ultra-luxury'),
  ('cotton_eg_giza',           'cotton', 'EG', 'Giza',               NULL,  95, 'Cotone Egiziano Giza',          '>35mm extra-long staple; <0.5% produzione globale'),
  ('cotton_us_supima',         'cotton', 'US', 'Supima Pima',        NULL,  90, 'Cotone Supima americano',       'Licensed trademark; tracciabilità americana'),
  ('cotton_us_pima',           'cotton', 'US', 'Pima',               NULL,  88, 'Cotone Pima americano',         'ELS cotton USA'),
  ('cotton_pe_pima',           'cotton', 'PE', 'Pima',               NULL,  82, 'Cotone Pima peruviano',         'Pima sudamericano'),
  ('cotton_organic_gots',      'cotton',  NULL, 'Organic',           'gots',78, 'Cotone organico GOTS',          'Multi-origine, certificazione GOTS'),
  ('cotton_in_organic',        'cotton', 'IN', 'Organic',            'gots',76, 'Cotone organico indiano GOTS',  NULL),
  ('cotton_bci',               'cotton',  NULL, NULL,           'better_cotton_bci', 70, 'Cotone BCI',            'Better Cotton Initiative; mass-balance'),
  ('cotton_tr',                'cotton', 'TR', NULL,                 NULL,  62, 'Cotone turco',                  'Buona qualità mediterranea'),
  ('cotton_in_generic',        'cotton', 'IN', NULL,                 NULL,  55, 'Cotone indiano',                NULL),
  ('cotton_pk_generic',        'cotton', 'PK', NULL,                 NULL,  55, 'Cotone pakistano',              NULL),
  ('cotton_cn_generic',        'cotton', 'CN', NULL,                 NULL,  45, 'Cotone cinese',                 NULL),
  ('cotton_generic',           'cotton',  NULL, NULL,                NULL,  45, 'Cotone generico (Upland)',      'Default fallback; pesticide-intensive');

-- LINO
INSERT INTO fiber_origins (id, fiber_id, country_iso2, variety, certification_id, origin_score, display_label, notes) VALUES
  ('linen_be_french',          'linen',   NULL, 'Linen Triangle',    NULL,  92, 'Lino Belgio/Francia',           'Linen Triangle: longest, finest fibers; 70% premium globale'),
  ('linen_fr',                 'linen',  'FR',  NULL,                NULL,  90, 'Lino francese',                 NULL),
  ('linen_be',                 'linen',  'BE',  NULL,                NULL,  90, 'Lino belga',                    NULL),
  ('linen_eu_other',           'linen',   NULL,  NULL,               NULL,  72, 'Lino europeo (altro)',          NULL),
  ('linen_cn',                 'linen',  'CN',  NULL,                NULL,  50, 'Lino cinese',                   'Costo tagliato, additivi chimici aggressivi'),
  ('linen_generic',            'linen',   NULL,  NULL,               NULL,  60, 'Lino - origine non specificata', 'Default fallback');

-- SETA
INSERT INTO fiber_origins (id, fiber_id, country_iso2, variety, certification_id, origin_score, display_label, notes) VALUES
  ('silk_it_como',             'silk',   'IT', 'Como finished',      NULL,  92, 'Seta finita a Como',            'Maestria tessile italiana (dyeing/printing/jacquard); raw spesso CN/IN'),
  ('silk_cn_mulberry_6a',      'silk',   'CN', 'Mulberry 6A',        NULL,  85, 'Seta cinese Mulberry 6A',       'Top grade fiber raw; CN 80% raw silk globale'),
  ('silk_cn',                  'silk',   'CN',  NULL,                NULL,  72, 'Seta cinese',                   'Bulk/luxury blend'),
  ('silk_in',                  'silk',   'IN', 'Tussar/Muga/Eri',    NULL,  70, 'Seta indiana',                  'Non-mulberry; coarse texture; cultural significance'),
  ('silk_generic',             'silk',    NULL, NULL,                NULL,  65, 'Seta - origine non specificata', 'Default fallback');

-- POLIESTERE / NYLON (origin per sintetici è meno rilevante: lo score primario
-- viene da technical_lens. Qui modelliamo solo i casi "riciclato vs vergine"
-- e il country della filiera quando dichiarato.)
INSERT INTO fiber_origins (id, fiber_id, country_iso2, variety, certification_id, origin_score, display_label, notes) VALUES
  ('polyester_recycled_grs',   'polyester', NULL, 'rPET',          'grs_50', 65, 'Poliestere riciclato GRS',     'rPET certificato; -30/-50% GHG vs virgin'),
  ('polyester_recycled_unc',   'polyester', NULL, 'rPET',           NULL,    55, 'Poliestere riciclato (no cert)', 'rPET non certificato'),
  ('polyester_virgin',         'polyester', NULL, 'Virgin',         NULL,    30, 'Poliestere vergine',            'Default'),
  ('nylon_econyl',             'nylon',   'IT', 'Aquafil regenerated', 'grs_50', 75, 'ECONYL nylon riciclato',     'Italiano (Aquafil); fishing nets/fabric scraps regenerated'),
  ('nylon_recycled_grs',       'nylon',   NULL, 'Recycled',         'grs_50', 65, 'Nylon riciclato GRS',          NULL),
  ('nylon_virgin',             'nylon',   NULL, 'Virgin',           NULL,     35, 'Nylon vergine',                'Default');

-- LIN/HEMP/RAMIE/JUTE/ALPACA — origini secondarie, default neutro
INSERT INTO fiber_origins (id, fiber_id, country_iso2, variety, certification_id, origin_score, display_label, notes) VALUES
  ('alpaca_pe',                'alpaca', 'PE', NULL,                NULL,  85, 'Alpaca peruviana',              'Origine premium tradizionale'),
  ('alpaca_other',             'alpaca',  NULL, NULL,               NULL,  65, 'Alpaca - origine non specificata', NULL);
