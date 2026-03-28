-- Crea cron jobs con pg_cron: refresh materialized views ogni 15 minuti
-- NOTA: pg_cron è abilitato di default sui piani Supabase Pro.
-- Sul piano Free, queste schedule non funzioneranno e il refresh
-- dovrà essere fatto manualmente o tramite Edge Function.

CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Refresh brand_rankings ogni 15 minuti
SELECT cron.schedule(
  'refresh-brand-rankings',
  '*/15 * * * *',
  $$REFRESH MATERIALIZED VIEW CONCURRENTLY brand_rankings$$
);

-- Refresh trending_products ogni 15 minuti
SELECT cron.schedule(
  'refresh-trending-products',
  '*/15 * * * *',
  $$REFRESH MATERIALIZED VIEW CONCURRENTLY trending_products$$
);
