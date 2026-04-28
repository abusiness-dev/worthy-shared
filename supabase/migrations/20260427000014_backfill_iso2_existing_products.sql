-- Worthy Score v2 - Backfill country_of_production_iso2 + step iso2 sui
-- prodotti esistenti.
--
-- I 718 prodotti già nel DB hanno country_of_production come stringa libera
-- ("Italy", "Made in China", "Italia", ...) ma NON hanno
-- country_of_production_iso2 valorizzato. Senza ISO2 la manufacturing_lens
-- è null per tutti loro → confidence v2 ridotta.
--
-- Questa migration:
--   1. Crea normalize_country_to_iso2(text) che replica country-normalizer.ts
--   2. Backfilla i 4 campi *_iso2 dai text esistenti
--   3. Ricalcola v2 sui prodotti affected (ora la manufacturing_lens contribuisce)
--
-- Idempotente: ri-eseguire popola solo i campi ancora null.

-- ============================================================
-- Funzione di normalizzazione paese → ISO2
-- ============================================================

CREATE OR REPLACE FUNCTION normalize_country_to_iso2(raw text)
RETURNS char(2)
LANGUAGE plpgsql IMMUTABLE
AS $$
DECLARE
  cleaned text;
  stripped text;
BEGIN
  IF raw IS NULL OR length(trim(raw)) = 0 THEN
    RETURN NULL;
  END IF;

  -- Normalizza: lower, rimuove punteggiatura, collassa spazi.
  -- Le emoji bandiere non sono presenti nei country_of_production scrapati,
  -- quindi non serve un filtro Unicode dedicato.
  cleaned := lower(raw);
  cleaned := regexp_replace(cleaned, '[.,;:!?(){}"]+', ' ', 'g');
  cleaned := regexp_replace(cleaned, '[\[\]]+', ' ', 'g');
  cleaned := regexp_replace(cleaned, '\s+', ' ', 'g');
  cleaned := trim(cleaned);

  IF cleaned = '' THEN RETURN NULL; END IF;

  -- Rimuove prefissi comuni
  stripped := regexp_replace(cleaned, '^(made in |prodotto in |fatto in |origin |origine |country of origin |country |paese )', '', 'i');
  stripped := trim(stripped);

  -- Match diretto (prima sulla stringa pulita, poi senza prefissi)
  RETURN CASE
    WHEN cleaned IN ('italia','italy','italie','italian','made in italy','fatto in italia','prodotto in italia') OR stripped IN ('italia','italy','italie','italian') OR cleaned LIKE '%italy%' OR cleaned LIKE '%italia%' THEN 'IT'
    WHEN cleaned IN ('giappone','japan','made in japan')        OR stripped IN ('giappone','japan')        OR cleaned LIKE '%japan%'      THEN 'JP'
    WHEN cleaned IN ('svizzera','switzerland','suisse')          OR stripped IN ('svizzera','switzerland','suisse') OR cleaned LIKE '%switzerland%' THEN 'CH'
    WHEN cleaned IN ('germania','germany','deutschland','made in germany') OR stripped IN ('germania','germany','deutschland') OR cleaned LIKE '%germany%' THEN 'DE'
    WHEN cleaned IN ('portogallo','portugal','made in portugal') OR stripped IN ('portogallo','portugal') OR cleaned LIKE '%portugal%' THEN 'PT'
    WHEN cleaned IN ('austria')                                  OR stripped IN ('austria')                                              THEN 'AT'
    WHEN cleaned IN ('francia','france','made in france','francaise') OR stripped IN ('francia','france','francaise') OR cleaned LIKE '%france%' THEN 'FR'
    WHEN cleaned IN ('belgio','belgium','belgique')              OR stripped IN ('belgio','belgium','belgique')                          THEN 'BE'
    WHEN cleaned IN ('paesi bassi','olanda','netherlands','holland') OR stripped IN ('paesi bassi','olanda','netherlands','holland')     THEN 'NL'
    WHEN cleaned IN ('regno unito','united kingdom','uk','britain','england','inghilterra','made in britain') OR stripped IN ('regno unito','united kingdom','uk','britain','england','inghilterra') OR cleaned LIKE '%united kingdom%' OR cleaned LIKE '%england%' THEN 'GB'
    WHEN cleaned IN ('stati uniti','united states','usa','u.s.a.','america','made in usa') OR stripped IN ('stati uniti','united states','usa','u.s.a.','america') OR cleaned LIKE '%united states%' OR cleaned LIKE '%u s a %' THEN 'US'
    WHEN cleaned IN ('spagna','spain','españa','espana','made in spain') OR stripped IN ('spagna','spain','españa','espana') OR cleaned LIKE '%spain%' OR cleaned LIKE '%spagna%' THEN 'ES'
    WHEN cleaned IN ('danimarca','denmark')                      OR stripped IN ('danimarca','denmark')                                  THEN 'DK'
    WHEN cleaned IN ('svezia','sweden')                          OR stripped IN ('svezia','sweden')                                      THEN 'SE'
    WHEN cleaned IN ('norvegia','norway')                        OR stripped IN ('norvegia','norway')                                    THEN 'NO'
    WHEN cleaned IN ('finlandia','finland')                      OR stripped IN ('finlandia','finland')                                  THEN 'FI'
    WHEN cleaned IN ('corea del sud','south korea','korea')      OR stripped IN ('corea del sud','south korea','korea')                  THEN 'KR'
    WHEN cleaned IN ('turchia','turkey','türkiye','turkiye','made in turkey') OR stripped IN ('turchia','turkey','türkiye','turkiye') OR cleaned LIKE '%turkey%' OR cleaned LIKE '%turchia%' THEN 'TR'
    WHEN cleaned IN ('romania')                                  OR stripped IN ('romania')                                              THEN 'RO'
    WHEN cleaned IN ('ungheria','hungary')                       OR stripped IN ('ungheria','hungary')                                   THEN 'HU'
    WHEN cleaned IN ('repubblica ceca','czech republic','cechia') OR stripped IN ('repubblica ceca','czech republic','cechia')           THEN 'CZ'
    WHEN cleaned IN ('polonia','poland')                         OR stripped IN ('polonia','poland')                                     THEN 'PL'
    WHEN cleaned IN ('taiwan')                                   OR stripped IN ('taiwan')                                               THEN 'TW'
    WHEN cleaned IN ('bulgaria')                                 OR stripped IN ('bulgaria')                                             THEN 'BG'
    WHEN cleaned IN ('vietnam','viet nam','made in vietnam')     OR stripped IN ('vietnam','viet nam') OR cleaned LIKE '%vietnam%'       THEN 'VN'
    WHEN cleaned IN ('cina','china','made in china','p.r.c.')    OR stripped IN ('cina','china','p.r.c.') OR cleaned LIKE '%china%' OR cleaned LIKE '%cina%' THEN 'CN'
    WHEN cleaned IN ('thailandia','thailand')                    OR stripped IN ('thailandia','thailand')                                THEN 'TH'
    WHEN cleaned IN ('india','made in india')                    OR stripped IN ('india')                  OR cleaned LIKE '%india%'    THEN 'IN'
    WHEN cleaned IN ('messico','mexico')                         OR stripped IN ('messico','mexico')                                     THEN 'MX'
    WHEN cleaned IN ('brasile','brazil','brasil')                OR stripped IN ('brasile','brazil','brasil')                            THEN 'BR'
    WHEN cleaned IN ('israele','israel')                         OR stripped IN ('israele','israel')                                     THEN 'IL'
    WHEN cleaned IN ('tunisia')                                  OR stripped IN ('tunisia')                                              THEN 'TN'
    WHEN cleaned IN ('egitto','egypt')                           OR stripped IN ('egitto','egypt')                                       THEN 'EG'
    WHEN cleaned IN ('pakistan')                                 OR stripped IN ('pakistan')                                             THEN 'PK'
    WHEN cleaned IN ('malesia','malaysia')                       OR stripped IN ('malesia','malaysia')                                   THEN 'MY'
    WHEN cleaned IN ('indonesia')                                OR stripped IN ('indonesia')                                            THEN 'ID'
    WHEN cleaned IN ('marocco','morocco','maroc')                OR stripped IN ('marocco','morocco','maroc')                            THEN 'MA'
    WHEN cleaned IN ('iran')                                     OR stripped IN ('iran')                                                 THEN 'IR'
    WHEN cleaned IN ('kazakistan','kazakhstan')                  OR stripped IN ('kazakistan','kazakhstan')                              THEN 'KZ'
    WHEN cleaned IN ('sri lanka','srilanka')                     OR stripped IN ('sri lanka','srilanka')                                 THEN 'LK'
    WHEN cleaned IN ('filippine','philippines')                  OR stripped IN ('filippine','philippines')                              THEN 'PH'
    WHEN cleaned IN ('bangladesh','made in bangladesh')          OR stripped IN ('bangladesh') OR cleaned LIKE '%bangladesh%'            THEN 'BD'
    WHEN cleaned IN ('nepal')                                    OR stripped IN ('nepal')                                                THEN 'NP'
    WHEN cleaned IN ('cambogia','cambodia')                      OR stripped IN ('cambogia','cambodia')                                  THEN 'KH'
    WHEN cleaned IN ('etiopia','ethiopia')                       OR stripped IN ('etiopia','ethiopia')                                   THEN 'ET'
    WHEN cleaned IN ('haiti')                                    OR stripped IN ('haiti')                                                THEN 'HT'
    WHEN cleaned IN ('myanmar','birmania','burma')               OR stripped IN ('myanmar','birmania','burma')                           THEN 'MM'
    WHEN cleaned IN ('australia')                                OR stripped IN ('australia')                                            THEN 'AU'
    WHEN cleaned IN ('nuova zelanda','new zealand')              OR stripped IN ('nuova zelanda','new zealand')                          THEN 'NZ'
    WHEN cleaned IN ('mongolia')                                 OR stripped IN ('mongolia')                                             THEN 'MN'
    WHEN cleaned IN ('antigua e barbuda','antigua')              OR stripped IN ('antigua e barbuda','antigua')                          THEN 'AG'
    WHEN cleaned IN ('afghanistan')                              OR stripped IN ('afghanistan')                                          THEN 'AF'
    WHEN cleaned IN ('perù','peru')                              OR stripped IN ('perù','peru')                                          THEN 'PE'
    ELSE NULL
  END;
END;
$$;

COMMENT ON FUNCTION normalize_country_to_iso2 IS
  'Normalizza una stringa libera di paese in codice ISO 3166-1 alpha-2. Replica country-normalizer.ts dello scraper. Ritorna NULL se non riconoscibile.';

-- ============================================================
-- Backfill: popola i 4 campi *_iso2 dai text esistenti.
-- Solo dove iso2 è ancora NULL (idempotente, sicuro su rerun).
-- ============================================================

UPDATE products
SET
  country_of_production_iso2 = normalize_country_to_iso2(country_of_production)
WHERE country_of_production_iso2 IS NULL AND country_of_production IS NOT NULL;

UPDATE products
SET
  spinning_iso2 = normalize_country_to_iso2(spinning_location)
WHERE spinning_iso2 IS NULL AND spinning_location IS NOT NULL;

UPDATE products
SET
  weaving_iso2 = normalize_country_to_iso2(weaving_location)
WHERE weaving_iso2 IS NULL AND weaving_location IS NOT NULL;

UPDATE products
SET
  dyeing_iso2 = normalize_country_to_iso2(dyeing_location)
WHERE dyeing_iso2 IS NULL AND dyeing_location IS NOT NULL;

-- ============================================================
-- Ricalcolo v2 sui prodotti che ora hanno almeno uno step manifattura
-- valorizzato (la manufacturing_lens ora contribuisce).
-- ============================================================

DO $$
DECLARE
  r record;
  n integer := 0;
BEGIN
  FOR r IN
    SELECT id FROM products
    WHERE is_active = true AND (
      country_of_production_iso2 IS NOT NULL
      OR spinning_iso2 IS NOT NULL
      OR weaving_iso2 IS NOT NULL
      OR dyeing_iso2 IS NOT NULL
    )
  LOOP
    PERFORM calculate_worthy_score_v2(r.id);
    n := n + 1;
  END LOOP;

  RAISE NOTICE 'Backfill ISO2 completato: % prodotti con manifattura valorizzata e ricalcolati', n;
END $$;
