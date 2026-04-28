-- Worthy Score v2 - Tabella anagrafica paesi (manufacturing tier).
--
-- Sostituisce le stringhe libere in products.country_of_production con un
-- riferimento normalizzato ISO 3166-1 alpha-2. Ogni paese ha un punteggio
-- "manufacturing_score" 0-100 usato dalla manufacturing_lens del nuovo Worthy
-- Score (peso 15% sul totale).
--
-- Tier sono basati su ricerca industriale (costi del lavoro, certificazioni,
-- distretti specializzati, qualità manifatturiera media):
--   T1 (90-100): premium manufacturing, integrated supply chain, expertise generazionale
--   T2 (70-89):  high-quality manufacturing, EU + Far East premium
--   T3 (45-69):  volume manufacturing, qualità accettabile
--   T4 (20-44):  mass production, qualità variabile, fast fashion
--
-- I valori sono curati e revisionabili via UPDATE. Non rappresentano un
-- giudizio assoluto sul paese: lo score è una proxy della qualità mediana
-- attesa dalla produzione tessile-abbigliamento. Brand premium che producono
-- in T3/T4 sono comunque valorizzati dalla technical_lens e dalla
-- sustainability_lens.

CREATE TABLE countries (
  iso2                char(2)  PRIMARY KEY,
  name_it             text     NOT NULL,
  name_en             text     NOT NULL,
  region              text     NOT NULL,
  manufacturing_tier  smallint NOT NULL CHECK (manufacturing_tier BETWEEN 1 AND 4),
  manufacturing_score smallint NOT NULL CHECK (manufacturing_score BETWEEN 0 AND 100),
  notes               text
);

COMMENT ON TABLE countries IS 'Anagrafica ISO2 con manufacturing_score per la lente Manufacturing del Worthy Score v2.';
COMMENT ON COLUMN countries.manufacturing_tier  IS '1=premium, 2=high-quality, 3=volume, 4=mass';
COMMENT ON COLUMN countries.manufacturing_score IS 'Score 0-100 usato dalla manufacturing_lens; revisionabile via UPDATE.';

-- ============================================================
-- Seed: paesi rilevanti per il sourcing tessile-abbigliamento
-- ============================================================

-- TIER 1 - Premium Manufacturing
INSERT INTO countries (iso2, name_it, name_en, region, manufacturing_tier, manufacturing_score, notes) VALUES
  ('IT', 'Italia',     'Italy',       'EU',   1, 95, '100% Made in Italy law 206/2023; distretti Biella, Como, Prato, Carpi'),
  ('JP', 'Giappone',   'Japan',       'Asia', 1, 92, 'Denim Okayama, technical synthetics, low-volume alta qualità'),
  ('CH', 'Svizzera',   'Switzerland', 'EU',   1, 90, 'Schoeller, technical fabrics, specialty membranes');

-- TIER 2 - High-Quality Manufacturing
INSERT INTO countries (iso2, name_it, name_en, region, manufacturing_tier, manufacturing_score, notes) VALUES
  ('DE', 'Germania',         'Germany',        'EU',   2, 82, NULL),
  ('PT', 'Portogallo',       'Portugal',       'EU',   2, 80, 'Cotton, denim, ecosystem integrato premium'),
  ('AT', 'Austria',          'Austria',        'EU',   2, 80, NULL),
  ('FR', 'Francia',          'France',         'EU',   2, 80, 'Lino premium triangle (con Belgio/Olanda)'),
  ('BE', 'Belgio',           'Belgium',        'EU',   2, 78, 'Lino europeo'),
  ('NL', 'Paesi Bassi',      'Netherlands',    'EU',   2, 78, NULL),
  ('GB', 'Regno Unito',      'United Kingdom', 'EU',   2, 78, 'Tweed, Shetland'),
  ('US', 'Stati Uniti',      'United States',  'Americas', 2, 78, 'Pima/Supima cotton, technical innovation'),
  ('ES', 'Spagna',           'Spain',          'EU',   2, 78, 'Sede storica Inditex (Zara), Mango'),
  ('DK', 'Danimarca',        'Denmark',        'EU',   2, 75, NULL),
  ('SE', 'Svezia',           'Sweden',         'EU',   2, 75, 'Sede H&M, COS'),
  ('NO', 'Norvegia',         'Norway',         'EU',   2, 75, NULL),
  ('FI', 'Finlandia',        'Finland',        'EU',   2, 75, NULL),
  ('KR', 'Corea del Sud',    'South Korea',    'Asia', 2, 75, 'Synthetic technical, K-fashion premium'),
  ('TR', 'Turchia',          'Turkey',         'Asia', 2, 72, 'Filiera integrata, distretti Istanbul/Denizli/Bursa, serve Hugo Boss/Zara'),
  ('RO', 'Romania',          'Romania',        'EU',   2, 70, 'Knitwear sintetico, denim'),
  ('HU', 'Ungheria',         'Hungary',        'EU',   2, 70, NULL),
  ('CZ', 'Repubblica Ceca',  'Czech Republic', 'EU',   2, 70, NULL),
  ('PL', 'Polonia',          'Poland',         'EU',   2, 70, NULL);

-- TIER 3 - Volume Manufacturing
INSERT INTO countries (iso2, name_it, name_en, region, manufacturing_tier, manufacturing_score, notes) VALUES
  ('TW', 'Taiwan',     'Taiwan',     'Asia',     3, 65, 'Synthetic technical, sportswear'),
  ('BG', 'Bulgaria',   'Bulgaria',   'EU',       3, 60, NULL),
  ('VN', 'Vietnam',    'Vietnam',    'Asia',     3, 58, 'Sportswear, knitwear, Patagonia/Arc''teryx production base'),
  ('CN', 'Cina',       'China',      'Asia',     3, 55, 'Range qualità ampia: high-tier (Stone Island production) coesiste con low-tier fast fashion'),
  ('TH', 'Thailandia', 'Thailand',   'Asia',     3, 55, NULL),
  ('IN', 'India',      'India',      'Asia',     3, 52, 'Cotone organico GOTS in crescita'),
  ('MX', 'Messico',    'Mexico',     'Americas', 3, 52, NULL),
  ('BR', 'Brasile',    'Brazil',     'Americas', 3, 52, 'Denim, casual wear'),
  ('IL', 'Israele',    'Israel',     'Asia',     3, 50, NULL),
  ('TN', 'Tunisia',    'Tunisia',    'Africa',   3, 50, 'Near-shoring europeo'),
  ('EG', 'Egitto',     'Egypt',      'Africa',   3, 50, 'Origine cotone Giza'),
  ('PK', 'Pakistan',   'Pakistan',   'Asia',     3, 50, 'Cotton premium, yarn spinning'),
  ('MY', 'Malesia',    'Malaysia',   'Asia',     3, 48, NULL),
  ('ID', 'Indonesia',  'Indonesia',  'Asia',     3, 45, NULL),
  ('MA', 'Marocco',    'Morocco',    'Africa',   3, 45, 'Near-shoring europeo'),
  ('LK', 'Sri Lanka',  'Sri Lanka',  'Asia',     3, 45, NULL),
  ('PH', 'Filippine',  'Philippines','Asia',     3, 42, NULL);

-- TIER 4 - Mass Production / Fast Fashion
INSERT INTO countries (iso2, name_it, name_en, region, manufacturing_tier, manufacturing_score, notes) VALUES
  ('BD', 'Bangladesh', 'Bangladesh', 'Asia',   4, 30, 'Maggior export fast fashion T-shirt/basic, turnover lavoro 22%'),
  ('NP', 'Nepal',      'Nepal',      'Asia',   4, 30, NULL),
  ('KH', 'Cambogia',   'Cambodia',   'Asia',   4, 25, NULL),
  ('ET', 'Etiopia',    'Ethiopia',   'Africa', 4, 25, NULL),
  ('HT', 'Haiti',      'Haiti',      'Americas', 4, 25, NULL),
  ('MM', 'Myanmar',    'Myanmar',    'Asia',   4, 20, NULL);

-- ============================================================
-- Paesi notabili come ORIGINE FIBRA (non solo manufacturing)
-- Score di manufacturing più basso possibile non è il loro caso d'uso primario.
-- ============================================================

INSERT INTO countries (iso2, name_it, name_en, region, manufacturing_tier, manufacturing_score, notes) VALUES
  ('AU', 'Australia',         'Australia',         'Oceania', 2, 70, 'Origine merino premium RWS'),
  ('NZ', 'Nuova Zelanda',     'New Zealand',       'Oceania', 2, 70, 'Origine merino'),
  ('MN', 'Mongolia',          'Mongolia',          'Asia',    3, 50, 'Origine cashmere GCS gold standard'),
  ('AG', 'Antigua e Barbuda', 'Antigua and Barbuda','Americas',3, 50, 'Origine Sea Island cotton ultra-luxury'),
  ('IR', 'Iran',              'Iran',              'Asia',    3, 45, 'Origine cashmere commodity'),
  ('AF', 'Afghanistan',       'Afghanistan',       'Asia',    4, 35, 'Origine cashmere commodity'),
  ('KZ', 'Kazakistan',        'Kazakhstan',        'Asia',    3, 45, 'Origine cashmere commodity'),
  ('PE', 'Perù',              'Peru',              'Americas',3, 55, 'Origine cotone Pima sudamericano, alpaca');
