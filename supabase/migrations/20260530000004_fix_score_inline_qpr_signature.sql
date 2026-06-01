-- ============================================================
-- FIX [CRITICO, già rotto in produzione]: allinea calculate_score_inline alla
-- firma a 5 argomenti di calculate_qpr_cluster.
--
-- PROBLEMA:
--   20260518000001_qpr_quality_index (GIÀ APPLICATA IN PRODUZIONE) ha fatto
--     DROP FUNCTION calculate_qpr_cluster(integer, uuid, uuid, numeric)
--   e l'ha ricreata a 5 argomenti (aggiungendo p_manuf_score numeric come 2°
--   parametro), aggiornando calculate_worthy_score_v2 ma NON calculate_score_inline
--   (definita in 20260517000004, ancora ferma alla firma a 4 argomenti).
--   Risultato in produzione: il trigger BEFORE INSERT protect_product_privileged_fields
--   → calculate_score_inline → calculate_qpr_cluster(integer,uuid,uuid,numeric)
--   NON ESISTE PIÙ → OGNI INSERT/UPDATE prodotto da utente loggato fallisce con
--   "function calculate_qpr_cluster(...) does not exist". (Gli import scraper via
--   service_role bypassano il trigger, quindi il bug non era emerso.)
--   La correzione NON poteva stare in 20260518000001 (già applicata: db push non
--   ri-esegue una migration già presente nel remoto) → serve questa forward migration.
--
-- FIX:
--   CREATE OR REPLACE calculate_score_inline (stessa firma jsonb,numeric,uuid,uuid)
--   con la chiamata corretta a 5 argomenti. Inline non dispone della lente
--   manufacturing (prodotto non ancora inserito) → passa NULL come p_manuf_score:
--   è esattamente l'intento documentato in 20260518000001. È sicuro:
--   compute_quality_index(comp, NULL) ritorna comp, e il bonus manuf in
--   calculate_qpr_cluster è applicato solo se p_manuf_score IS NOT NULL.
--   Il valore inline è comunque transitorio: subito dopo l'INSERT il trigger AFTER
--   chiama calculate_worthy_score (→ v2) che sovrascrive con tutte le lenti.
-- ============================================================

CREATE OR REPLACE FUNCTION calculate_score_inline(
  p_composition jsonb,
  p_price       numeric,
  p_category_id uuid,
  p_brand_id    uuid DEFAULT NULL
)
RETURNS TABLE(
  comp_score    integer,
  qpr_score     integer,
  worthy_score  integer,
  final_verdict verdict
)
LANGUAGE plpgsql STABLE
SET search_path = public
AS $$
DECLARE
  v_comp  integer;
  v_qpr   integer;
  v_score integer;
  v_verd  verdict;
  raw_score numeric;
BEGIN
  v_comp := calculate_composition_score(p_composition);
  -- Firma a 5 argomenti: p_manuf_score = NULL (inline senza lente manufacturing).
  v_qpr  := calculate_qpr_cluster(v_comp, NULL::numeric, p_brand_id, p_category_id, p_price);

  -- Aggregazione senza manufacturing: rinormalizza composition+qpr su 0.75.
  raw_score := (v_comp * 0.50 + v_qpr * 0.25) / 0.75;
  v_score := LEAST(100, GREATEST(0, round(raw_score)::integer));

  v_verd := CASE
    WHEN v_score >= 86 THEN 'steal'::verdict
    WHEN v_score >= 71 THEN 'worthy'::verdict
    WHEN v_score >= 51 THEN 'fair'::verdict
    WHEN v_score >= 31 THEN 'meh'::verdict
    ELSE 'not_worthy'::verdict
  END;

  comp_score    := v_comp;
  qpr_score     := v_qpr;
  worthy_score  := v_score;
  final_verdict := v_verd;
  RETURN NEXT;
END;
$$;

COMMENT ON FUNCTION calculate_score_inline IS
  'Score inline (BEFORE INSERT) con calculate_qpr_cluster a 5 arg (p_manuf_score=NULL inline). Valore transitorio: il trigger AFTER ricalcola con tutte le lenti. Forward-fix del mismatch di firma introdotto in 20260518000001.';
