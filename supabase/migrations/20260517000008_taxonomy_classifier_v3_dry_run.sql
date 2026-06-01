-- Cleanup taxonomy — STEP 3: classificatore v3, dry-run finale.
--
-- v2 (20260517000007) ha mostrato 3 bug residui:
--   1. "Pullover/maglione con collo a polo" → veniva classificato polo, ma
--      è un maglione (il collo è solo un dettaglio).
--   2. "Top bikini" → veniva classificato top, ma è la parte superiore di
--      un costume da bagno.
--   3. "Pantaloni in denim" → veniva classificato pantaloni, ma
--      semanticamente è jeans (il keyword "pantalon" matcha prima di jeans).
--   4. "Cardigan con collo a polo" → veniva spostato a polo, ma resta
--      cardigan (capo a maglia con abbottonatura).
--
-- Correzioni:
--   - Aggiunta esclusione: polo NON match se nome contiene pullover|maglion
--     o cardigan.
--   - Aggiunta regola: top + bikini|mare|piscina → costume.
--   - Aggiunta regola: pantalon + denim|jeans → jeans (PRIMA di pantaloni
--     eleganti e generico).

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
  -- BLOCCO 1: OUTERWEAR
  -- ============================================================
  IF n ~* '\m(cappott\w*)\M' THEN RETURN 'cappotto'; END IF;
  IF n ~* '\m(trench)\M' THEN RETURN 'trench'; END IF;
  IF n ~* '\m(parka)\M' THEN RETURN 'parka'; END IF;
  IF n ~* '\m(piumin\w*|puffer)\M' THEN RETURN 'piumino'; END IF;
  IF n ~* '\m(bomber)\M' THEN RETURN 'bomber'; END IF;
  IF n ~* '\m(giubb\w*)\M' THEN RETURN 'giubbotto'; END IF;
  IF n ~* '\m(blazer)\M' THEN RETURN 'blazer'; END IF;
  IF n ~* '\mgiacc\w*\M' AND n ~* '(da\s+abit\w*|da\s+complet\w*|tailored)' THEN
    RETURN 'abito';
  END IF;
  IF n ~* '\m(giacc\w*)\M' THEN RETURN 'giacche'; END IF;

  -- ============================================================
  -- BLOCCO 2: DRESS vs SUIT
  -- ============================================================
  IF n ~* '\m(vestit\w+)\M' THEN RETURN 'vestito'; END IF;

  IF n ~* '\mabit[oi]\M' AND n ~* '\m(midi|maxi|mini|lung\w*|cort\w*|stamp\w*|fior\w*|sera|festa|cocktail|spallin\w*|drappeggiat\w*|asimmetric\w*|donna|polo|piqu[eé]|jacquard|all''?uncinetto|svasat\w*|plissettat\w*|costin\w*)\M' THEN
    RETURN 'vestito';
  END IF;

  IF n ~* '\mabit[oi]\M' AND n ~* '\m(tailored|complet\w*|doppio\s+petto|uomo|navy|tre\s+pezzi|formale|fresco\s+lana|lana\s+fredda|gessat\w*|microstruttura)\M' THEN
    RETURN 'abito';
  END IF;

  IF n ~* '\mabit[oi]\M' THEN RETURN NULL; END IF;

  -- ============================================================
  -- BLOCCO 3: BOTTOMS
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

  -- FIX v3 — "Pantaloni in denim" / "Pantaloni jeans" → jeans
  IF n ~* '\mpantalon\w*\M' AND n ~* '\m(denim|jeans?)\M' THEN
    RETURN 'jeans';
  END IF;

  IF n ~* '\mpantalon\w*\M' AND n ~* '(da\s+complet\w*|da\s+abit\w*|tailored|elegant\w*|sigaretta|fresco\s+lana|lana\s+fredda|gessat\w*|microstruttura)' THEN
    RETURN 'pantaloni-eleganti';
  END IF;
  IF n ~* '\mpantalon\w*\M' THEN RETURN 'pantaloni'; END IF;

  -- ============================================================
  -- BLOCCO 4: GONNA
  -- ============================================================
  IF n ~* '\m(gonn\w*|minigonn\w*)\M' THEN RETURN 'gonna'; END IF;

  -- ============================================================
  -- BLOCCO 5: SWIMWEAR (anticipato — prima di top per "top bikini")
  -- ============================================================
  IF n ~* '\m(bikini|trikini|monokini)\M' THEN RETURN 'costume'; END IF;
  IF n ~* '\mtop\M' AND n ~* '\m(mare|piscina|bagn\w*|nuot\w*)\M' THEN RETURN 'costume'; END IF;
  IF n ~* '\m(costume)\M' AND n ~* '\m(bagn\w*|piscina|mare)\M' THEN RETURN 'costume'; END IF;
  IF n ~* '\m(boxer|slip|brief)\M' AND n ~* '\m(bagn\w*|piscina|mare|nuot\w*)\M' THEN RETURN 'costume'; END IF;
  IF n ~* '\m(costume)\M' THEN RETURN 'costume'; END IF;

  -- ============================================================
  -- BLOCCO 6: KNITWEAR (maglione/cardigan PRIMA di polo, per
  -- "Pullover con collo a polo", "Cardigan-polo")
  -- ============================================================
  IF n ~* '\m(cappucc\w*|hoodie)\M' AND n ~* '\m(felp\w*)\M' THEN RETURN 'felpa-cappuccio'; END IF;
  IF n ~* '\mhoodie\M' THEN RETURN 'felpa-cappuccio'; END IF;
  IF n ~* '\m(felp\w*)\M' AND n ~* '\m(girocoll\w*)\M' THEN RETURN 'felpa-girocollo'; END IF;
  IF n ~* '\msweatshirt\M' THEN RETURN 'felpa-girocollo'; END IF;
  IF n ~* '\m(felp\w*)\M' THEN RETURN 'felpe'; END IF;

  IF n ~* '\m(cardigan)\M' THEN RETURN 'cardigan'; END IF;
  IF n ~* '\m(maglion\w*|pullover|dolcevita)\M' THEN RETURN 'maglione'; END IF;

  -- ============================================================
  -- BLOCCO 7: TOP WEAR LEGGERO
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
  -- BLOCCO 8: INTIMO
  -- ============================================================
  IF n ~* '\m(slip|boxer|brief|reggisen\w*|brassiere|perizoma|tanga|culotte\w*|underwear|intimo|guaina)\M' THEN
    RETURN 'intimo';
  END IF;
  IF n ~* '\mbody\M' AND n !~* '\m(top|abit\w*|vestit\w*|gonn\w*)\M' THEN RETURN 'intimo'; END IF;

  -- ============================================================
  -- BLOCCO 9: TUTA / ACCESSORI
  -- ============================================================
  IF n ~* '\m(tracksuit|tute\s+sportiv\w*)\M' THEN RETURN 'tuta'; END IF;
  IF n ~* '\m(tuta)\M' AND n ~* '\m(sport\w*|completa|jogging|fitness)\M' THEN RETURN 'tuta'; END IF;

  IF n ~* '\m(calzin\w*|calzett\w*|fantasmin\w*|calze)\M' THEN RETURN 'calzini'; END IF;

  -- ============================================================
  -- BLOCCO 10: JEANS (FINALE)
  -- ============================================================
  IF n ~* '\m(jeans?|denim)\M' THEN RETURN 'jeans'; END IF;

  RETURN NULL;
END;
$$;

COMMENT ON FUNCTION suggest_category_from_name IS
  'Classificatore deterministico keyword-based v3: outerwear > vestiti > bottoms > gonna > swimwear > knitwear > top wear > intimo > tuta > calzini > jeans (FINALE). Pullover/maglione vincono su polo per "Pullover collo a polo". Top + bikini/mare → costume. Pantaloni + denim → jeans.';

-- ============================================================
-- DRY-RUN v3
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
  RAISE NOTICE 'TAXONOMY DRY-RUN v3 — totale prodotti attivi: %', total_products;
  RAISE NOTICE '  - classificati:                 %', total_classified;
  RAISE NOTICE '  - già in categoria corretta:    %', total_unchanged;
  RAISE NOTICE '  - intra-famiglia (skip):        %', total_intra_family;
  RAISE NOTICE '  - DA RIASSEGNARE (cross-famiglia): %', total_reassign;
  RAISE NOTICE '  - non classificabili (NULL):    %', total_unknown;
  RAISE NOTICE '====================================================';
END $$;

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
