-- Seed data: 9 categorie, 12 brand di lancio, 5 badge, 1 utente admin di test
-- Idempotente: usa ON CONFLICT DO NOTHING, eseguibile più volte senza errori
-- Eseguito automaticamente dopo le migration con `supabase db reset`

-- ============================================================
-- Categorie
-- ============================================================

INSERT INTO categories (id, name, slug, icon) VALUES
  (gen_random_uuid(), 'T-Shirt',    't-shirt',    '👕'),
  (gen_random_uuid(), 'Felpe',      'felpe',      '🧥'),
  (gen_random_uuid(), 'Jeans',      'jeans',      '👖'),
  (gen_random_uuid(), 'Pantaloni',  'pantaloni',  '👖'),
  (gen_random_uuid(), 'Giacche',    'giacche',    '🧥'),
  (gen_random_uuid(), 'Sneakers',   'sneakers',   '👟'),
  (gen_random_uuid(), 'Camicie',    'camicie',    '👔'),
  (gen_random_uuid(), 'Intimo',     'intimo',     '🩲'),
  (gen_random_uuid(), 'Accessori',  'accessori',  '🧣')
ON CONFLICT (slug) DO NOTHING;

-- ============================================================
-- Brand di lancio
-- ============================================================

INSERT INTO brands (id, name, slug, origin_country, market_segment) VALUES
  (gen_random_uuid(), 'Zara',           'zara',           'Spagna',   'fast'),
  (gen_random_uuid(), 'H&M',            'h-and-m',        'Svezia',   'fast'),
  (gen_random_uuid(), 'Uniqlo',         'uniqlo',         'Giappone', 'fast'),
  (gen_random_uuid(), 'Shein',          'shein',          'Cina',     'ultra_fast'),
  (gen_random_uuid(), 'Bershka',        'bershka',        'Spagna',   'fast'),
  (gen_random_uuid(), 'Pull&Bear',      'pull-and-bear',  'Spagna',   'fast'),
  (gen_random_uuid(), 'Stradivarius',   'stradivarius',   'Spagna',   'fast'),
  (gen_random_uuid(), 'Primark',        'primark',        'Irlanda',  'ultra_fast'),
  (gen_random_uuid(), 'ASOS',           'asos',           'UK',       'fast'),
  (gen_random_uuid(), 'Mango',          'mango',          'Spagna',   'fast'),
  (gen_random_uuid(), 'COS',            'cos',            'Svezia',   'premium_fast'),
  (gen_random_uuid(), 'Massimo Dutti',  'massimo-dutti',  'Spagna',   'premium_fast')
ON CONFLICT (slug) DO NOTHING;

-- ============================================================
-- Badge
-- ============================================================

INSERT INTO badges (id, name, description, icon, points_required, benefit) VALUES
  ('fashion_scout',   'Fashion Scout',   'Hai iniziato a contribuire!',  '🔍', 50,   'Badge visibile sul profilo'),
  ('style_expert',    'Style Expert',    'Contributor esperto',          '⭐', 200,  'Accesso anticipato nuove review'),
  ('database_hero',   'Database Hero',   'Il database ti ringrazia',     '🏆', 500,  'Prodotti senza revisione'),
  ('worthy_legend',   'Worthy Legend',   'Leggenda della community',     '👑', 1000, 'Menzione stories Mattia'),
  ('top_contributor', 'Top Contributor', 'Top 10 del mese',              '🥇', 0,    'Badge esclusivo + shoutout')
ON CONFLICT (id) DO NOTHING;
