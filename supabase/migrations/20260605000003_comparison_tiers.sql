-- ════════════════════════════════════════════════════════════════════
-- Migration: leghe di confronto del brand (comparison_tier)
--
-- Problema: il QPR cluster-based usa brands.market_segment (enum a 4 valori:
-- ultra_fast, fast_fashion, premium, maison) come dimensione di confronto. È
-- troppo grossolano e separa brand che l'utente considera comparabili:
--   - Zara (fast_fashion) e Primark (ultra_fast) finiscono in cluster diversi;
--   - dentro 'premium' convivono COS (~80€) e brand molto più alti.
--
-- Soluzione: una NUOVA dimensione EDITABILE e REVERSIBILE — comparison_tier —
-- come dato (lookup table + colonna text), NON come enum Postgres (append-only,
-- irreversibile). market_segment resta in schema come attributo legacy (non
-- rinominato/rimosso → nessun breaking change per worthy-app/worthy-admin), ma
-- NON guida più il QPR (vedi 20260605000004).
--
-- 4 leghe larghe ordinate (scelta prodotto: pochi cluster ben popolati che
-- rispettano i gruppi reali):
--   mass_market (0) · premium (1) · luxury (2) · maison (3)
--
-- Mapping iniziale brand→lega (calibrabile con Mattia):
--   ultra_fast/fast_fashion → mass_market  (Zara ~ H&M ~ Bershka ~ Primark)
--   premium                 → premium      (Suitsupply ~ COS ~ Massimo Dutti ~ Lacoste ~ Ralph Lauren)
--   maison                  → maison
--   + split 'luxury' per i contemporary/tecnici elevati (Theory, A.P.C.,
--     Zadig & Voltaire, Isabel Marant Étoile, Moncler, Stone Island).
--
-- Idempotente.
-- ════════════════════════════════════════════════════════════════════

-- ============================================================
-- 1. Lookup table comparison_tiers (ordinata)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.comparison_tiers (
  key        text PRIMARY KEY,
  label      text NOT NULL,
  sort_order int  NOT NULL,
  price_hint text
);

COMMENT ON TABLE public.comparison_tiers IS
  'Leghe di confronto del brand (asse di clustering del QPR). Editabili come dato: aggiungere/spostare leghe NON richiede una migration di enum. sort_order definisce l''adiacenza usata dalle alternative.';

INSERT INTO public.comparison_tiers (key, label, sort_order, price_hint) VALUES
  ('mass_market', 'Mass-market',          0, 'Fast fashion e mass-market (Zara, H&M, Bershka, Primark, Mango, Uniqlo, Shein)'),
  ('premium',     'Premium / Contemporary',1, 'Premium accessibile e contemporary (Suitsupply, COS, Massimo Dutti, Lacoste, Ralph Lauren, Hugo Boss)'),
  ('luxury',      'Luxury',                2, 'Contemporary elevato e tecnico-lusso (Theory, A.P.C., Zadig & Voltaire, Moncler, Stone Island)'),
  ('maison',      'Maison',                3, 'Alta gamma / maison (Gucci, Prada, Loro Piana, Zegna, Hermès)')
ON CONFLICT (key) DO UPDATE
  SET label = EXCLUDED.label,
      sort_order = EXCLUDED.sort_order,
      price_hint = EXCLUDED.price_hint;

-- ============================================================
-- 2. brands.comparison_tier (colonna editabile + backfill + FK)
-- ============================================================

ALTER TABLE public.brands
  ADD COLUMN IF NOT EXISTS comparison_tier text;

-- Backfill dal market_segment legacy.
UPDATE public.brands
SET comparison_tier = CASE market_segment::text
    WHEN 'ultra_fast'   THEN 'mass_market'
    WHEN 'fast_fashion' THEN 'mass_market'
    WHEN 'premium'      THEN 'premium'
    WHEN 'maison'       THEN 'maison'
    ELSE 'mass_market'
  END
WHERE comparison_tier IS NULL;

-- Split 'luxury': contemporary elevato + tecnici-lusso, separati dal premium
-- accessibile (così la lega 'premium' resta coerente con {Suitsupply, COS,
-- Massimo Dutti, Lacoste, Ralph Lauren}). Calibrare con Mattia.
UPDATE public.brands
SET comparison_tier = 'luxury'
WHERE slug IN (
  'theory', 'apc', 'zadig-and-voltaire', 'isabel-marant-etoile',
  'moncler', 'stone-island'
);

-- NOT NULL + default (i futuri INSERT di brand senza tier cadono in mass_market;
-- l'admin può ricurarli).
ALTER TABLE public.brands
  ALTER COLUMN comparison_tier SET DEFAULT 'mass_market';

ALTER TABLE public.brands
  ALTER COLUMN comparison_tier SET NOT NULL;

-- FK verso la lookup (idempotente).
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint WHERE conname = 'brands_comparison_tier_fkey'
  ) THEN
    ALTER TABLE public.brands
      ADD CONSTRAINT brands_comparison_tier_fkey
      FOREIGN KEY (comparison_tier) REFERENCES public.comparison_tiers(key);
  END IF;
END $$;

CREATE INDEX IF NOT EXISTS idx_brands_comparison_tier
  ON public.brands (comparison_tier);

COMMENT ON COLUMN public.brands.comparison_tier IS
  'Lega di confronto del brand (asse del QPR cluster-based, vedi category_tier_aggregates). Editabile. market_segment resta come attributo legacy ma non guida più il QPR.';
