-- Worthy Score v2 - Seed brand_certifications best-effort.
--
-- Inserisce certificazioni brand-level note per i brand già presenti nel DB.
-- Best-effort: usa WHERE EXISTS, non fallisce se un brand non esiste ancora.
-- ON CONFLICT DO NOTHING per idempotenza.
--
-- Seed conservativo: include solo certificazioni con commitment pubblico
-- documentato. Per aggiungere brand B Corp/Bluesign/Fair Trade (Patagonia,
-- Arc'teryx, ecc.) prima va seedato il brand stesso, poi aggiunto qui.

-- ============================================================
-- Made in Italy 100% (Law 206/2023): maison italiane storiche con
-- filiera integralmente italiana documentata.
-- ============================================================

INSERT INTO brand_certifications (brand_id, certification_id)
SELECT b.id, 'made_in_italy_100'::text
FROM brands b
WHERE b.slug IN (
  'loro-piana',
  'brunello-cucinelli',
  'kiton',
  'brioni',
  'canali',
  'ermenegildo-zegna',
  'stone-island',
  'moncler',
  'fendi',
  'valentino',
  'versace',
  'dolce-and-gabbana',
  'bottega-veneta',
  'prada',
  'gucci',
  'giorgio-armani'
)
ON CONFLICT DO NOTHING;

-- ============================================================
-- Better Cotton Initiative: brand con programma BCI documentato a
-- livello brand (commitment pubblico, certificazione mass-balance).
-- ============================================================

INSERT INTO brand_certifications (brand_id, certification_id)
SELECT b.id, 'better_cotton_bci'::text
FROM brands b
WHERE b.slug IN (
  'uniqlo',
  'h-and-m',
  'cos',
  'levis',
  'tommy-hilfiger',
  'calvin-klein',
  'ovs',
  'c-and-a',
  'arket',
  'and-other-stories',
  'monki',
  'weekday'
)
ON CONFLICT DO NOTHING;

-- ============================================================
-- Ricalcolo v2 in shadow per i prodotti dei brand affected.
-- (Il sustainability_lens ora aggiunge bonus a quei prodotti.)
-- ============================================================

DO $$
DECLARE
  r record;
  n integer := 0;
BEGIN
  FOR r IN
    SELECT DISTINCT p.id
    FROM products p
    JOIN brand_certifications bc ON bc.brand_id = p.brand_id
    WHERE p.is_active = true
  LOOP
    PERFORM calculate_worthy_score_v2(r.id);
    n := n + 1;
  END LOOP;

  RAISE NOTICE 'Ricalcolo v2 post-seed brand_certifications: % prodotti', n;
END $$;
