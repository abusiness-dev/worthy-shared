-- Worthy Score - Estende il trigger di scoring per il dual-write v2.
--
-- Ad ogni INSERT/UPDATE rilevante su products, oltre a calculate_worthy_score
-- (v1) viene chiamato anche calculate_worthy_score_v2 in shadow per popolare
-- score_breakdown e i sub-score della v2.
--
-- L'errore di v2 NON deve bloccare l'INSERT del prodotto (la v2 ha più
-- dipendenze: lookup mancanti, dati incompleti). Per questo la chiamata è
-- avvolta in BEGIN/EXCEPTION/WARNING.

CREATE OR REPLACE FUNCTION trigger_calculate_worthy_score()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  IF TG_OP = 'INSERT' OR
     OLD.composition IS DISTINCT FROM NEW.composition OR
     OLD.price IS DISTINCT FROM NEW.price OR
     OLD.category_id IS DISTINCT FROM NEW.category_id
  THEN
    -- v1: calcolo principale (worthy_score visibile in app)
    PERFORM calculate_worthy_score(NEW.id);

    -- v2: dual-write shadow su score_breakdown.
    -- Errori v2 non devono interrompere l'INSERT/UPDATE del prodotto.
    BEGIN
      PERFORM calculate_worthy_score_v2(NEW.id);
    EXCEPTION WHEN OTHERS THEN
      RAISE WARNING 'calculate_worthy_score_v2 failed for product %: %', NEW.id, SQLERRM;
    END;
  END IF;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION trigger_calculate_worthy_score IS
  'Trigger di scoring: chiama v1 (canonico) + v2 (shadow) ad ogni cambio rilevante. Errori v2 emettono WARNING ma non bloccano l''operazione.';

-- Aggiungo anche un trigger sui link tables v2 perché un cambio di
-- product_fiber_origins / product_technologies / product_certifications
-- deve riflettersi nello score_breakdown.

CREATE OR REPLACE FUNCTION trigger_recalc_v2_on_link_change()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  target_product_id uuid;
BEGIN
  IF TG_OP = 'DELETE' THEN
    target_product_id := OLD.product_id;
  ELSE
    target_product_id := NEW.product_id;
  END IF;

  BEGIN
    PERFORM calculate_worthy_score_v2(target_product_id);
  EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'calculate_worthy_score_v2 failed on link change for product %: %', target_product_id, SQLERRM;
  END;

  IF TG_OP = 'DELETE' THEN
    RETURN OLD;
  END IF;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION trigger_recalc_v2_on_link_change IS
  'Ricalcola worthy_score_v2 in shadow quando vengono inseriti/modificati/rimossi product_fiber_origins, product_technologies o product_certifications.';

DROP TRIGGER IF EXISTS trg_pfo_recalc_v2 ON product_fiber_origins;
CREATE TRIGGER trg_pfo_recalc_v2
  AFTER INSERT OR UPDATE OR DELETE ON product_fiber_origins
  FOR EACH ROW EXECUTE FUNCTION trigger_recalc_v2_on_link_change();

DROP TRIGGER IF EXISTS trg_pt_recalc_v2 ON product_technologies;
CREATE TRIGGER trg_pt_recalc_v2
  AFTER INSERT OR UPDATE OR DELETE ON product_technologies
  FOR EACH ROW EXECUTE FUNCTION trigger_recalc_v2_on_link_change();

DROP TRIGGER IF EXISTS trg_pc_recalc_v2 ON product_certifications;
CREATE TRIGGER trg_pc_recalc_v2
  AFTER INSERT OR UPDATE OR DELETE ON product_certifications
  FOR EACH ROW EXECUTE FUNCTION trigger_recalc_v2_on_link_change();
