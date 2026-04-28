-- F5 - Worthy Score v2 diventa il valore canonico in products.worthy_score.
--
-- calculate_worthy_score(uuid) viene riscritta come "wrapper" che delega a
-- calculate_worthy_score_v2 e persiste il risultato v2 in:
--   - worthy_score      ← (breakdown -> final)
--   - verdict           ← (breakdown -> verdict)
--   - score_composition ← (breakdown -> lenses -> composition -> score)
--   - score_qpr         ← (breakdown -> lenses -> qpr -> score)
--
-- score_origin, score_manufacturing, score_technical, score_sustainability,
-- score_confidence, score_breakdown vengono già aggiornati da
-- calculate_worthy_score_v2.
--
-- Da questo momento l'app legge worthy_score = v2. v1 logic non viene più
-- calcolata. score_fit / score_durability restano NULL.
--
-- calculate_score_inline (usata dal BEFORE INSERT trigger per popolare i campi
-- score quando il prodotto non esiste ancora nel DB) resta INVARIATA: calcola
-- ancora v1 70/30 inline. Subito dopo l'INSERT, il trigger AFTER INSERT chiama
-- calculate_worthy_score che SOVRASCRIVE con v2. Quindi a transazione completa
-- lo score persistito è v2.

CREATE OR REPLACE FUNCTION calculate_worthy_score(p_product_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  v2_breakdown jsonb;
  v2_score integer;
  v2_verdict verdict;
  v2_comp integer;
  v2_qpr integer;
BEGIN
  PERFORM set_config('worthy.skip_protection', 'true', true);

  -- Calcola via v2 (popola anche score_origin/manuf/technical/sustainability/
  -- confidence/breakdown internamente).
  v2_breakdown := calculate_worthy_score_v2(p_product_id);

  v2_score   := (v2_breakdown ->> 'final')::integer;
  v2_verdict := (v2_breakdown ->> 'verdict')::verdict;
  v2_comp    := (v2_breakdown -> 'lenses' -> 'composition' ->> 'score')::integer;
  v2_qpr     := (v2_breakdown -> 'lenses' -> 'qpr' ->> 'score')::integer;

  -- v2 alla fine ha resettato worthy.skip_protection a 'false'; lo riattivo
  -- prima del nostro UPDATE finale che tocca worthy_score (campo protetto).
  PERFORM set_config('worthy.skip_protection', 'true', true);

  UPDATE products
  SET
    worthy_score      = v2_score,
    verdict           = v2_verdict,
    score_composition = v2_comp,
    score_qpr         = v2_qpr,
    score_fit         = NULL,
    score_durability  = NULL
  WHERE id = p_product_id;

  PERFORM set_config('worthy.skip_protection', 'false', true);

  RETURN v2_score;
END;
$$;

COMMENT ON FUNCTION calculate_worthy_score IS
  'Worthy Score CANONICO (v2). Wrapper su calculate_worthy_score_v2 che persiste breakdown.final in products.worthy_score. SECURITY DEFINER per RLS bypass.';

-- ============================================================
-- Ricalcolo massivo: tutti i prodotti attivi vengono allineati al nuovo
-- algoritmo canonico. Da questo momento l'app vede direttamente i numeri v2.
-- ============================================================

DO $$
DECLARE
  r record;
  n integer := 0;
BEGIN
  FOR r IN SELECT id FROM products WHERE is_active = true LOOP
    PERFORM calculate_worthy_score(r.id);
    n := n + 1;
  END LOOP;

  RAISE NOTICE 'F5 switch v2 canonico: % prodotti aggiornati, worthy_score ora riflette v2', n;
END $$;

-- Aggiorna le medie aggregate sui brand
SELECT recalculate_brand_avg_scores();
