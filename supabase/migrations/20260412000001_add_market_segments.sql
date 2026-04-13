-- Estende l'enum market_segment con i segmenti usati dall'espansione del catalogo brand:
-- 'fast_fashion' (alias moderno per il retail mass-market),
-- 'premium' (contemporary/designer accessibile),
-- 'maison' (lusso e alta moda).
-- Nota: in PostgreSQL i nuovi valori enum non possono essere usati nella stessa
-- transazione in cui vengono aggiunti, quindi l'INSERT dei brand è in una migration successiva.

ALTER TYPE market_segment ADD VALUE IF NOT EXISTS 'fast_fashion';
ALTER TYPE market_segment ADD VALUE IF NOT EXISTS 'premium';
ALTER TYPE market_segment ADD VALUE IF NOT EXISTS 'maison';
