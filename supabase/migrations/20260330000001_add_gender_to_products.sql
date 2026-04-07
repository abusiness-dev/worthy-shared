-- Enum per il genere prodotto
CREATE TYPE gender AS ENUM ('uomo', 'donna', 'unisex');

-- Aggiungere colonna gender alla tabella products
ALTER TABLE products ADD COLUMN gender gender NOT NULL DEFAULT 'unisex';

-- Indice per filtrare per genere
CREATE INDEX idx_products_gender ON products (gender);
