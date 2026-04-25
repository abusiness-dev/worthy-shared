-- Aggiunge colonne supply chain a products.
-- country_of_production esiste già. Filatura, tessitura e tintura sono raramente
-- esposte per singolo SKU dai brand fast-fashion → colonne nullable, popolate
-- opportunisticamente dallo scraper quando il brand pubblica il dato in PDP.

ALTER TABLE products
  ADD COLUMN spinning_location text,
  ADD COLUMN weaving_location  text,
  ADD COLUMN dyeing_location   text;

COMMENT ON COLUMN products.spinning_location IS 'Paese/sede di filatura del filato, quando dichiarato dal brand (spesso null)';
COMMENT ON COLUMN products.weaving_location  IS 'Paese/sede di tessitura o knitting, quando dichiarato dal brand (spesso null)';
COMMENT ON COLUMN products.dyeing_location   IS 'Paese/sede di tintura del tessuto, quando dichiarato dal brand (spesso null)';
