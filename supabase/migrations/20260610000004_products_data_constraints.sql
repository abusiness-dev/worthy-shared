-- ════════════════════════════════════════════════════════════════════
-- HARDENING pre-lancio (Wave 1.4) — validazione anti-bypass PostgREST su products /
-- product_reports, via TRIGGER (NON CHECK).
--
-- PROBLEMA:
--   La validazione TS (src/validation/*) gira nel client con anon key ed è
--   bypassabile scrivendo direttamente su PostgREST → dato sporco (composition
--   assurda, name con HTML, prezzo fuori scala, EAN invalido) o EXCEPTION runtime.
--
-- PERCHÉ TRIGGER E NON CHECK (lezione già nel codebase, vedi 20260530000001):
--   Un CHECK constraint viene ri-valutato da Postgres su OGNI UPDATE della riga,
--   anche se la colonna vincolata non cambia. Su dati di PRODUZIONE già esistenti e
--   non conformi (es. un prezzo storico > soglia, una composizione con >8 fibre),
--   QUALSIASI update — incluso il writeback dello scoring engine e gli update dello
--   scraper — fallirebbe. Un trigger BEFORE che bypassa service_role e
--   worthy.skip_protection valida SOLO le scritture client (la vera minaccia) e NON
--   blocca mai gli update interni/scraper di righe storiche.
--
-- ALLINEAMENTO TS: compositionValidation.ts (1-8 fibre, 0<pct<=100, no duplicati,
--   somma 99-101), productValidation.ts (name 3-200, no HTML/URL), barcodeValidation.ts
--   (EAN-13/UPC-A checksum). Cap prezzo DB = 100000 (NON il cap UX €500: lo scraper
--   importa luxury/maison oltre 500€; il bound è solo anti-assurdo per le scritture client).
-- ════════════════════════════════════════════════════════════════════

-- ============================================================
-- 1. EAN/UPC checksum (IMMUTABLE) — mirror di barcodeValidation.ts
-- ============================================================

CREATE OR REPLACE FUNCTION public.is_valid_ean_or_upc(code text)
RETURNS boolean
LANGUAGE plpgsql
IMMUTABLE
SET search_path = public, pg_temp
AS $$
DECLARE
  len  int;
  s    int := 0;
  i    int;
  d    int;
  chk  int;
  comp int;
BEGIN
  IF code IS NULL OR code !~ '^[0-9]+$' THEN
    RETURN false;
  END IF;
  len := length(code);
  IF len NOT IN (12, 13) THEN
    RETURN false;
  END IF;
  chk := substr(code, len, 1)::int;

  IF len = 13 THEN
    -- EAN-13: pesi 1,3 sui primi 12 (mirror eanCheckDigit, index pari→1, dispari→3)
    FOR i IN 1..12 LOOP
      d := substr(code, i, 1)::int;
      s := s + d * (CASE WHEN (i - 1) % 2 = 0 THEN 1 ELSE 3 END);
    END LOOP;
  ELSE
    -- UPC-A: pesi 3,1 sui primi 11 (mirror isValidUPC, index pari→3, dispari→1)
    FOR i IN 1..11 LOOP
      d := substr(code, i, 1)::int;
      s := s + d * (CASE WHEN (i - 1) % 2 = 0 THEN 3 ELSE 1 END);
    END LOOP;
  END IF;

  comp := (10 - (s % 10)) % 10;
  RETURN comp = chk;
END;
$$;

COMMENT ON FUNCTION public.is_valid_ean_or_upc IS
  'true se code è un EAN-13 o UPC-A con check digit valido. Mirror di src/validation/barcodeValidation.ts.';

-- ============================================================
-- 2. Trigger BEFORE su products: name + composition + price + EAN
--    Bypass: scoring engine (worthy.skip_protection) e service_role/admin (scraper).
-- ============================================================

CREATE OR REPLACE FUNCTION public.validate_product_content()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  total_pct  numeric;
  n_elems    int;
  n_distinct int;
  bad_pct    int;
  bad_fiber  int;
  e          text;
BEGIN
  -- Bypass: scoring engine (session var) e service_role/admin (scraper).
  IF current_setting('worthy.skip_protection', true) = 'true'
     OR is_service_role_or_internal() THEN
    RETURN NEW;
  END IF;

  -- name: lunghezza 3-200, no tag HTML, no URL.
  IF char_length(btrim(NEW.name)) < 3 OR char_length(btrim(NEW.name)) > 200 THEN
    RAISE EXCEPTION 'name non valido: lunghezza ammessa 3-200 caratteri' USING ERRCODE = '23514';
  END IF;
  IF NEW.name ~ '<[^>]+>' THEN
    RAISE EXCEPTION 'name non valido: i tag HTML non sono ammessi' USING ERRCODE = '23514';
  END IF;
  IF NEW.name ~* 'https?://' THEN
    RAISE EXCEPTION 'name non valido: non può contenere URL' USING ERRCODE = '23514';
  END IF;

  -- price: > 0 (ridondante col CHECK products_price_positive) e <= 100000 anti-assurdo.
  IF NEW.price IS NULL OR NEW.price <= 0 OR NEW.price > 100000 THEN
    RAISE EXCEPTION 'price non valido: deve essere tra 0 (escluso) e 100000' USING ERRCODE = '23514';
  END IF;

  -- composition: array di 1..8 elementi.
  IF jsonb_typeof(NEW.composition) <> 'array' OR jsonb_array_length(NEW.composition) = 0 THEN
    RAISE EXCEPTION 'composition non valida: deve essere un array non vuoto' USING ERRCODE = '23514';
  END IF;
  IF jsonb_array_length(NEW.composition) > 8 THEN
    RAISE EXCEPTION 'composition non valida: massimo 8 fibre' USING ERRCODE = '23514';
  END IF;

  -- Ogni percentage deve essere un NUMERO JSON (evita il fallimento del cast sotto).
  IF EXISTS (
    SELECT 1 FROM jsonb_array_elements(NEW.composition) AS el(value)
    WHERE jsonb_typeof(el.value -> 'percentage') <> 'number'
  ) THEN
    RAISE EXCEPTION 'composition non valida: ogni fibra deve avere una percentage numerica'
      USING ERRCODE = '23514';
  END IF;

  -- Aggregazione set-based: range percentuali, fibre vuote, somma, duplicati.
  SELECT
    count(*) FILTER (WHERE (el.value ->> 'percentage')::numeric <= 0
                        OR (el.value ->> 'percentage')::numeric > 100),
    count(*) FILTER (WHERE coalesce(btrim(el.value ->> 'fiber'), '') = ''),
    coalesce(sum((el.value ->> 'percentage')::numeric), 0),
    count(DISTINCT lower(btrim(el.value ->> 'fiber'))),
    count(*)
  INTO bad_pct, bad_fiber, total_pct, n_distinct, n_elems
  FROM jsonb_array_elements(NEW.composition) AS el(value);

  IF bad_pct > 0 THEN
    RAISE EXCEPTION 'composition non valida: ogni percentage deve essere tra 0 (escluso) e 100'
      USING ERRCODE = '23514';
  END IF;
  IF bad_fiber > 0 THEN
    RAISE EXCEPTION 'composition non valida: ogni fibra deve avere un nome' USING ERRCODE = '23514';
  END IF;
  IF n_distinct <> n_elems THEN
    RAISE EXCEPTION 'composition non valida: contiene fibre duplicate' USING ERRCODE = '23514';
  END IF;
  IF total_pct < 99 OR total_pct > 101 THEN
    RAISE EXCEPTION 'composition non valida: la somma delle percentuali deve essere ~100%% (attuale: %)', total_pct
      USING ERRCODE = '23514';
  END IF;

  -- ean_barcode: formato + checksum (is_valid_ean_or_upc copre entrambi).
  IF NEW.ean_barcode IS NOT NULL AND NOT is_valid_ean_or_upc(NEW.ean_barcode) THEN
    RAISE EXCEPTION 'ean_barcode non valido: deve essere EAN-13/UPC-A con check digit corretto'
      USING ERRCODE = '23514';
  END IF;

  -- additional_eans: ogni elemento deve essere un EAN/UPC valido.
  IF NEW.additional_eans IS NOT NULL THEN
    FOREACH e IN ARRAY NEW.additional_eans LOOP
      IF e IS NOT NULL AND btrim(e) <> '' AND NOT is_valid_ean_or_upc(e) THEN
        RAISE EXCEPTION 'additional_eans contiene un codice non valido: %', e USING ERRCODE = '23514';
      END IF;
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.validate_product_content IS
  'BEFORE INSERT/UPDATE su products: valida name (3-200, no HTML/URL), price (0<p<=100000), composition (1-8 fibre, somma ~100, no duplicati, percentuali valide) ed EAN (checksum) per le scritture client. Bypass via worthy.skip_protection o JWT service_role → non blocca mai scoring engine e scraper né le righe storiche. Allineato a src/validation/*.';

DROP TRIGGER IF EXISTS trg_products_validate_content ON public.products;
CREATE TRIGGER trg_products_validate_content
  BEFORE INSERT OR UPDATE ON public.products
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_product_content();

-- ============================================================
-- 3. product_reports.description: cap lunghezza via trigger (client-only)
-- ============================================================

CREATE OR REPLACE FUNCTION public.validate_report_content()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
  IF is_service_role_or_internal() THEN
    RETURN NEW;
  END IF;
  IF NEW.description IS NOT NULL AND char_length(NEW.description) > 1000 THEN
    RAISE EXCEPTION 'description troppo lunga: massimo 1000 caratteri' USING ERRCODE = '23514';
  END IF;
  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.validate_report_content IS
  'BEFORE INSERT su product_reports: cap description a 1000 caratteri per le scritture client (bypass service_role).';

DROP TRIGGER IF EXISTS trg_product_reports_validate_content ON public.product_reports;
CREATE TRIGGER trg_product_reports_validate_content
  BEFORE INSERT ON public.product_reports
  FOR EACH ROW
  EXECUTE FUNCTION public.validate_report_content();

-- ============================================================
-- NOTA: price_history NON ha vincoli aggiunti — è scrivibile solo da service_role
-- (REVOKE da anon/authenticated in 20260417000006), quindi nessuna superficie di
-- bypass client. I CHECK declarativi sono volutamente EVITATI (vedi intestazione).
-- ============================================================
