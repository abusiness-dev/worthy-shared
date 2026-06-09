-- ════════════════════════════════════════════════════════════════════
-- HARDENING pre-lancio (Wave 4.1) — retention conservativa + indice temporale.
--
-- SCELTA UTENTE: scan_history 12 mesi, audit_log 24 mesi, price_history ILLIMITATO.
--
-- PROBLEMA: scan_history (1 riga/scan) e audit_log (snapshot jsonb su ogni modifica
--   privilegiata) crescono senza limite → bloat, pressione su autovacuum, costo.
--
-- SOLUZIONE: indice temporale su scan_history(created_at) (oggi created_at è solo 2ª
--   colonna di idx_scan_history_product_date → un DELETE per range non lo sfrutta;
--   audit_log ha già idx_audit_log_created) + purge giornaliero a batch limitato.
--   A lancio NON c'è storico oltre soglia: il cron è preventivo. Il batch (50k) bound
--   il singolo DELETE; i DELETE prendono lock di riga (non bloccano letture/scritture).
--
-- price_history: NESSUN purge (scelta utente) — solo retro-compat.
-- ════════════════════════════════════════════════════════════════════

-- Indice temporale per il range-scan del purge (e del refresh trending).
CREATE INDEX IF NOT EXISTS idx_scan_history_created_at
  ON public.scan_history (created_at);

-- Purge generico per età (tabelle con colonna created_at), batch bounded.
CREATE OR REPLACE FUNCTION public.purge_old_rows(
  p_table   regclass,
  p_max_age interval,
  p_batch   int DEFAULT 50000
)
RETURNS bigint
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  n bigint;
BEGIN
  EXECUTE format(
    'DELETE FROM %s WHERE ctid IN (SELECT ctid FROM %s WHERE created_at < now() - $1 LIMIT %s)',
    p_table, p_table, p_batch
  ) USING p_max_age;
  GET DIAGNOSTICS n = ROW_COUNT;
  RETURN n;
END;
$$;

COMMENT ON FUNCTION public.purge_old_rows IS
  'Cancella fino a p_batch righe più vecchie di p_max_age da p_table (deve avere created_at). Idempotente; pensata per cron giornaliero. SECURITY DEFINER.';

REVOKE ALL ON FUNCTION public.purge_old_rows(regclass, interval, int) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.purge_old_rows(regclass, interval, int) TO service_role;

-- Cron notturni (orari sfalsati). Confermare i 24 mesi audit con gli obblighi legali.
SELECT cron.schedule(
  'purge-scan-history',
  '30 3 * * *',
  $$SELECT public.purge_old_rows('public.scan_history'::regclass, interval '12 months', 50000)$$
);

SELECT cron.schedule(
  'purge-audit-log',
  '45 3 * * *',
  $$SELECT public.purge_old_rows('public.audit_log'::regclass, interval '24 months', 50000)$$
);
