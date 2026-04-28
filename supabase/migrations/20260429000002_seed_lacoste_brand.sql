-- Seed brand Lacoste (premium). I prodotti vengono importati separatamente
-- da scripts/scraper/src/seed-lacoste.ts a partire dal file Excel del catalogo IT.

INSERT INTO brands (id, name, slug, description, origin_country, market_segment) VALUES
  (
    gen_random_uuid(),
    'Lacoste',
    'lacoste',
    'Maison francese di sportswear premium fondata nel 1933 da René Lacoste. Riferimento globale della polo classica L.12.12, eleganza sportiva con heritage tennis.',
    'France',
    'premium'
  )
ON CONFLICT (slug) DO NOTHING;
