-- ============================================================
-- Deduplicazione prodotti
-- 1. Trova i gruppi di duplicati (stesso brand + nome molto simile, o stesso barcode)
-- 2. Sceglie il prodotto "canonico" per ogni gruppo
-- 3. Migra saved_products, scan_history, product_votes al canonico
-- 4. Registra i duplicati nella tabella product_duplicates
-- 5. Disattiva i doppioni (soft delete)
-- ============================================================

BEGIN;

-- ── Step 1: tabella temporanea con le coppie di duplicati ───
-- Trova prodotti attivi dello stesso brand con nome similarity > 0.7
-- Usa una window function per assegnare un "canonical" per gruppo

CREATE TEMP TABLE _dup_pairs AS
WITH pairs AS (
  SELECT
    a.id AS product_a,
    b.id AS product_b,
    similarity(a.name, b.name) AS name_sim,
    a.brand_id
  FROM products a
  JOIN products b
    ON a.brand_id = b.brand_id
    AND a.id < b.id                       -- evita duplicati e self-join
    AND a.is_active = true
    AND b.is_active = true
    AND similarity(a.name, b.name) > 0.7  -- soglia alta per evitare falsi positivi
)
SELECT * FROM pairs;

-- Aggiungi anche coppie con lo stesso barcode (anche se nomi diversi)
INSERT INTO _dup_pairs (product_a, product_b, name_sim, brand_id)
SELECT
  a.id, b.id,
  similarity(a.name, b.name),
  a.brand_id
FROM products a
JOIN products b
  ON a.ean_barcode = b.ean_barcode
  AND a.ean_barcode IS NOT NULL
  AND a.id < b.id
  AND a.is_active = true
  AND b.is_active = true
ON CONFLICT DO NOTHING;  -- la temp table non ha PK, ma evitiamo duplicati logici con la condizione a.id < b.id

-- ── Step 2: per ogni coppia, scegli il prodotto canonico ────
-- Criteri (in ordine di priorità):
--   1. verification_status più alto (mattia_reviewed > verified > unverified)
--   2. scan_count più alto
--   3. community_votes_count più alto
--   4. created_at più vecchio (il primo inserito)

CREATE TEMP TABLE _dup_resolved AS
SELECT DISTINCT ON (duplicate_id)
  canonical_id,
  duplicate_id,
  name_sim
FROM (
  SELECT
    CASE
      WHEN rank_a <= rank_b THEN product_a
      ELSE product_b
    END AS canonical_id,
    CASE
      WHEN rank_a <= rank_b THEN product_b
      ELSE product_a
    END AS duplicate_id,
    name_sim
  FROM (
    SELECT
      dp.product_a,
      dp.product_b,
      dp.name_sim,
      -- Rank per product_a (lower = better)
      (CASE a.verification_status
        WHEN 'mattia_reviewed' THEN 0
        WHEN 'verified' THEN 1
        ELSE 2
      END * 1000000
      - a.scan_count * 1000
      - a.community_votes_count * 10
      + EXTRACT(EPOCH FROM a.created_at) / 1000000) AS rank_a,
      -- Rank per product_b
      (CASE b.verification_status
        WHEN 'mattia_reviewed' THEN 0
        WHEN 'verified' THEN 1
        ELSE 2
      END * 1000000
      - b.scan_count * 1000
      - b.community_votes_count * 10
      + EXTRACT(EPOCH FROM b.created_at) / 1000000) AS rank_b
    FROM _dup_pairs dp
    JOIN products a ON a.id = dp.product_a
    JOIN products b ON b.id = dp.product_b
  ) ranked
) resolved
ORDER BY duplicate_id, name_sim DESC;

-- ── Step 3: migra i dati correlati al prodotto canonico ─────

-- 3a. saved_products: sposta i salvataggi al prodotto canonico
-- Usa ON CONFLICT per evitare violazioni del vincolo unique (user_id, product_id)
INSERT INTO saved_products (user_id, product_id, created_at)
SELECT sp.user_id, dr.canonical_id, sp.created_at
FROM saved_products sp
JOIN _dup_resolved dr ON sp.product_id = dr.duplicate_id
ON CONFLICT (user_id, product_id) DO NOTHING;

-- Elimina i vecchi riferimenti ai duplicati
DELETE FROM saved_products sp
USING _dup_resolved dr
WHERE sp.product_id = dr.duplicate_id;

-- 3b. scan_history: aggiorna il product_id verso il canonico
UPDATE scan_history sh
SET product_id = dr.canonical_id
FROM _dup_resolved dr
WHERE sh.product_id = dr.duplicate_id;

-- 3c. product_votes: sposta i voti al prodotto canonico
INSERT INTO product_votes (product_id, user_id, score, fit_score, durability_score, comment, created_at)
SELECT dr.canonical_id, pv.user_id, pv.score, pv.fit_score, pv.durability_score, pv.comment, pv.created_at
FROM product_votes pv
JOIN _dup_resolved dr ON pv.product_id = dr.duplicate_id
ON CONFLICT (product_id, user_id) DO NOTHING;

DELETE FROM product_votes pv
USING _dup_resolved dr
WHERE pv.product_id = dr.duplicate_id;

-- 3d. price_history: sposta al canonico
UPDATE price_history ph
SET product_id = dr.canonical_id
FROM _dup_resolved dr
WHERE ph.product_id = dr.duplicate_id;

-- 3e. product_reports: sposta al canonico
UPDATE product_reports pr
SET product_id = dr.canonical_id
FROM _dup_resolved dr
WHERE pr.product_id = dr.duplicate_id;

-- 3f. Somma scan_count dei duplicati al canonico
UPDATE products p
SET scan_count = p.scan_count + COALESCE(dup_scans.total, 0)
FROM (
  SELECT dr.canonical_id, SUM(dup.scan_count) AS total
  FROM _dup_resolved dr
  JOIN products dup ON dup.id = dr.duplicate_id
  GROUP BY dr.canonical_id
) dup_scans
WHERE p.id = dup_scans.canonical_id;

-- ── Step 4: registra nella tabella product_duplicates ───────

INSERT INTO product_duplicates (product_id, duplicate_of, similarity_score, status, resolved_at)
SELECT
  duplicate_id,
  canonical_id,
  name_sim,
  'confirmed_duplicate',
  now()
FROM _dup_resolved;

-- ── Step 5: soft-delete dei duplicati ───────────────────────

UPDATE products
SET is_active = false, updated_at = now()
WHERE id IN (SELECT duplicate_id FROM _dup_resolved);

-- ── Cleanup ─────────────────────────────────────────────────

DROP TABLE _dup_pairs;
DROP TABLE _dup_resolved;

-- ── Ricalcola community scores per i prodotti canonici ──────

UPDATE products p
SET
  community_score = sub.avg_score,
  community_votes_count = sub.vote_count
FROM (
  SELECT
    pv.product_id,
    ROUND(AVG(pv.score) * 10, 2) AS avg_score,
    COUNT(*) AS vote_count
  FROM product_votes pv
  JOIN products pr ON pr.id = pv.product_id AND pr.is_active = true
  GROUP BY pv.product_id
) sub
WHERE p.id = sub.product_id
  AND p.is_active = true;

COMMIT;
