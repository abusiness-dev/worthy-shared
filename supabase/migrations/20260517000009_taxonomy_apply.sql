-- Cleanup taxonomy — STEP 4 (FINAL): apply.
--
-- Versione classifier v4: rimuove "culotte" dalle keyword intimo perché può
-- essere shape di jeans/pantaloni ("Jeans Catherin culotte vita alta" Mango).
-- Il resto della funzione è invariata rispetto a v3 (20260517000008).
--
-- Applica le riassegnazioni cross-famiglia (~236 prodotti) e ricalcola
-- aggregati cluster + worthy_score di tutti i prodotti attivi.
--
-- Note operative:
--   - UPDATE category_id triggera trg_products_qpr_aggregates (AFTER) che
--     ricalcola gli aggregati cluster per category × segment.
--   - UPDATE category_id triggera trg_products_calculate_score (AFTER) che
--     chiama calculate_worthy_score → ricalcola QPR.
--   - La fase di backfill finale è ridondante con i trigger ma garantisce
--     coerenza.

-- ============================================================
-- 1. Classifier v4 — rimuove "culotte" da intimo (collision con jeans
--    culotte). Tutto il resto invariato.
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

  -- BLOCCO 1: OUTERWEAR
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

  -- BLOCCO 2: DRESS vs SUIT
  IF n ~* '\m(vestit\w+)\M' THEN RETURN 'vestito'; END IF;
  IF n ~* '\mabit[oi]\M' AND n ~* '\m(midi|maxi|mini|lung\w*|cort\w*|stamp\w*|fior\w*|sera|festa|cocktail|spallin\w*|drappeggiat\w*|asimmetric\w*|donna|polo|piqu[eé]|jacquard|all''?uncinetto|svasat\w*|plissettat\w*|costin\w*)\M' THEN
    RETURN 'vestito';
  END IF;
  IF n ~* '\mabit[oi]\M' AND n ~* '\m(tailored|complet\w*|doppio\s+petto|uomo|navy|tre\s+pezzi|formale|fresco\s+lana|lana\s+fredda|gessat\w*|microstruttura)\M' THEN
    RETURN 'abito';
  END IF;
  IF n ~* '\mabit[oi]\M' THEN RETURN NULL; END IF;

  -- BLOCCO 3: BOTTOMS
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
  IF n ~* '\mpantalon\w*\M' AND n ~* '\m(denim|jeans?)\M' THEN
    RETURN 'jeans';
  END IF;
  IF n ~* '\mpantalon\w*\M' AND n ~* '(da\s+complet\w*|da\s+abit\w*|tailored|elegant\w*|sigaretta|fresco\s+lana|lana\s+fredda|gessat\w*|microstruttura)' THEN
    RETURN 'pantaloni-eleganti';
  END IF;
  IF n ~* '\mpantalon\w*\M' THEN RETURN 'pantaloni'; END IF;

  -- BLOCCO 4: GONNA
  IF n ~* '\m(gonn\w*|minigonn\w*)\M' THEN RETURN 'gonna'; END IF;

  -- BLOCCO 5: SWIMWEAR (prima di top per "top bikini")
  IF n ~* '\m(bikini|trikini|monokini)\M' THEN RETURN 'costume'; END IF;
  IF n ~* '\mtop\M' AND n ~* '\m(mare|piscina|bagn\w*|nuot\w*)\M' THEN RETURN 'costume'; END IF;
  IF n ~* '\m(costume)\M' AND n ~* '\m(bagn\w*|piscina|mare)\M' THEN RETURN 'costume'; END IF;
  IF n ~* '\m(boxer|slip|brief)\M' AND n ~* '\m(bagn\w*|piscina|mare|nuot\w*)\M' THEN RETURN 'costume'; END IF;
  IF n ~* '\m(costume)\M' THEN RETURN 'costume'; END IF;

  -- BLOCCO 6: KNITWEAR (maglione/cardigan PRIMA di polo)
  IF n ~* '\m(cappucc\w*|hoodie)\M' AND n ~* '\m(felp\w*)\M' THEN RETURN 'felpa-cappuccio'; END IF;
  IF n ~* '\mhoodie\M' THEN RETURN 'felpa-cappuccio'; END IF;
  IF n ~* '\m(felp\w*)\M' AND n ~* '\m(girocoll\w*)\M' THEN RETURN 'felpa-girocollo'; END IF;
  IF n ~* '\msweatshirt\M' THEN RETURN 'felpa-girocollo'; END IF;
  IF n ~* '\m(felp\w*)\M' THEN RETURN 'felpe'; END IF;
  IF n ~* '\m(cardigan)\M' THEN RETURN 'cardigan'; END IF;
  IF n ~* '\m(maglion\w*|pullover|dolcevita)\M' THEN RETURN 'maglione'; END IF;

  -- BLOCCO 7: TOP WEAR LEGGERO
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

  -- BLOCCO 8: INTIMO (v4: rimossa "culotte" perché può essere taglio jeans)
  IF n ~* '\m(slip|boxer|brief|reggisen\w*|brassiere|perizoma|tanga|underwear|intimo|guaina)\M' THEN
    RETURN 'intimo';
  END IF;
  IF n ~* '\mbody\M' AND n !~* '\m(top|abit\w*|vestit\w*|gonn\w*)\M' THEN RETURN 'intimo'; END IF;

  -- BLOCCO 9: TUTA / ACCESSORI
  IF n ~* '\m(tracksuit|tute\s+sportiv\w*)\M' THEN RETURN 'tuta'; END IF;
  IF n ~* '\m(tuta)\M' AND n ~* '\m(sport\w*|completa|jogging|fitness)\M' THEN RETURN 'tuta'; END IF;
  IF n ~* '\m(calzin\w*|calzett\w*|fantasmin\w*|calze)\M' THEN RETURN 'calzini'; END IF;

  -- BLOCCO 10: JEANS (FINALE)
  IF n ~* '\m(jeans?|denim)\M' THEN RETURN 'jeans'; END IF;

  RETURN NULL;
END;
$$;

COMMENT ON FUNCTION suggest_category_from_name IS
  'Classificatore v4 (finale). Stesso ordine di v3 ma "culotte" rimosso dalle keyword intimo per non sottrarre "Jeans Catherin culotte vita alta".';

-- ============================================================
-- 2. Apply: UPDATE category_id per i prodotti cross-famiglia.
--    I trigger AFTER UPDATE su products gestiscono in automatico:
--      - trg_products_qpr_aggregates: ricalcolo cluster aggregates
--      - trg_products_calculate_score: ricalcolo worthy_score / QPR
-- ============================================================

DO $$
DECLARE
  r record;
  cat_id_new uuid;
  n integer := 0;
BEGIN
  FOR r IN
    SELECT p.id, p.name, c.slug AS current_slug,
           suggest_category_from_name(p.name) AS suggested_slug
    FROM products p
    JOIN categories c ON c.id = p.category_id
    WHERE p.is_active = true
      AND suggest_category_from_name(p.name) IS NOT NULL
      AND category_family(suggest_category_from_name(p.name)) <> category_family(c.slug)
  LOOP
    SELECT id INTO cat_id_new FROM categories WHERE slug = r.suggested_slug;
    IF cat_id_new IS NOT NULL THEN
      UPDATE products SET category_id = cat_id_new WHERE id = r.id;
      n := n + 1;
    END IF;
  END LOOP;
  RAISE NOTICE 'Taxonomy cleanup: % prodotti riassegnati cross-famiglia', n;
END $$;

-- ============================================================
-- 3. Backfill aggregati cluster e medie categoria (sicurezza)
-- ============================================================

DO $$
DECLARE r record;
BEGIN
  FOR r IN SELECT id FROM categories LOOP
    PERFORM recalculate_category_medians(r.id);
  END LOOP;
  FOR r IN
    SELECT DISTINCT p.category_id, b.market_segment
    FROM products p
    JOIN brands b ON b.id = p.brand_id
    WHERE p.is_active = true
  LOOP
    PERFORM recalculate_category_segment_aggregates(r.category_id, r.market_segment);
  END LOOP;
  RAISE NOTICE 'Aggregati cluster e medie categoria rinfrescati';
END $$;

-- ============================================================
-- 4. Ricalcolo finale di tutti i prodotti attivi
--    (i trigger già hanno ricalcolato i 236 spostati; questa passata
--    aggiorna anche gli altri perché le mediane di cluster sono cambiate)
-- ============================================================

DO $$
DECLARE
  r record;
  n integer := 0;
BEGIN
  FOR r IN SELECT id FROM products WHERE is_active = true LOOP
    PERFORM calculate_worthy_score(r.id);
    n := n + 1;
  END LOOP;
  RAISE NOTICE 'Recalc finale: % prodotti', n;
END $$;

SELECT recalculate_brand_avg_scores();

-- ============================================================
-- 5. Cleanup: drop delle funzioni helper (servivano solo per il cleanup)
-- ============================================================

DROP FUNCTION IF EXISTS suggest_category_from_name(text);
DROP FUNCTION IF EXISTS category_family(text);
