-- Espansione del catalogo categorie: da 9 categorie generiche a 36 categorie granulari
-- (tutte piatte, nessuna gerarchia). Le 9 categorie originali (t-shirt, felpe, jeans,
-- pantaloni, giacche, sneakers, camicie, intimo, accessori) vengono lasciate intatte
-- per preservare l'integrità referenziale dei prodotti già esistenti.
--
-- Idempotente: ON CONFLICT (slug) DO NOTHING. I valori di avg_price e
-- avg_composition_score sono stime iniziali per il segmento fast fashion (EUR);
-- verranno ricalcolati dai trigger quando i prodotti popoleranno le categorie.

INSERT INTO categories (id, name, slug, icon, avg_price, avg_composition_score) VALUES

  -- ============================================================
  -- T-shirt & Top
  -- ============================================================
  (gen_random_uuid(), 'T-shirt basic',       't-shirt-basic',    '👕', 12.00, 55.00),
  (gen_random_uuid(), 'T-shirt oversize',    't-shirt-oversize', '👕', 18.00, 58.00),
  (gen_random_uuid(), 'Polo',                'polo',             '👕', 20.00, 62.00),
  (gen_random_uuid(), 'Canotte',             'canotta',          '🩱', 10.00, 52.00),
  (gen_random_uuid(), 'Top sportivi',        'top-sportivo',     '💪', 25.00, 48.00),

  -- ============================================================
  -- Camicie
  -- ============================================================
  (gen_random_uuid(), 'Camicie',             'camicia',          '👔', 30.00, 65.00),

  -- ============================================================
  -- Felpe & Maglioni
  -- ============================================================
  (gen_random_uuid(), 'Felpe con cappuccio', 'felpa-cappuccio',  '🧥', 35.00, 60.00),
  (gen_random_uuid(), 'Felpe girocollo',     'felpa-girocollo',  '🧥', 30.00, 60.00),
  (gen_random_uuid(), 'Maglioni',            'maglione',         '🧶', 40.00, 55.00),
  (gen_random_uuid(), 'Cardigan',            'cardigan',         '🧶', 45.00, 58.00),

  -- ============================================================
  -- Giacche
  -- ============================================================
  (gen_random_uuid(), 'Bomber',              'bomber',           '🧥', 60.00, 55.00),
  (gen_random_uuid(), 'Parka',               'parka',            '🧥', 90.00, 58.00),
  (gen_random_uuid(), 'Blazer',              'blazer',           '🧥', 70.00, 62.00),
  (gen_random_uuid(), 'Piumini',             'piumino',          '🧥', 100.00, 50.00),
  (gen_random_uuid(), 'Giubbotti',           'giubbotto',        '🧥', 75.00, 55.00),

  -- ============================================================
  -- Pantaloni
  -- ============================================================
  (gen_random_uuid(), 'Chinos',              'chinos',           '👖', 35.00, 68.00),
  (gen_random_uuid(), 'Cargo',               'cargo',            '👖', 40.00, 65.00),
  (gen_random_uuid(), 'Jogger',              'jogger',           '👖', 30.00, 52.00),
  (gen_random_uuid(), 'Pantaloni eleganti',  'pantaloni-eleganti','👖', 45.00, 65.00),

  -- ============================================================
  -- Jeans
  -- ============================================================
  (gen_random_uuid(), 'Jeans slim',          'jeans-slim',       '👖', 35.00, 70.00),
  (gen_random_uuid(), 'Jeans regular',       'jeans-regular',    '👖', 35.00, 72.00),
  (gen_random_uuid(), 'Jeans wide leg',      'jeans-wide',       '👖', 40.00, 70.00),

  -- ============================================================
  -- Shorts
  -- ============================================================
  (gen_random_uuid(), 'Shorts',              'shorts',           '🩳', 25.00, 60.00),
  (gen_random_uuid(), 'Shorts sportivi',     'shorts-sportivi',  '🩳', 20.00, 45.00),

  -- ============================================================
  -- Intimo
  -- ============================================================
  (gen_random_uuid(), 'Intimo',              'intimo',           '🩲', 10.00, 55.00),
  (gen_random_uuid(), 'Calzini',             'calzini',          '🧦',  6.00, 58.00),

  -- ============================================================
  -- Scarpe
  -- ============================================================
  (gen_random_uuid(), 'Sneakers',            'sneakers',         '👟', 60.00, 45.00),
  (gen_random_uuid(), 'Scarpe eleganti',     'scarpe-eleganti',  '👞', 70.00, 60.00),

  -- ============================================================
  -- Accessori
  -- ============================================================
  (gen_random_uuid(), 'Cappelli',            'cappelli',         '🧢', 15.00, 55.00),
  (gen_random_uuid(), 'Sciarpe',             'sciarpe',          '🧣', 20.00, 58.00),
  (gen_random_uuid(), 'Cinture',             'cinture',          '👔', 25.00, 50.00),
  (gen_random_uuid(), 'Borse',               'borse',            '👜', 40.00, 42.00),

  -- ============================================================
  -- Costumi
  -- ============================================================
  (gen_random_uuid(), 'Costumi',             'costume',          '🩱', 25.00, 48.00),

  -- ============================================================
  -- Activewear
  -- ============================================================
  (gen_random_uuid(), 'Leggings',            'leggings',         '🦵', 25.00, 48.00),
  (gen_random_uuid(), 'Tute sportive',       'tuta',             '🏃', 55.00, 52.00)

ON CONFLICT (slug) DO NOTHING;
