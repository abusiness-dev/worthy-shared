-- ============================================================
-- SECURITY FIX (F2): validazione lato DB di affiliate_url, photo_urls,
-- label_photo_url su products.
--
-- PROBLEMA:
--   Le policy products_insert_auth / products_update_own_recent permettono a un
--   utente authenticated di inserire/aggiornare prodotti propri con valori
--   arbitrari per affiliate_url / photo_urls / label_photo_url. La validazione
--   TypeScript (src/validation) gira nel client con anon key e NON è una
--   barriera: la anon key può scrivere direttamente su PostgREST bypassandola.
--   Un affiliate_url malevolo (javascript:, data:, phishing su http) renderizzato
--   o aperto dai client = XSS/open-redirect/phishing verso altri utenti.
--
-- SOLUZIONE:
--   Trigger BEFORE INSERT/UPDATE (NON un CHECK constraint): valida solo le righe
--   scritte e NON fallisce su eventuali righe storiche non conformi. I soli URL
--   ammessi dai client sono https://. Le scritture interne (scoring engine via
--   worthy.skip_protection) e service_role (scraper/admin, che inseriscono URL
--   CDN legittimi) bypassano la validazione — stesso pattern di
--   protect_product_privileged_fields (20260417000003).
--
-- ALLINEAMENTO TS: src/validation/urlValidation.ts (isSafeHttpsUrl,
--   validateAffiliateUrl, validatePhotoUrls) replica questa logica lato client.
--
-- PRE-CHECK CONSIGLIATO prima del deploy (verifica che non rompa nulla):
--   SELECT id, affiliate_url FROM products
--     WHERE affiliate_url IS NOT NULL AND affiliate_url !~* '^https://[^[:space:]]+$';
--   SELECT id, u FROM products, unnest(photo_urls) AS u
--     WHERE u IS NOT NULL AND u <> '' AND u !~* '^https://[^[:space:]]+$';
--   (Le righe scritte da service_role/scraper non sono soggette al trigger, ma
--    eventuali URL non-https andrebbero comunque bonificati.)
-- ============================================================

CREATE OR REPLACE FUNCTION validate_product_urls()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
DECLARE
  u text;
  https_re constant text := '^https://[^[:space:]]+$';
BEGIN
  -- Bypass: scoring engine (session var) e service_role/admin (scraper).
  IF current_setting('worthy.skip_protection', true) = 'true'
     OR is_service_role_or_internal() THEN
    RETURN NEW;
  END IF;

  -- affiliate_url (opzionale): solo https:// — blocca javascript:, data:, http:, ecc.
  IF NEW.affiliate_url IS NOT NULL AND btrim(NEW.affiliate_url) <> '' THEN
    IF NEW.affiliate_url !~* https_re THEN
      RAISE EXCEPTION 'affiliate_url non valido: sono ammessi solo URL https://'
        USING ERRCODE = '23514'; -- check_violation
    END IF;
  END IF;

  -- label_photo_url (opzionale): solo https://
  IF NEW.label_photo_url IS NOT NULL AND btrim(NEW.label_photo_url) <> '' THEN
    IF NEW.label_photo_url !~* https_re THEN
      RAISE EXCEPTION 'label_photo_url non valido: sono ammessi solo URL https://'
        USING ERRCODE = '23514';
    END IF;
  END IF;

  -- photo_urls: ogni elemento non vuoto deve essere https://
  IF NEW.photo_urls IS NOT NULL THEN
    FOREACH u IN ARRAY NEW.photo_urls LOOP
      IF u IS NOT NULL AND btrim(u) <> '' AND u !~* https_re THEN
        RAISE EXCEPTION 'photo_urls contiene un URL non valido (ammessi solo https://): %', u
          USING ERRCODE = '23514';
      END IF;
    END LOOP;
  END IF;

  RETURN NEW;
END;
$$;

COMMENT ON FUNCTION validate_product_urls IS
  'BEFORE INSERT/UPDATE su products: impone affiliate_url/photo_urls/label_photo_url = solo https:// per scritture client. Bypass via session var worthy.skip_protection o JWT service_role. Allineato a src/validation/urlValidation.ts.';

DROP TRIGGER IF EXISTS trg_products_validate_urls ON products;
CREATE TRIGGER trg_products_validate_urls
  BEFORE INSERT OR UPDATE ON products
  FOR EACH ROW
  EXECUTE FUNCTION validate_product_urls();
