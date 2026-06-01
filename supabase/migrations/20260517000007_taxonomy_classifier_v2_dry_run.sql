-- Cleanup taxonomy — STEP 2: classificatore v2, dry-run.
--
-- Il classifier v1 (20260517000006) ha mostrato problemi:
--   1. "jeans/denim" troppo aggressivo: ruba "Camicia in denim",
--      "Giacca di jeans", "Gonna midi in denim", "Bermuda denim" che
--      LEGITTIMAMENTE appartengono a camicia/giacca/gonna/shorts.
--   2. Match polo/t-shirt prima di vestito/abito: "Abito polo Lacoste"
--      (vestito Lacoste con scollo a polo) veniva spostato a polo.
--   3. Riassegnamenti intra-famiglia: t-shirt-basic ↔ t-shirt,
--      felpa-girocollo ↔ felpe, jeans-regular ↔ jeans erano proposti come
--      riassegnamenti, ma sono solo sotto-categorie della stessa famiglia.
--
-- Fix nel v2:
--   - Outerwear (cappotti/trench/giubbotti/blazer/giacche) classificato
--     PRIMA degli inner perché può contenere keyword di sotto-strati.
--   - Vestito/abito classificati PRIMA di polo/t-shirt.
--   - Jeans/denim spostato in fondo: matcha solo se nessun'altra categoria
--     matcha.
--   - Aggiunta funzione category_family(slug) per evitare riassegnamenti
--     intra-famiglia (es. t-shirt-basic NON riassegnato a t-shirt).
--
-- Continua a essere un DRY-RUN: nessun UPDATE. Lo step 3 applicherà.

-- ============================================================
-- 1. category_family: raggruppa sotto-categorie equivalenti
-- ============================================================

CREATE OR REPLACE FUNCTION category_family(p_slug text)
RETURNS text
LANGUAGE plpgsql IMMUTABLE
AS $$
BEGIN
  RETURN CASE p_slug
    WHEN 'jeans-regular'     THEN 'jeans'
    WHEN 'jeans-slim'        THEN 'jeans'
    WHEN 'jeans-wide'        THEN 'jeans'
    WHEN 't-shirt-basic'     THEN 't-shirt'
    WHEN 't-shirt-oversize'  THEN 't-shirt'
    WHEN 'felpa-cappuccio'   THEN 'felpe'
    WHEN 'felpa-girocollo'   THEN 'felpe'
    WHEN 'shorts-sportivi'   THEN 'shorts'
    WHEN 'top-sportivo'      THEN 'top'
    WHEN 'pantaloni-eleganti' THEN 'pantaloni'
    WHEN 'camicie'           THEN 'camicia'
    ELSE p_slug
  END;
END;
$$;

COMMENT ON FUNCTION category_family IS
  'Raggruppa le sotto-categorie nella stessa famiglia (es. t-shirt-basic e t-shirt-oversize → t-shirt). Usato per evitare riassegnamenti intra-famiglia.';

-- ============================================================
-- 2. suggest_category_from_name v2
-- ============================================================

CREATE OR REPLACE FUNCTION suggest_category_from_name(p_name text)
RETURNS text
LANGUAGE plpgsql IMMUTABLE
AS $$
DECLARE
  n text;
BEGIN
  IF p_name IS NULL OR length(p_name) = 0 THEN
    RETURN NULL;
  END IF;
  n := lower(p_name);

  -- ============================================================
  -- BLOCCO 1: OUTERWEAR (priorità su altri perché può contenere keyword
  -- di sotto-strati: "Cappotto camicia", "Bomber denim", "Trench polo")
  -- ============================================================
  IF n ~* '\m(cappott\w*)\M' THEN RETURN 'cappotto'; END IF;
  IF n ~* '\m(trench)\M' THEN RETURN 'trench'; END IF;
  IF n ~* '\m(parka)\M' THEN RETURN 'parka'; END IF;
  IF n ~* '\m(piumin\w*|puffer)\M' THEN RETURN 'piumino'; END IF;
  IF n ~* '\m(bomber)\M' THEN RETURN 'bomber'; END IF;
  IF n ~* '\m(giubb\w*)\M' THEN RETURN 'giubbotto'; END IF;
  IF n ~* '\m(blazer)\M' THEN RETURN 'blazer'; END IF;

  -- "Giacca da abito/completo/tailored" → abito (parte di completo)
  IF n ~* '\mgiacc\w*\M' AND n ~* '(da\s+abit\w*|da\s+complet\w*|tailored)' THEN
    RETURN 'abito';
  END IF;
  IF n ~* '\m(giacc\w*)\M' THEN RETURN 'giacche'; END IF;

  -- ============================================================
  -- BLOCCO 2: DRESS vs SUIT (priorità su top wear perché "abito polo"
  -- è un vestito, non un polo)
  -- ============================================================
  IF n ~* '\m(vestit\w+)\M' THEN RETURN 'vestito'; END IF;

  -- "Abito" + segnali dress donna → vestito
  IF n ~* '\mabit[oi]\M' AND n ~* '\m(midi|maxi|mini|lung\w*|cort\w*|stamp\w*|fior\w*|sera|festa|cocktail|spallin\w*|drappeggiat\w*|asimmetric\w*|donna|polo|piqu[eé]|jacquard|all''?uncinetto|svasat\w*|plissettat\w*|costin\w*)\M' THEN
    RETURN 'vestito';
  END IF;

  -- "Abito" + segnali suit uomo → abito
  IF n ~* '\mabit[oi]\M' AND n ~* '\m(tailored|complet\w*|doppio\s+petto|uomo|navy|tre\s+pezzi|formale|fresco\s+lana|lana\s+fredda|gessat\w*|microstruttura)\M' THEN
    RETURN 'abito';
  END IF;

  -- "Abito" generico → NULL (conservativo, lascia attuale)
  IF n ~* '\mabit[oi]\M' THEN RETURN NULL; END IF;

  -- ============================================================
  -- BLOCCO 3: BOTTOMS (cargo/chinos/jogger/leggings prima di pantaloni;
  -- shorts prima di jeans perché "shorts denim" è shorts)
  -- ============================================================
  IF n ~* '\m(cargo)\M' THEN RETURN 'cargo'; END IF;
  IF n ~* '\m(chinos|chino)\M' THEN RETURN 'chinos'; END IF;
  IF n ~* '\m(joggers?)\M' THEN RETURN 'jogger'; END IF;
  IF n ~* '\m(leggings?|leggins)\M' THEN RETURN 'leggings'; END IF;

  IF n ~* '\m(shorts?|bermuda|pantaloncin\w*)\M' THEN
    IF n ~* '\m(sport\w*|active|running|gym|fitness|allenamento|palestra)\M' THEN
      RETURN 'shorts-sportivi';
    END IF;
    RETURN 'shorts';
  END IF;

  IF n ~* '\mpantalon\w*\M' AND n ~* '(da\s+complet\w*|da\s+abit\w*|tailored|elegant\w*|sigaretta|fresco\s+lana|lana\s+fredda|gessat\w*|microstruttura)' THEN
    RETURN 'pantaloni-eleganti';
  END IF;
  IF n ~* '\mpantalon\w*\M' THEN RETURN 'pantaloni'; END IF;

  -- ============================================================
  -- BLOCCO 4: GONNA (prima di jeans, perché "gonna denim" è gonna)
  -- ============================================================
  IF n ~* '\m(gonn\w*|minigonn\w*)\M' THEN RETURN 'gonna'; END IF;

  -- ============================================================
  -- BLOCCO 5: TOP WEAR (camicia prima di t-shirt; t-shirt prima di top)
  -- ============================================================
  IF n ~* '\m(camic\w*)\M' THEN RETURN 'camicia'; END IF;
  IF n ~* '\m(polo)\M' THEN RETURN 'polo'; END IF;
  IF n ~* '\m(canott\w*|canottier\w*)\M' THEN RETURN 'canotta'; END IF;

  IF n ~* '\m(t[\s.\-]?shirts?|magliett\w*|tees?)\M' THEN
    IF n ~* '\moversize\w*\M' THEN RETURN 't-shirt-oversize'; END IF;
    IF n ~* '\mbasic\w*\M' THEN RETURN 't-shirt-basic'; END IF;
    RETURN 't-shirt';
  END IF;

  IF n ~* '\m(top)\M' AND n ~* '\m(sport\w*|active|running|gym|fitness|allenamento|palestra|reggiseno)\M' THEN
    RETURN 'top-sportivo';
  END IF;
  IF n ~* '^\s*top\s' OR n ~* '\mtop\s+(con|in|a|da|midi|crop\w*|smanicat\w*|incrociat\w*|annodat\w*|elasticizz\w*|drappeggiat\w*|asimmetric\w*|halter|fascia|senza\s+manich\w*|scollo|spallin\w*)\M' THEN
    RETURN 'top';
  END IF;

  -- ============================================================
  -- BLOCCO 6: KNITWEAR (cappuccio > girocollo > felpe; maglione/cardigan)
  -- ============================================================
  IF n ~* '\m(cappucc\w*|hoodie)\M' AND n ~* '\m(felp\w*)\M' THEN RETURN 'felpa-cappuccio'; END IF;
  IF n ~* '\mhoodie\M' THEN RETURN 'felpa-cappuccio'; END IF;
  IF n ~* '\m(felp\w*)\M' AND n ~* '\m(girocoll\w*)\M' THEN RETURN 'felpa-girocollo'; END IF;
  IF n ~* '\msweatshirt\M' THEN RETURN 'felpa-girocollo'; END IF;
  IF n ~* '\m(felp\w*)\M' THEN RETURN 'felpe'; END IF;

  IF n ~* '\m(cardigan)\M' THEN RETURN 'cardigan'; END IF;
  IF n ~* '\m(maglion\w*|pullover|dolcevita)\M' THEN RETURN 'maglione'; END IF;

  -- ============================================================
  -- BLOCCO 7: SWIMWEAR (prima di intimo per "boxer/slip da bagno")
  -- ============================================================
  IF n ~* '\m(bikini|trikini|monokini)\M' THEN RETURN 'costume'; END IF;
  IF n ~* '\m(costume)\M' AND n ~* '\m(bagn\w*|piscina|mare)\M' THEN RETURN 'costume'; END IF;
  IF n ~* '\m(boxer|slip|brief)\M' AND n ~* '\m(bagn\w*|piscina|mare|nuot\w*)\M' THEN RETURN 'costume'; END IF;
  IF n ~* '\m(costume)\M' THEN RETURN 'costume'; END IF;

  -- ============================================================
  -- BLOCCO 8: INTIMO
  -- ============================================================
  IF n ~* '\m(slip|boxer|brief|reggisen\w*|brassiere|perizoma|tanga|culotte\w*|underwear|intimo|guaina)\M' THEN
    RETURN 'intimo';
  END IF;
  IF n ~* '\mbody\M' AND n !~* '\m(top|abit\w*|vestit\w*|gonn\w*)\M' THEN RETURN 'intimo'; END IF;

  -- ============================================================
  -- BLOCCO 9: TUTA SPORTIVA
  -- ============================================================
  IF n ~* '\m(tracksuit|tute\s+sportiv\w*)\M' THEN RETURN 'tuta'; END IF;
  IF n ~* '\m(tuta)\M' AND n ~* '\m(sport\w*|completa|jogging|fitness)\M' THEN RETURN 'tuta'; END IF;

  -- ============================================================
  -- BLOCCO 10: ACCESSORI (calzini)
  -- ============================================================
  IF n ~* '\m(calzin\w*|calzett\w*|fantasmin\w*|calze)\M' THEN RETURN 'calzini'; END IF;

  -- ============================================================
  -- BLOCCO 11: JEANS (FINALE — solo se NESSUN'altra categoria matcha)
  -- Cattura: pantaloni in denim genuini ("Jeans skinny", "Jean a vita alta").
  -- Le camicie/giacche/giubbotti/gonne/shorts in denim sono già state
  -- classificate sopra nelle loro categorie corrette.
  -- ============================================================
  IF n ~* '\m(jeans?|denim)\M' THEN RETURN 'jeans'; END IF;

  RETURN NULL;
END;
$$;

COMMENT ON FUNCTION suggest_category_from_name IS
  'Classificatore deterministico keyword-based v2: priorità ordinate da specialista a generico, outerwear > vestiti > bottoms > top wear > knitwear > swimwear > intimo > tuta > accessori > jeans (FINALE). Conservativo: restituisce NULL se ambiguo.';

-- ============================================================
-- DRY-RUN v2: applica il filtro category_family per evitare
-- riassegnamenti intra-famiglia.
-- ============================================================

DO $$
DECLARE
  total_products      integer;
  total_classified    integer;
  total_unchanged     integer;
  total_intra_family  integer;
  total_reassign      integer;
  total_unknown       integer;
BEGIN
  SELECT count(*) INTO total_products FROM products WHERE is_active = true;

  SELECT
    count(*) FILTER (WHERE suggest_category_from_name(name) IS NOT NULL),
    count(*) FILTER (WHERE suggest_category_from_name(name) IS NULL)
  INTO total_classified, total_unknown
  FROM products WHERE is_active = true;

  SELECT
    count(*) FILTER (WHERE suggest_category_from_name(p.name) = c.slug),
    count(*) FILTER (
      WHERE suggest_category_from_name(p.name) IS NOT NULL
        AND suggest_category_from_name(p.name) <> c.slug
        AND category_family(suggest_category_from_name(p.name)) = category_family(c.slug)
    ),
    count(*) FILTER (
      WHERE suggest_category_from_name(p.name) IS NOT NULL
        AND category_family(suggest_category_from_name(p.name)) <> category_family(c.slug)
    )
  INTO total_unchanged, total_intra_family, total_reassign
  FROM products p
  JOIN categories c ON c.id = p.category_id
  WHERE p.is_active = true;

  RAISE NOTICE '====================================================';
  RAISE NOTICE 'TAXONOMY DRY-RUN v2 — totale prodotti attivi: %', total_products;
  RAISE NOTICE '  - classificati:                 %', total_classified;
  RAISE NOTICE '  - già in categoria corretta:    %', total_unchanged;
  RAISE NOTICE '  - intra-famiglia (skip):        %', total_intra_family;
  RAISE NOTICE '  - DA RIASSEGNARE (cross-famiglia): %', total_reassign;
  RAISE NOTICE '  - non classificabili (NULL):    %', total_unknown;
  RAISE NOTICE '====================================================';
END $$;

-- Top 25 riassegnazioni cross-famiglia (le vere riassegnazioni)
DO $$
DECLARE r record;
BEGIN
  RAISE NOTICE 'TOP 25 RIASSEGNAZIONI CROSS-FAMIGLIA:';
  FOR r IN
    SELECT c.slug AS current_cat,
           suggest_category_from_name(p.name) AS suggested_cat,
           count(*) AS n
    FROM products p
    JOIN categories c ON c.id = p.category_id
    WHERE p.is_active = true
      AND suggest_category_from_name(p.name) IS NOT NULL
      AND category_family(suggest_category_from_name(p.name)) <> category_family(c.slug)
    GROUP BY c.slug, suggest_category_from_name(p.name)
    ORDER BY count(*) DESC
    LIMIT 25
  LOOP
    RAISE NOTICE '  % → %: % prodotti', rpad(r.current_cat, 22), rpad(r.suggested_cat, 22), r.n;
  END LOOP;
END $$;
