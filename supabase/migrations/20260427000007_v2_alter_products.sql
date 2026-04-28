-- Worthy Score v2 - Estensione tabella products per i nuovi sub-score.
--
-- Aggiunge:
--   - country_of_production_iso2: FK soft a countries.iso2 (parallela alla
--     vecchia country_of_production text che resta per compatibilità).
--     Lo scraper popola la nuova man mano che vengono normalizzate le
--     stringhe esistenti.
--   - score_origin, score_manufacturing, score_technical, score_sustainability:
--     sub-score 0-100 delle nuove lenti.
--   - score_confidence: 0-100, quanti segnali sono stati realmente usati nel
--     calcolo (graceful degradation index).
--   - score_breakdown: jsonb con il dettaglio completo per spiegabilità UX.
--
-- Le colonne sono nullable di default. La funzione di scoring v2 le popolerà.
-- Le colonne legacy (worthy_score, score_composition, score_qpr, verdict)
-- restano: durante F3 (dual-write) v1 continua a scrivere worthy_score, v2
-- scrive su score_breakdown. Allo switch (F5) lo swap diventa effettivo.

ALTER TABLE products
  ADD COLUMN country_of_production_iso2 char(2) REFERENCES countries(iso2) ON DELETE SET NULL,
  ADD COLUMN spinning_iso2              char(2) REFERENCES countries(iso2) ON DELETE SET NULL,
  ADD COLUMN weaving_iso2               char(2) REFERENCES countries(iso2) ON DELETE SET NULL,
  ADD COLUMN dyeing_iso2                char(2) REFERENCES countries(iso2) ON DELETE SET NULL,
  ADD COLUMN score_origin               numeric(5,2),
  ADD COLUMN score_manufacturing        numeric(5,2),
  ADD COLUMN score_technical            numeric(5,2),
  ADD COLUMN score_sustainability       numeric(5,2),
  ADD COLUMN score_confidence           numeric(5,2),
  ADD COLUMN score_breakdown            jsonb;

CREATE INDEX idx_products_country_iso2 ON products(country_of_production_iso2);

COMMENT ON COLUMN products.country_of_production_iso2 IS 'FK normalizzato ISO2; popolato dallo scraper. Affianca country_of_production (text legacy).';
COMMENT ON COLUMN products.spinning_iso2              IS 'FK normalizzato ISO2 della filatura; affianca spinning_location (text legacy).';
COMMENT ON COLUMN products.weaving_iso2               IS 'FK normalizzato ISO2 della tessitura; affianca weaving_location (text legacy).';
COMMENT ON COLUMN products.dyeing_iso2                IS 'FK normalizzato ISO2 della tintura; affianca dyeing_location (text legacy).';
COMMENT ON COLUMN products.score_origin               IS 'Sub-score lente Origin (0-100); peso 20% su Worthy Score v2.';
COMMENT ON COLUMN products.score_manufacturing        IS 'Sub-score lente Manufacturing (0-100); peso 15% su Worthy Score v2.';
COMMENT ON COLUMN products.score_technical            IS 'Sub-score lente Technical (0-100); peso 10% su Worthy Score v2.';
COMMENT ON COLUMN products.score_sustainability       IS 'Sub-score lente Sustainability (0-100, cumulativo capped); peso 5% su Worthy Score v2.';
COMMENT ON COLUMN products.score_confidence           IS 'Confidence index 0-100: quanti dati sono stati realmente usati nel calcolo v2.';
COMMENT ON COLUMN products.score_breakdown            IS 'JSONB con il dettaglio per ogni lente (score, weight, contribution, sources). Usato per "perché questo score?" in UX.';
