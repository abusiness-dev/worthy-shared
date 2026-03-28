-- Crea materialized views: brand_rankings, trending_products

-- ============================================================
-- brand_rankings: classifica brand per score medio
-- ============================================================

CREATE MATERIALIZED VIEW brand_rankings AS
SELECT
  b.id AS brand_id,
  b.name AS brand_name,
  b.slug AS brand_slug,
  b.market_segment,
  COUNT(p.id) AS product_count,
  COALESCE(round(AVG(p.worthy_score), 2), 0) AS avg_score,
  SUM(p.scan_count) AS total_scans,
  CASE
    WHEN AVG(p.worthy_score) >= 86 THEN 'steal'::verdict
    WHEN AVG(p.worthy_score) >= 71 THEN 'worthy'::verdict
    WHEN AVG(p.worthy_score) >= 51 THEN 'fair'::verdict
    WHEN AVG(p.worthy_score) >= 31 THEN 'meh'::verdict
    ELSE 'not_worthy'::verdict
  END AS avg_verdict
FROM brands b
LEFT JOIN products p ON p.brand_id = b.id AND p.is_active = true
GROUP BY b.id, b.name, b.slug, b.market_segment
ORDER BY avg_score DESC;

-- Indice univoco richiesto per REFRESH CONCURRENTLY
CREATE UNIQUE INDEX idx_brand_rankings_brand_id
  ON brand_rankings(brand_id);

COMMENT ON MATERIALIZED VIEW brand_rankings IS 'Classifica brand per Worthy Score medio — refresh ogni 15 minuti';

-- ============================================================
-- trending_products: prodotti con più scansioni nelle ultime 48h
-- ============================================================

CREATE MATERIALIZED VIEW trending_products AS
SELECT
  p.id AS product_id,
  p.name AS product_name,
  p.slug AS product_slug,
  p.brand_id,
  b.name AS brand_name,
  p.worthy_score,
  p.verdict,
  p.price,
  COUNT(sh.id) AS recent_scans,
  p.photo_urls
FROM products p
JOIN brands b ON b.id = p.brand_id
JOIN scan_history sh ON sh.product_id = p.id
  AND sh.created_at > now() - interval '48 hours'
WHERE p.is_active = true
GROUP BY p.id, p.name, p.slug, p.brand_id, b.name,
         p.worthy_score, p.verdict, p.price, p.photo_urls
ORDER BY recent_scans DESC
LIMIT 50;

-- Indice univoco richiesto per REFRESH CONCURRENTLY
CREATE UNIQUE INDEX idx_trending_products_product_id
  ON trending_products(product_id);

COMMENT ON MATERIALIZED VIEW trending_products IS 'Top 50 prodotti più scansionati nelle ultime 48h — refresh ogni 15 minuti';
