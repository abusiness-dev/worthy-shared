-- Worthy Score v2 - Estende la protezione del trigger
-- protect_product_privileged_fields ai nuovi sub-score introdotti da v2.
--
-- Senza questa estensione un utente con UPDATE su products potrebbe falsificare
-- score_origin, score_manufacturing, score_technical, score_sustainability,
-- score_confidence, score_breakdown bypassando il calcolo legittimo.
--
-- I nuovi campi sono modificabili solo via:
--   - calculate_worthy_score_v2 (SECURITY DEFINER + skip_protection)
--   - service_role JWT (worthy-admin via PostgREST)
--
-- La logica del trigger è invariata; aggiunge solo i check sui nuovi campi.

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
  -- Bypass 1: session variable (scoring engine)
  -- Bypass 2: service_role JWT
  IF current_setting('worthy.skip_protection', true) = 'true'
     OR is_service_role_or_internal() THEN
    RETURN NEW;
  END IF;

  IF TG_OP = 'INSERT' THEN
    -- INSERT: forza valori default per campi protetti
    NEW.verification_status := 'unverified';
    NEW.scan_count := 0;
    NEW.community_score := NULL;
    NEW.community_votes_count := 0;
    NEW.is_active := true;
    NEW.score_fit := NULL;
    NEW.score_durability := NULL;

    -- v2: i sub-score nuovi sono NULL all'INSERT (saranno popolati al primo
    -- calculate_worthy_score_v2 in shadow durante F3)
    NEW.score_origin         := NULL;
    NEW.score_manufacturing  := NULL;
    NEW.score_technical      := NULL;
    NEW.score_sustainability := NULL;
    NEW.score_confidence     := NULL;
    NEW.score_breakdown      := NULL;

    -- Calcola score v1 inline da composition/price/category_id
    IF NEW.composition IS NOT NULL AND NEW.price IS NOT NULL AND NEW.category_id IS NOT NULL THEN
      SELECT * INTO scores
      FROM calculate_score_inline(NEW.composition, NEW.price, NEW.category_id);

      NEW.score_composition := scores.comp_score;
      NEW.score_qpr := scores.qpr_score;
      NEW.worthy_score := scores.worthy_score;
      NEW.verdict := scores.final_verdict;
    ELSE
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

    -- v2 sub-score: protetti come gli score v1
    IF NEW.score_origin IS DISTINCT FROM OLD.score_origin THEN
      blocked_fields := array_append(blocked_fields, 'score_origin');
    END IF;
    IF NEW.score_manufacturing IS DISTINCT FROM OLD.score_manufacturing THEN
      blocked_fields := array_append(blocked_fields, 'score_manufacturing');
    END IF;
    IF NEW.score_technical IS DISTINCT FROM OLD.score_technical THEN
      blocked_fields := array_append(blocked_fields, 'score_technical');
    END IF;
    IF NEW.score_sustainability IS DISTINCT FROM OLD.score_sustainability THEN
      blocked_fields := array_append(blocked_fields, 'score_sustainability');
    END IF;
    IF NEW.score_confidence IS DISTINCT FROM OLD.score_confidence THEN
      blocked_fields := array_append(blocked_fields, 'score_confidence');
    END IF;
    IF NEW.score_breakdown IS DISTINCT FROM OLD.score_breakdown THEN
      blocked_fields := array_append(blocked_fields, 'score_breakdown');
    END IF;

    -- Se nessun campo protetto modificato, UPDATE procede
    IF array_length(blocked_fields, 1) IS NULL THEN
      RETURN NEW;
    END IF;

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
  'BEFORE INSERT/UPDATE trigger: forza defaults su INSERT (incluso azzeramento v2 sub-score), blocca UPDATE su tutti i campi score (v1 + v2). Bypass via session var worthy.skip_protection o JWT service_role.';
