-- ════════════════════════════════════════════════════════════════════
-- HARDENING pre-lancio (Wave 4.2) — tuning autovacuum/fillfactor sulle tabelle
-- ad alta scrittura.
--
-- PROBLEMA: i default Postgres (autovacuum_vacuum_scale_factor=0.2 → vacuum solo dopo
--   il 20% di dead tuple) su tabelle grandi lasciano accumulare bloat. In particolare
--   function_calls_throttle (insert+delete ad alto churn) accumula dead tuple tra un
--   cleanup e l'altro.
--
-- SOLUZIONE: soglie autovacuum più aggressive sulle tabelle hot; fillfactor<100 su
--   products per favorire gli HOT update degli score (writeback dello scoring su colonne
--   non indicizzate). Valori = punti di partenza, da tarare col carico reale.
--   NB: fillfactor si applica alle pagine nuove; le esistenti si compattano col tempo
--   (o con un VACUUM FULL manuale, non necessario qui).
-- ════════════════════════════════════════════════════════════════════

-- Alto churn insert+delete: vacuum molto aggressivo.
ALTER TABLE public.function_calls_throttle
  SET (autovacuum_vacuum_scale_factor = 0.02, autovacuum_vacuum_cost_delay = 2);

ALTER TABLE public.claude_usage_counter
  SET (autovacuum_vacuum_scale_factor = 0.02, autovacuum_vacuum_cost_delay = 2);

ALTER TABLE public.qpr_aggregate_dirty
  SET (autovacuum_vacuum_scale_factor = 0.05, autovacuum_vacuum_cost_delay = 2);

-- Append-only ad alto volume: soglia più bassa del default per contenere il bloat.
ALTER TABLE public.scan_history
  SET (autovacuum_vacuum_scale_factor = 0.05);

ALTER TABLE public.audit_log
  SET (autovacuum_vacuum_scale_factor = 0.05);

ALTER TABLE public.price_history
  SET (autovacuum_vacuum_scale_factor = 0.05);

-- products: write-amplification dello scoring → fillfactor per HOT update.
ALTER TABLE public.products
  SET (fillfactor = 90);
