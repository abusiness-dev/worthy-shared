-- ════════════════════════════════════════════════════════════════════
-- HARDENING pre-lancio (Wave 2.1/2.2) — riduce la write-amplification dello scoring.
--
-- PROBLEMA:
--   1) trigger_calculate_worthy_score (20260530000003) chiama calculate_worthy_score
--      (che è già un WRAPPER su calculate_worthy_score_v2, vedi 20260427000015) E POI
--      di nuovo calculate_worthy_score_v2 come "dual-write shadow" → v2 girava DUE
--      volte per ogni scrittura rilevante di products.
--   2) trigger_audit_log (20260417000004) logga to_jsonb(OLD)+to_jsonb(NEW) interi su
--      OGNI UPDATE di products, inclusi i 2-3 UPDATE INTERNI di writeback dello scoring
--      → 3-5 righe audit_log (con 2 snapshot jsonb della riga) per singola modifica
--      logica di prodotto.
--
-- SOLUZIONE:
--   1) trigger_calculate_worthy_score chiama SOLO calculate_worthy_score (che già
--      delega a v2 e ne persiste il breakdown). Nessun cambio di semantica: la
--      catena di fallimento è identica (il wrapper già poteva fallire).
--   2) trigger_audit_log SALTA gli UPDATE su products eseguiti DURANTE lo scoring
--      (lo scoring engine setta worthy.skip_protection='true' nei suoi writeback,
--      vedi 20260427000015:36/49 e 20260518000001:321). Resta loggata la scrittura
--      UTENTE originale (skip_protection='false' a quel punto) e l'audit di
--      brands/users è invariato.
--
-- VALIDARE: un UPDATE products che cambia composition deve produrre 1 SOLA riga
--   audit_log (azione 'update' dell'utente) invece di 3-4.
-- ════════════════════════════════════════════════════════════════════

-- 1. Dedup: una sola esecuzione di v2 per scrittura (via il wrapper canonico).
CREATE OR REPLACE FUNCTION trigger_calculate_worthy_score()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF TG_OP = 'INSERT' OR
     OLD.composition IS DISTINCT FROM NEW.composition OR
     OLD.price IS DISTINCT FROM NEW.price OR
     OLD.category_id IS DISTINCT FROM NEW.category_id
  THEN
    -- calculate_worthy_score è il wrapper canonico (20260427000015): chiama
    -- internamente calculate_worthy_score_v2 e persiste il breakdown. La seconda
    -- chiamata diretta a _v2 (dual-write storico) era pura ridondanza → rimossa.
    PERFORM calculate_worthy_score(NEW.id);
  END IF;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION trigger_calculate_worthy_score IS
  'Trigger di scoring. Chiama il wrapper canonico calculate_worthy_score (che delega a v2 e persiste il breakdown). SECURITY DEFINER: la catena gira come owner, indipendente dai GRANT EXECUTE (F8). Dedup della doppia chiamata v2 (Wave 2.1).';

-- 2. Audit guard: salta gli UPDATE interni dello scoring su products.
CREATE OR REPLACE FUNCTION trigger_audit_log()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  record_uuid uuid;
  old_json jsonb;
  new_json jsonb;
  action_type audit_action;
  acting_user uuid;
BEGIN
  -- Anti-amplificazione: gli UPDATE di writeback dello scoring (worthy_score,
  -- score_*) girano con worthy.skip_protection='true'. Non li auditiamo: la
  -- scrittura UTENTE che li ha innescati è già loggata a monte. Solo per products
  -- e solo su UPDATE (INSERT/DELETE restano sempre loggati).
  IF TG_TABLE_NAME = 'products'
     AND TG_OP = 'UPDATE'
     AND current_setting('worthy.skip_protection', true) = 'true' THEN
    RETURN NEW;
  END IF;

  action_type := lower(TG_OP)::audit_action;

  IF TG_OP = 'DELETE' THEN
    record_uuid := OLD.id;
    old_json := to_jsonb(OLD);
    new_json := NULL;
  ELSIF TG_OP = 'INSERT' THEN
    record_uuid := NEW.id;
    old_json := NULL;
    new_json := to_jsonb(NEW);
  ELSE
    record_uuid := NEW.id;
    old_json := to_jsonb(OLD);
    new_json := to_jsonb(NEW);
  END IF;

  BEGIN
    acting_user := auth.uid();
  EXCEPTION WHEN OTHERS THEN
    acting_user := NULL;
  END;

  INSERT INTO audit_log (table_name, record_id, action, user_id, old_data, new_data)
  VALUES (TG_TABLE_NAME, record_uuid, action_type, acting_user, old_json, new_json);

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION trigger_audit_log IS
  'Audit log append-only. Salta gli UPDATE interni dello scoring su products (worthy.skip_protection) per evitare la write-amplification 3-5x (Wave 2.2). SECURITY DEFINER + search_path fisso.';
