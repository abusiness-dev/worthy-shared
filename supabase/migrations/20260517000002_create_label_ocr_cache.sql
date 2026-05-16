-- Cache OCR per match-product-by-tag.
-- Persiste hash sha256(immagine) + testo estratto + confidence per 24h.
-- Privacy: l'immagine NON viene salvata, solo l'hash.
-- RLS service-role-only: l'edge function ci scrive col service role, il client non accede.

CREATE TABLE IF NOT EXISTS label_ocr_cache (
  image_sha256   char(64)     PRIMARY KEY,
  detected_brand text         NOT NULL DEFAULT '',
  detected_name  text         NOT NULL DEFAULT '',
  confidence     numeric(4,3) NOT NULL CHECK (confidence BETWEEN 0 AND 1),
  model          text         NOT NULL,
  created_at     timestamptz  NOT NULL DEFAULT now(),
  expires_at     timestamptz  NOT NULL DEFAULT now() + interval '24 hours'
);

CREATE INDEX IF NOT EXISTS idx_label_ocr_cache_expires
  ON label_ocr_cache(expires_at);

ALTER TABLE label_ocr_cache ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON label_ocr_cache FROM anon, authenticated;
-- Nessuna policy esplicita: solo service_role accede (bypassa RLS by default).

-- Cleanup periodico delle entry scadute (ogni 6 ore).
SELECT cron.schedule(
  'cleanup-label-ocr-cache',
  '0 */6 * * *',
  $$DELETE FROM label_ocr_cache WHERE expires_at < now()$$
);
