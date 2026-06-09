-- ════════════════════════════════════════════════════════════════════
-- HARDENING pre-lancio (Wave 4.3) — riprogrammazione cron + osservabilità.
--
-- CAMBIAMENTI:
--   1) cleanup-function-calls-throttle: da */30 (retention 1h) a */5 (retention 10min).
--      La finestra utile del throttle è 1 minuto: DELETE piccoli e frequenti generano
--      meno bloat di un DELETE grosso ogni 30 min (combinare col tuning autovacuum 4.2).
--   2) refresh-trending-products: da */15 a orario. "Trending 48h" è insensibile a 15
--      min; il refresh CONCURRENTLY su scan_history (che cresce) costa, ridurne la
--      frequenza taglia il costo. (refresh-brand-rankings resta */15.)
--   3) cleanup-cron-history: pota cron.job_run_details (cresce indefinitamente con i job
--      ogni 2/5/15 min) mantenendo 7 giorni di storico per il debug.
--
-- Idempotente: unschedule via cron.job (no-op se il job non esiste) + reschedule.
-- ════════════════════════════════════════════════════════════════════

-- 1. Throttle cleanup: */5, retention 10 minuti.
SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'cleanup-function-calls-throttle';
SELECT cron.schedule(
  'cleanup-function-calls-throttle',
  '*/5 * * * *',
  $$DELETE FROM function_calls_throttle WHERE called_at < now() - interval '10 minutes'$$
);

-- 2. Trending refresh: orario.
SELECT cron.unschedule(jobid) FROM cron.job WHERE jobname = 'refresh-trending-products';
SELECT cron.schedule(
  'refresh-trending-products',
  '0 * * * *',
  $$REFRESH MATERIALIZED VIEW CONCURRENTLY trending_products$$
);

-- 3. Pulizia storico cron.
SELECT cron.schedule(
  'cleanup-cron-history',
  '15 4 * * *',
  $$DELETE FROM cron.job_run_details WHERE end_time < now() - interval '7 days'$$
);
