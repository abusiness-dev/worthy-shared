-- ════════════════════════════════════════════════════════════════════
-- Migration: hard-delete dei prodotti nelle categorie non supportate.
--
-- Scelta prodotto: rimozione definitiva (non soft-hide) dei capi in categorie
-- escluse (calzature, intimo, calze, costumi, accessori, activewear — vedi
-- 20260605000005).
--
-- Sicurezza FK: tutte le tabelle figlie di products hanno ON DELETE CASCADE
-- (price_history, product_votes, product_reports, scan_history, saved_products,
-- product_duplicates, product_certifications e link-tables v2); daily_worthy ha
-- ON DELETE SET NULL. saved_comparisons.product_ids è un array senza FK: eventuali
-- UUID orfani restano nell'array (l'app già tollera prodotti mancanti).
--
-- ⚠️ Operazione irreversibile: eseguire dopo backup del DB.
-- ════════════════════════════════════════════════════════════════════

DO $$
DECLARE
  n_products integer;
  n_categories integer;
BEGIN
  SELECT count(*) INTO n_categories
  FROM categories WHERE is_supported = false;

  SELECT count(*) INTO n_products
  FROM products
  WHERE category_id IN (SELECT id FROM categories WHERE is_supported = false);

  DELETE FROM products
  WHERE category_id IN (SELECT id FROM categories WHERE is_supported = false);

  RAISE NOTICE 'Hard-delete categorie non supportate: % prodotti rimossi da % categorie',
    n_products, n_categories;
END $$;

-- Riallinea le medie aggregate sui brand dopo la rimozione (il trigger per-riga
-- ha già aggiornato category_tier_aggregates e le mediane di categoria).
SELECT recalculate_brand_avg_scores();
