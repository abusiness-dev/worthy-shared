-- Aggiunge 5 categorie per supportare brand fast-fashion donna (BERSHKA,
-- Mango, Pull&Bear, Stradivarius, Zara, H&M). Distinte semanticamente da
-- quelle premium uomo introdotte in 20260425000001.
--
--   - gonna:    skirt (mini, midi, lunga)
--   - vestito:  dress femminile (mini/midi/lungo); distinto da `abito` che è
--               il completo formale uomo (giacca + pantalone)
--   - top:      top femminile generico (bandeau, halter, bustier, ecc.) —
--               distinto da t-shirt-basic (tagli classici) e canotta (tank)
--   - stivali:  boots, ankle boots, knee-high
--   - sandali:  sandals, flip-flop, infradito
--
-- Idempotente: ON CONFLICT (slug) DO NOTHING. avg_price/avg_composition_score
-- riflettono la fascia fast-fashion (sintetici, prezzi bassi).

INSERT INTO categories (id, name, slug, icon, avg_price, avg_composition_score) VALUES
  (gen_random_uuid(), 'Gonne',    'gonna',    '👗', 25.00, 55.00),
  (gen_random_uuid(), 'Vestiti',  'vestito',  '👗', 35.00, 55.00),
  (gen_random_uuid(), 'Top',      'top',      '👚', 18.00, 55.00),
  (gen_random_uuid(), 'Stivali',  'stivali',  '👢', 50.00, 55.00),
  (gen_random_uuid(), 'Sandali',  'sandali',  '🩴', 35.00, 55.00)
ON CONFLICT (slug) DO NOTHING;
