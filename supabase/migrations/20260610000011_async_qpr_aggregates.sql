-- ════════════════════════════════════════════════════════════════════
-- HARDENING pre-lancio (Wave 2.3) — ricalcolo aggregati QPR ASINCRONO (coda + cron).
--
-- PROBLEMA:
--   trg_products_qpr_aggregates (AFTER INSERT/UPDATE/DELETE FOR EACH ROW) eseguiva
--   SINCRONO, dentro la transazione utente, fino a 5 percentile_cont (full sort sul
--   cluster category×comparison_tier + sulla categoria) PER OGNI riga scritta. Gli
--   import scraper diventano ~O(prodotti × dimensione_cluster) e l'editing concorrente
--   nella stessa categoria genera lock contention sulle righe aggregate.
--
-- SOLUZIONE (refactor async):
--   - Il trigger diventa un MARCATORE O(1): inserisce le coppie (category, tier)
--     "sporche" in qpr_aggregate_dirty (ON CONFLICT DO NOTHING).
--   - Un job pg_cron (ogni 2 min) DRENA la coda ricalcolando una sola volta per
--     cluster sporco, fuori dal path utente. Idempotente e at-least-once (se il drain
--     fallisce, la transazione rolla back e le righe restano in coda).
--   NB: il marcatore NON ha la guardia worthy.skip_protection: i writeback di
--   score_composition/score_manufacturing dello scoring CAMBIANO realmente le mediane
--   del cluster (median_quality_index/median_manufacturing) e DEVONO marcare dirty;
--   l'enqueue è O(1) con dedup via PK, quindi marcare 1-3x è innocuo.
--
--   Correttezza dello score del nuovo prodotto: alla INSERT, calculate_qpr_cluster
--   valuta il capo contro le mediane PRE-ESISTENTI (il riferimento corretto; il
--   contributo del singolo nuovo capo alla mediana è trascurabile). Il cron rinfresca
--   gli aggregati entro 2 min per tutti gli altri.
--
-- IMPORT BULK (scraper, service_role): per evitare anche solo l'overhead del marcatore
--   per-riga, disabilitare il trigger per la durata del batch e ricalcolare una volta a
--   fine import — vedi scripts/README.md.
--
-- VALIDARE: un UPDATE products NON deve più eseguire percentile_cont sincroni (solo un
--   INSERT in qpr_aggregate_dirty); dopo ~2 min category_tier_aggregates riflette il
--   cambiamento. `SELECT public.drain_qpr_aggregate_dirty()` svuota la coda on-demand.
-- ════════════════════════════════════════════════════════════════════

-- ============================================================
-- 1. Coda dei cluster "sporchi"
-- ============================================================

CREATE TABLE IF NOT EXISTS public.qpr_aggregate_dirty (
  category_id     uuid NOT NULL,
  comparison_tier text NOT NULL,
  enqueued_at     timestamptz NOT NULL DEFAULT now(),
  PRIMARY KEY (category_id, comparison_tier)
);

COMMENT ON TABLE public.qpr_aggregate_dirty IS
  'Coda dei cluster (category × comparison_tier) le cui mediane QPR vanno ricalcolate. Riempita O(1) dal trigger sui products, drenata dal cron recalc-qpr-aggregates.';

ALTER TABLE public.qpr_aggregate_dirty ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.qpr_aggregate_dirty FROM anon, authenticated;
-- Nessuna policy: scritta dal trigger SECURITY DEFINER (owner) e letta/drenata da service_role/cron.

-- ============================================================
-- 2. Trigger marcatore O(1) (sostituisce il ricalcolo sincrono)
-- ============================================================

CREATE OR REPLACE FUNCTION public.trigger_recalc_qpr_aggregates()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  old_tier text;
  new_tier text;
BEGIN
  IF TG_OP = 'INSERT' THEN
    SELECT b.comparison_tier INTO new_tier FROM brands b WHERE b.id = NEW.brand_id;
    IF new_tier IS NOT NULL THEN
      INSERT INTO qpr_aggregate_dirty (category_id, comparison_tier)
        VALUES (NEW.category_id, new_tier) ON CONFLICT DO NOTHING;
    END IF;

  ELSIF TG_OP = 'UPDATE' THEN
    IF NEW.brand_id              IS DISTINCT FROM OLD.brand_id
       OR NEW.category_id        IS DISTINCT FROM OLD.category_id
       OR NEW.price              IS DISTINCT FROM OLD.price
       OR NEW.composition        IS DISTINCT FROM OLD.composition
       OR NEW.is_active          IS DISTINCT FROM OLD.is_active
       OR NEW.score_composition  IS DISTINCT FROM OLD.score_composition
       OR NEW.score_manufacturing IS DISTINCT FROM OLD.score_manufacturing
    THEN
      SELECT b.comparison_tier INTO old_tier FROM brands b WHERE b.id = OLD.brand_id;
      SELECT b.comparison_tier INTO new_tier FROM brands b WHERE b.id = NEW.brand_id;

      IF old_tier IS NOT NULL THEN
        INSERT INTO qpr_aggregate_dirty (category_id, comparison_tier)
          VALUES (OLD.category_id, old_tier) ON CONFLICT DO NOTHING;
      END IF;
      IF new_tier IS NOT NULL AND (NEW.category_id IS DISTINCT FROM OLD.category_id
                                   OR new_tier IS DISTINCT FROM old_tier) THEN
        INSERT INTO qpr_aggregate_dirty (category_id, comparison_tier)
          VALUES (NEW.category_id, new_tier) ON CONFLICT DO NOTHING;
      END IF;
    END IF;

  ELSIF TG_OP = 'DELETE' THEN
    SELECT b.comparison_tier INTO old_tier FROM brands b WHERE b.id = OLD.brand_id;
    IF old_tier IS NOT NULL THEN
      INSERT INTO qpr_aggregate_dirty (category_id, comparison_tier)
        VALUES (OLD.category_id, old_tier) ON CONFLICT DO NOTHING;
    END IF;
  END IF;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trigger_recalc_qpr_aggregates IS
  'Marcatore O(1): accoda (category × comparison_tier) in qpr_aggregate_dirty su cambio dei campi sorgente/score di products. Il ricalcolo pesante (percentile_cont) è demandato al cron drain_qpr_aggregate_dirty (Wave 2.3).';

-- Il trigger trg_products_qpr_aggregates (20260428000002:236) già punta a questa
-- funzione: la riscrittura in place è sufficiente.

-- ============================================================
-- 3. Drain della coda (chiamato dal cron) — batched & idempotente
-- ============================================================

CREATE OR REPLACE FUNCTION public.drain_qpr_aggregate_dirty(p_limit int DEFAULT 500)
RETURNS int
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  r record;
  n int := 0;
BEGIN
  -- Claim atomico di un batch: sposta fino a p_limit righe da qpr_aggregate_dirty a una
  -- temp table via DELETE…RETURNING dentro un CTE data-modifying. Se qualcosa fallisce
  -- dopo, l'intera transazione (cron) rolla back e le righe restano accodate (retry).
  -- (CREATE TABLE AS è utility e non sostituisce le variabili plpgsql; quindi creiamo la
  --  temp table vuota e poi facciamo l'INSERT … SELECT che supporta LIMIT p_limit.)
  CREATE TEMP TABLE _claimed (category_id uuid, comparison_tier text) ON COMMIT DROP;

  WITH del AS (
    DELETE FROM qpr_aggregate_dirty
    WHERE ctid IN (
      SELECT ctid FROM qpr_aggregate_dirty ORDER BY enqueued_at LIMIT p_limit
    )
    RETURNING category_id, comparison_tier
  )
  INSERT INTO _claimed (category_id, comparison_tier)
  SELECT category_id, comparison_tier FROM del;

  -- Mediane di categoria (una per categoria distinta toccata).
  FOR r IN SELECT DISTINCT category_id FROM _claimed LOOP
    PERFORM recalculate_category_medians(r.category_id);
  END LOOP;

  -- Aggregati per (categoria × lega).
  FOR r IN SELECT category_id, comparison_tier FROM _claimed LOOP
    PERFORM recalculate_category_tier_aggregates(r.category_id, r.comparison_tier);
    n := n + 1;
  END LOOP;

  RETURN n;
END;
$$;

COMMENT ON FUNCTION public.drain_qpr_aggregate_dirty IS
  'Drena fino a p_limit cluster da qpr_aggregate_dirty e ne ricalcola mediane (categoria) e aggregati (categoria×lega). Idempotente, at-least-once. Chiamato dal cron recalc-qpr-aggregates.';

REVOKE ALL ON FUNCTION public.drain_qpr_aggregate_dirty(int) FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.drain_qpr_aggregate_dirty(int) TO service_role;

-- ============================================================
-- 4. Cron: drena ogni 2 minuti
-- ============================================================

SELECT cron.schedule(
  'recalc-qpr-aggregates',
  '*/2 * * * *',
  $$SELECT public.drain_qpr_aggregate_dirty(500)$$
);

-- Drain iniziale per non lasciare in sospeso eventuali enqueue del reset.
SELECT public.drain_qpr_aggregate_dirty(100000);
