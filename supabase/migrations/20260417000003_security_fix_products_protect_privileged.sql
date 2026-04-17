-- ============================================================
-- SECURITY FIX: Protegge campi privilegiati della tabella products
-- + Calcolo score inline per INSERT + scoring engine SECURITY DEFINER
--
-- VULNERABILITA CHIUSE:
--   V-003 (CRITICO): products_insert_auth permette INSERT con
--     verification_status='mattia_reviewed', scan_count=99999
--   V-004 (CRITICO): products_update_own_recent permette UPDATE
--     su worthy_score, verdict, verification_status entro 24h
--
-- BYPASS (OR logic):
--   1. Session variable worthy.skip_protection = 'true'
--      (impostata da calculate_worthy_score per lo scoring engine)
--   2. is_service_role_or_internal() = TRUE
--      (per worthy-admin via service_role key PostgREST)
--
-- CAMPI PROTETTI:
--   worthy_score, score_composition, score_qpr, score_fit,
--   score_durability, verdict, verification_status, scan_count,
--   community_score, community_votes_count, is_active
-- ============================================================

-- ============================================================
-- calculate_score_inline()
-- Calcola score composizione, QPR, worthy score e verdict
-- senza che il prodotto esista nel database.
-- Usata dal BEFORE INSERT trigger per popolare i campi score.
--
-- TODO post-launch: unificare calculate_score_inline e
-- calculate_worthy_score per eliminare rischio divergenza futura.
-- ============================================================

CREATE OR REPLACE FUNCTION calculate_score_inline(
  p_composition jsonb,
  p_price numeric,
  p_category_id uuid
)
RETURNS TABLE(
  comp_score integer,
  qpr_score integer,
  worthy_score integer,
  final_verdict verdict
)
LANGUAGE plpgsql STABLE
SET search_path = public
AS $$
DECLARE
  v_comp_score integer;
  v_qpr_score integer;
  v_worthy_score integer;
  v_verdict verdict;
  cat_avg_score numeric;
  cat_avg_price numeric;
  raw_qpr numeric;
  raw_score numeric;
BEGIN
  -- Calcola score composizione (riusa la funzione esistente)
  v_comp_score := calculate_composition_score(p_composition);

  -- Calcola QPR inline (senza bisogno del prodotto nel DB)
  SELECT c.avg_composition_score, c.avg_price
  INTO cat_avg_score, cat_avg_price
  FROM categories c
  WHERE c.id = p_category_id;

  IF p_price > 0 AND cat_avg_price > 0 AND cat_avg_score > 0 THEN
    raw_qpr := (v_comp_score::numeric / p_price) / (cat_avg_score / cat_avg_price) * 100;
    v_qpr_score := LEAST(100, GREATEST(0, round(
      100.0 / (1.0 + exp(-0.05 * (raw_qpr - 100.0)))
    )));
  ELSE
    v_qpr_score := 50;
  END IF;

  -- Worthy score: comp*0.7 + qpr*0.3 (nessun mattia_adj per prodotti nuovi)
  raw_score := v_comp_score * 0.7 + v_qpr_score * 0.3;
  v_worthy_score := LEAST(100, GREATEST(0, round(raw_score)));

  -- Verdict
  v_verdict := CASE
    WHEN v_worthy_score >= 86 THEN 'steal'::verdict
    WHEN v_worthy_score >= 71 THEN 'worthy'::verdict
    WHEN v_worthy_score >= 51 THEN 'fair'::verdict
    WHEN v_worthy_score >= 31 THEN 'meh'::verdict
    ELSE 'not_worthy'::verdict
  END;

  comp_score := v_comp_score;
  qpr_score := v_qpr_score;
  worthy_score := v_worthy_score;
  final_verdict := v_verdict;
  RETURN NEXT;
END;
$$;

COMMENT ON FUNCTION calculate_score_inline IS
  'Calcola score composizione, QPR, worthy score e verdict senza bisogno che il prodotto esista nel DB. Usata dal BEFORE INSERT trigger. TODO post-launch: unificare con calculate_worthy_score.';

-- ============================================================
-- protect_product_privileged_fields()
-- BEFORE INSERT OR UPDATE trigger
-- ============================================================

CREATE OR REPLACE FUNCTION protect_product_privileged_fields()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  blocked_fields text[] := '{}';
  acting_user uuid;
  scores record;
BEGIN
  -- Bypass 1: session variable (scoring engine, set da calculate_worthy_score)
  -- Bypass 2: service_role JWT (worthy-admin via PostgREST)
  IF current_setting('worthy.skip_protection', true) = 'true'
     OR is_service_role_or_internal() THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    -- INSERT: forza valori default per campi protetti (silenzioso)
    NEW.verification_status := 'unverified';
    NEW.scan_count := 0;
    NEW.community_score := NULL;
    NEW.community_votes_count := 0;
    NEW.is_active := true;
    NEW.score_fit := NULL;
    NEW.score_durability := NULL;

    -- Calcola score inline da composition/price/category_id
    -- cosi la response INSERT restituisce lo score corretto
    IF NEW.composition IS NOT NULL AND NEW.price IS NOT NULL AND NEW.category_id IS NOT NULL THEN
      SELECT * INTO scores
      FROM calculate_score_inline(NEW.composition, NEW.price, NEW.category_id);

      NEW.score_composition := scores.comp_score;
      NEW.score_qpr := scores.qpr_score;
      NEW.worthy_score := scores.worthy_score;
      NEW.verdict := scores.final_verdict;
    ELSE
      -- Dati incompleti: defaults sicuri
      NEW.score_composition := 0;
      NEW.score_qpr := 0;
      NEW.worthy_score := 0;
      NEW.verdict := 'fair'::verdict;
    END IF;

    RETURN NEW;

  ELSIF TG_OP = 'UPDATE' THEN
    -- UPDATE: verifica se campi protetti sono stati modificati

    IF NEW.worthy_score IS DISTINCT FROM OLD.worthy_score THEN
      blocked_fields := array_append(blocked_fields, 'worthy_score');
    END IF;

    IF NEW.score_composition IS DISTINCT FROM OLD.score_composition THEN
      blocked_fields := array_append(blocked_fields, 'score_composition');
    END IF;

    IF NEW.score_qpr IS DISTINCT FROM OLD.score_qpr THEN
      blocked_fields := array_append(blocked_fields, 'score_qpr');
    END IF;

    IF NEW.score_fit IS DISTINCT FROM OLD.score_fit THEN
      blocked_fields := array_append(blocked_fields, 'score_fit');
    END IF;

    IF NEW.score_durability IS DISTINCT FROM OLD.score_durability THEN
      blocked_fields := array_append(blocked_fields, 'score_durability');
    END IF;

    IF NEW.verdict IS DISTINCT FROM OLD.verdict THEN
      blocked_fields := array_append(blocked_fields, 'verdict');
    END IF;

    IF NEW.verification_status IS DISTINCT FROM OLD.verification_status THEN
      blocked_fields := array_append(blocked_fields, 'verification_status');
    END IF;

    IF NEW.scan_count IS DISTINCT FROM OLD.scan_count THEN
      blocked_fields := array_append(blocked_fields, 'scan_count');
    END IF;

    IF NEW.community_score IS DISTINCT FROM OLD.community_score THEN
      blocked_fields := array_append(blocked_fields, 'community_score');
    END IF;

    IF NEW.community_votes_count IS DISTINCT FROM OLD.community_votes_count THEN
      blocked_fields := array_append(blocked_fields, 'community_votes_count');
    END IF;

    IF NEW.is_active IS DISTINCT FROM OLD.is_active THEN
      blocked_fields := array_append(blocked_fields, 'is_active');
    END IF;

    -- Se nessun campo protetto modificato, UPDATE procede
    IF array_length(blocked_fields, 1) IS NULL THEN
      RETURN NEW;
    END IF;

    -- Log e blocco
    BEGIN
      acting_user := auth.uid();
    EXCEPTION WHEN OTHERS THEN
      acting_user := NULL;
    END;

    PERFORM log_security_event('products', OLD.id, acting_user, blocked_fields);

    RAISE EXCEPTION 'Attempt to modify protected fields: %',
      array_to_string(blocked_fields, ', ')
      USING HINT = 'Score, verification, and is_active fields on products can only be modified by service_role.',
            ERRCODE = '42501';
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION protect_product_privileged_fields IS
  'BEFORE INSERT/UPDATE trigger: su INSERT forza defaults e calcola score inline; su UPDATE blocca modifiche a campi protetti. Bypass via session var worthy.skip_protection o JWT service_role.';

-- Crea il trigger (drop prima per idempotenza)
DROP TRIGGER IF EXISTS trg_products_protect_fields ON products;
CREATE TRIGGER trg_products_protect_fields
  BEFORE INSERT OR UPDATE ON products
  FOR EACH ROW
  EXECUTE FUNCTION protect_product_privileged_fields();

-- ============================================================
-- Ricrea calculate_worthy_score() come SECURITY DEFINER
--
-- SECURITY DEFINER per bypassare RLS sulle query interne.
-- Il bypass del BEFORE trigger protettivo e gestito dalla
-- session variable worthy.skip_protection (NON da SECURITY DEFINER —
-- le GUC di sessione non cambiano con SECURITY DEFINER).
--
-- TODO post-launch: unificare con calculate_score_inline per
-- eliminare rischio divergenza futura.
-- ============================================================

CREATE OR REPLACE FUNCTION calculate_worthy_score(p_product_id uuid)
RETURNS integer
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  comp_score integer;
  qpr_score integer;
  mattia_adj integer;
  raw_score numeric;
  final_score integer;
  final_verdict verdict;
BEGIN
  -- Attiva il bypass del BEFORE trigger protettivo su products.
  -- Il terzo parametro true rende il setting LOCAL alla transazione:
  -- viene resettato automaticamente al commit/rollback.
  PERFORM set_config('worthy.skip_protection', 'true', true);

  -- Calcola score composizione dal JSON
  SELECT calculate_composition_score(p.composition)
  INTO comp_score
  FROM products p
  WHERE p.id = p_product_id;

  -- Aggiorna score_composition prima del calcolo QPR (calculate_qpr lo legge)
  UPDATE products SET score_composition = comp_score WHERE id = p_product_id;

  -- Calcola QPR (formula invariata)
  qpr_score := calculate_qpr(p_product_id);

  -- Recupera mattia adjustment se presente
  SELECT COALESCE(mr.score_adjustment, 0)
  INTO mattia_adj
  FROM products p
  LEFT JOIN mattia_reviews mr ON mr.product_id = p.id
  WHERE p.id = p_product_id;

  IF mattia_adj IS NULL THEN
    mattia_adj := 0;
  END IF;

  -- Formula: comp*0.7 + qpr*0.3 + mattia
  raw_score := comp_score * 0.7 + qpr_score * 0.3 + mattia_adj;
  final_score := LEAST(100, GREATEST(0, round(raw_score)));

  final_verdict := CASE
    WHEN final_score >= 86 THEN 'steal'::verdict
    WHEN final_score >= 71 THEN 'worthy'::verdict
    WHEN final_score >= 51 THEN 'fair'::verdict
    WHEN final_score >= 31 THEN 'meh'::verdict
    ELSE 'not_worthy'::verdict
  END;

  UPDATE products
  SET
    score_composition = comp_score,
    score_qpr = qpr_score,
    score_fit = NULL,
    score_durability = NULL,
    worthy_score = final_score,
    verdict = final_verdict
  WHERE id = p_product_id;

  -- Disattiva il bypass
  PERFORM set_config('worthy.skip_protection', 'false', true);

  RETURN final_score;
END;
$$;

COMMENT ON FUNCTION calculate_worthy_score IS
  'Calcola worthy_score e verdict con formula 70/30 (composition/qpr) + Mattia. SECURITY DEFINER per RLS bypass. Usa session var worthy.skip_protection per bypass del trigger protettivo. TODO post-launch: unificare con calculate_score_inline.';
