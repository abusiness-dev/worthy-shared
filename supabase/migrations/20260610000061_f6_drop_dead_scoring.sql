-- ════════════════════════════════════════════════════════════════════
-- HARDENING pre-lancio (Wave 7 / F6 parziale) — DROP delle funzioni di scoring v1
-- ormai fuori dal path live.
--
-- Verificato (audit) che NESSUN trigger/funzione LIVE le richiama:
--   - calculate_qpr(uuid): sostituita da calculate_qpr_cluster (path canonico v2).
--   - calculate_origin_lens / calculate_technical_lens / calculate_sustainability_lens:
--     la v2 corrente (20260518000001) usa SOLO calculate_manufacturing_lens.
-- Erano già REVOKE da PUBLIC/anon/authenticated (F8), quindi nessun consumer esterno
-- può chiamarle. DROP IF EXISTS è no-op se assenti.
--
-- NON tocchiamo: calculate_manufacturing_lens (LIVE), né la tabella
-- category_segment_aggregates (deprecata ma potenziale lettura esterna da worthy-admin:
-- il suo drop resta gated alla fase F6 completa, post verifica consumer + 30gg stabilità).
-- ════════════════════════════════════════════════════════════════════

DROP FUNCTION IF EXISTS calculate_qpr(uuid);
DROP FUNCTION IF EXISTS calculate_origin_lens(uuid);
DROP FUNCTION IF EXISTS calculate_technical_lens(uuid);
DROP FUNCTION IF EXISTS calculate_sustainability_lens(uuid);
