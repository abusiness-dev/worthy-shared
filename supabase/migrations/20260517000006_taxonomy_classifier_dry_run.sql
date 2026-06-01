-- Cleanup taxonomy keyword-based — STEP 1: dry-run.
--
-- Molte categorie sono semanticamente contaminate (es. "Abiti" contiene
-- pantaloni/camicie/shorts di Massimo Dutti e COS). Questo falsifica il QPR
-- in entrambe le direzioni: penalizza gli abiti veri e premia
-- ingiustamente i contaminanti.
--
-- Approccio: classificatore deterministico keyword-based con regole di
-- priorità ordinate dalla più specifica alla più generica. Conservativo:
-- restituisce NULL se non riesce a classificare con certezza (evitare falsi
-- positivi è prioritario su pulire ogni capo).
--
-- Questa migration crea SOLO la funzione e logga le statistiche. NON esegue
-- nessun UPDATE. Il prossimo step (20260517000007) applicherà le
-- riassegnazioni se le stats sono ragionevoli.

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

  -- ----------------------------------------------------------------
  -- Pantaloni specializzati (priorità su pantaloni generico)
  -- ----------------------------------------------------------------
  IF n ~* '\m(cargo)\M' THEN RETURN 'cargo'; END IF;
  IF n ~* '\m(chinos|chino)\M' THEN RETURN 'chinos'; END IF;
  IF n ~* '\m(joggers?)\M' THEN RETURN 'jogger'; END IF;
  IF n ~* '\m(leggings?|leggins)\M' THEN RETURN 'leggings'; END IF;
  IF n ~* '\m(jeans?|denim)\M' THEN RETURN 'jeans'; END IF;

  -- ----------------------------------------------------------------
  -- Shorts (priorità su pantaloni; "bermuda" → shorts)
  -- ----------------------------------------------------------------
  IF n ~* '\m(shorts?|bermuda|pantaloncin\w*)\M' THEN
    IF n ~* '\m(sport\w*|active|running|gym|fitness|allenamento|palestra)\M' THEN
      RETURN 'shorts-sportivi';
    END IF;
    RETURN 'shorts';
  END IF;

  -- ----------------------------------------------------------------
  -- Pantaloni eleganti (segnali "da completo/da abito/tailored/eleganti")
  -- ----------------------------------------------------------------
  IF n ~* '\mpantalon\w*\M' AND n ~* '(da\s+complet\w*|da\s+abit\w*|tailored|elegant\w*|sigaretta|fresco\s+lana|lana\s+fredda|gessat\w*|microstruttura)' THEN
    RETURN 'pantaloni-eleganti';
  END IF;

  -- Pantaloni generico (fallback)
  IF n ~* '\mpantalon\w*\M' THEN RETURN 'pantaloni'; END IF;

  -- ----------------------------------------------------------------
  -- Outerwear (priorità sui vari tipi, poi giacche generico)
  -- ----------------------------------------------------------------
  IF n ~* '\m(cappott\w*)\M' THEN RETURN 'cappotto'; END IF;
  IF n ~* '\m(trench)\M' THEN RETURN 'trench'; END IF;
  IF n ~* '\m(parka)\M' THEN RETURN 'parka'; END IF;
  IF n ~* '\m(piumin\w*|puffer)\M' THEN RETURN 'piumino'; END IF;
  IF n ~* '\m(bomber)\M' THEN RETURN 'bomber'; END IF;
  IF n ~* '\m(giubb\w*)\M' THEN RETURN 'giubbotto'; END IF;
  IF n ~* '\m(blazer)\M' THEN RETURN 'blazer'; END IF;

  -- "Giacca da abito" / "giacca da completo" → suit jacket; mappiamo a
  -- abito perché parte di un completo. Conservativo: il QPR cluster di abiti
  -- ne beneficia.
  IF n ~* '\mgiacc\w*\M' AND n ~* '(da\s+abit\w*|da\s+complet\w*|tailored)' THEN
    RETURN 'abito';
  END IF;

  IF n ~* '\m(giacc\w*)\M' THEN RETURN 'giacche'; END IF;

  -- ----------------------------------------------------------------
  -- Felpe (priorità: cappuccio > girocollo > felpe generico)
  -- ----------------------------------------------------------------
  IF n ~* '(felp\w*\s+(con\s+)?cappucc\w*|hoodie|\bcappucc\w*\b)' AND n ~* '\m(felp\w*|hoodie|cappucc\w*)\M' THEN
    RETURN 'felpa-cappuccio';
  END IF;
  IF n ~* '(felp\w*\s+girocoll\w*|sweatshirt)' THEN RETURN 'felpa-girocollo'; END IF;
  IF n ~* '\m(felp\w*)\M' THEN RETURN 'felpe'; END IF;

  -- ----------------------------------------------------------------
  -- Maglieria
  -- ----------------------------------------------------------------
  IF n ~* '\m(cardigan)\M' THEN RETURN 'cardigan'; END IF;
  IF n ~* '\m(maglion\w*|pullover|dolcevita)\M' THEN RETURN 'maglione'; END IF;

  -- ----------------------------------------------------------------
  -- Costumi (priorità su intimo per "boxer/slip da bagno")
  -- ----------------------------------------------------------------
  IF n ~* '\m(bikini|trikini|monokini)\M' THEN RETURN 'costume'; END IF;
  IF n ~* '\m(costume)\M' AND n ~* '\m(bagn\w*|piscina|mare)\M' THEN RETURN 'costume'; END IF;
  IF n ~* '\m(boxer|slip|brief)\M' AND n ~* '\m(bagn\w*|piscina|mare|nuot\w*)\M' THEN RETURN 'costume'; END IF;
  IF n ~* '\m(costume)\M' THEN RETURN 'costume'; END IF;

  -- ----------------------------------------------------------------
  -- Intimo
  -- ----------------------------------------------------------------
  IF n ~* '\m(slip|boxer|brief|reggisen\w*|brassiere|perizoma|tanga|culotte\w*|underwear|intimo|guaina)\M' THEN
    RETURN 'intimo';
  END IF;
  IF n ~* '\mbody\M' AND n !~* '\m(top|abit\w*|vestit\w*|gonn\w*)\M' THEN RETURN 'intimo'; END IF;

  -- ----------------------------------------------------------------
  -- Top wear
  -- ----------------------------------------------------------------
  -- "Camicia da abito" → camicia (non abito)
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
  -- "Top" all'inizio o "top + qualificatore donna"
  IF n ~* '^\s*top\s' OR n ~* '\mtop\s+(con|in|a|da|midi|crop\w*|smanicat\w*|incrociat\w*|annodat\w*|elasticizz\w*|drappeggiat\w*|asimmetric\w*)\M' THEN
    RETURN 'top';
  END IF;

  -- ----------------------------------------------------------------
  -- Calzini
  -- ----------------------------------------------------------------
  IF n ~* '\m(calzin\w*|calzett\w*|fantasmin\w*|calze)\M' THEN RETURN 'calzini'; END IF;

  -- ----------------------------------------------------------------
  -- Gonna
  -- ----------------------------------------------------------------
  IF n ~* '\m(gonn\w*|minigonn\w*)\M' THEN RETURN 'gonna'; END IF;

  -- ----------------------------------------------------------------
  -- Tuta sportiva (intera, non singolo pezzo)
  -- ----------------------------------------------------------------
  IF n ~* '\m(tracksuit|tute\s+sportiv\w*)\M' THEN RETURN 'tuta'; END IF;
  IF n ~* '\m(tuta)\M' AND n ~* '\m(sport\w*|completa|jogging|fitness)\M' THEN RETURN 'tuta'; END IF;

  -- ----------------------------------------------------------------
  -- Vestiti (dress) vs Abiti (suit)
  -- "vestito"/"vestiti" → SEMPRE vestito
  -- "abito" da solo → ambiguo; richiede segnali per disambiguare
  -- ----------------------------------------------------------------
  IF n ~* '\m(vestit\w+)\M' THEN RETURN 'vestito'; END IF;

  -- "Abito" + segnali donna → vestito
  IF n ~* '\mabit[oi]\M' AND n ~* '\m(midi|maxi|mini|lung\w*|cort\w*|stamp\w*|fior\w*|sera|festa|cocktail|spallin\w*|drappeggiat\w*|asimmetric\w*|elegante\s+donna|donna)\M' THEN
    RETURN 'vestito';
  END IF;

  -- "Abito" + segnali suit → abito
  IF n ~* '\mabit[oi]\M' AND n ~* '\m(tailored|complet\w*|doppio\s+petto|uomo|navy|tre\s+pezzi|formale|fresco\s+lana|lana\s+fredda)\M' THEN
    RETURN 'abito';
  END IF;

  -- "Abito" generico senza segnali → NULL (conservativo, evita riassegnamenti rischiosi)
  -- Lasciamo che resti dov'è.

  RETURN NULL;
END;
$$;

COMMENT ON FUNCTION suggest_category_from_name IS
  'Classificatore deterministico keyword-based per la categoria di un prodotto, basato sul nome. Regole di priorità ordinate dalla più specifica alla più generica. Restituisce slug della categoria suggerita o NULL se non classificabile. Usato per cleanup taxonomy QPR.';

-- ============================================================
-- DRY-RUN: solo statistiche, nessun UPDATE.
-- ============================================================

DO $$
DECLARE
  total_products  integer;
  total_classified integer;
  total_unchanged integer;
  total_reassign  integer;
  total_unknown   integer;
BEGIN
  SELECT count(*) INTO total_products FROM products WHERE is_active = true;

  SELECT
    count(*) FILTER (WHERE suggest_category_from_name(name) IS NOT NULL),
    count(*) FILTER (WHERE suggest_category_from_name(name) IS NULL)
  INTO total_classified, total_unknown
  FROM products WHERE is_active = true;

  SELECT
    count(*) FILTER (
      WHERE suggest_category_from_name(p.name) IS NOT NULL
        AND suggest_category_from_name(p.name) = c.slug
    ),
    count(*) FILTER (
      WHERE suggest_category_from_name(p.name) IS NOT NULL
        AND suggest_category_from_name(p.name) <> c.slug
    )
  INTO total_unchanged, total_reassign
  FROM products p
  JOIN categories c ON c.id = p.category_id
  WHERE p.is_active = true;

  RAISE NOTICE '====================================================';
  RAISE NOTICE 'TAXONOMY DRY-RUN — totale prodotti attivi: %', total_products;
  RAISE NOTICE '  - classificati dalla funzione:  %', total_classified;
  RAISE NOTICE '  - già in categoria corretta:    %', total_unchanged;
  RAISE NOTICE '  - DA RIASSEGNARE:               %', total_reassign;
  RAISE NOTICE '  - non classificabili (NULL):    %', total_unknown;
  RAISE NOTICE '====================================================';
END $$;

-- Top 20 cluster (current_category × suggested_category) con più
-- riassegnazioni proposte, per ispezione manuale.
DO $$
DECLARE r record;
BEGIN
  RAISE NOTICE 'TOP 20 RIASSEGNAZIONI PROPOSTE (current_cat → suggested_cat):';
  FOR r IN
    SELECT c.slug AS current_cat,
           suggest_category_from_name(p.name) AS suggested_cat,
           count(*) AS n
    FROM products p
    JOIN categories c ON c.id = p.category_id
    WHERE p.is_active = true
      AND suggest_category_from_name(p.name) IS NOT NULL
      AND suggest_category_from_name(p.name) <> c.slug
    GROUP BY c.slug, suggest_category_from_name(p.name)
    ORDER BY count(*) DESC
    LIMIT 20
  LOOP
    RAISE NOTICE '  % → %: % prodotti', rpad(r.current_cat, 20), rpad(r.suggested_cat, 20), r.n;
  END LOOP;
END $$;
