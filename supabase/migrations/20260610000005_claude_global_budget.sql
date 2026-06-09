-- ════════════════════════════════════════════════════════════════════
-- HARDENING pre-lancio (Wave 1.5) — tetto di spesa GLOBALE sulla Claude API +
-- kill-switch OCR.
--
-- PROBLEMA:
--   scan-label e match-product-by-tag chiamano Claude (a nostro carico) protette
--   SOLO dal throttle per-(utente,funzione). Il cap per-utente NON si aggrega: uno
--   spike virale o un abuso coordinato su molti account autenticati (la registrazione
--   è aperta) può far esplodere la spesa Anthropic.
--
-- SOLUZIONE:
--   - claude_usage_counter: contatore atomico per (finestra oraria × funzione).
--   - app_settings: kill-switch `ocr_enabled` + cap orari configurabili SENZA redeploy.
--   - check_and_record_global_budget(p_function, p_window_minutes): SECURITY DEFINER,
--     atomica via INSERT…ON CONFLICT…RETURNING; legge kill-switch + cap da app_settings;
--     ritorna false se OCR spento o oltre soglia. Chiamata dalle edge function PRIMA del
--     fetch a Claude (in match-product-by-tag solo nel ramo cache-miss).
--   - Tutto bloccato a service_role (come check_and_record_throttle): le edge function
--     usano la service key.
--
-- VALIDARE: rpc come authenticated → "permission denied"; come service_role la 1ª
--   chiamata ritorna true e incrementa n; superato il cap → false; `UPDATE app_settings
--   SET value='false' WHERE key='ocr_enabled'` → la RPC ritorna false (kill-switch).
-- ════════════════════════════════════════════════════════════════════

-- ============================================================
-- 1. app_settings (feature-flag / config runtime, key→jsonb)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.app_settings (
  key        text PRIMARY KEY,
  value      jsonb NOT NULL,
  updated_at timestamptz NOT NULL DEFAULT now()
);

COMMENT ON TABLE public.app_settings IS
  'Config/feature-flag runtime (key→jsonb). Scrivibile solo da service_role (worthy-admin). Letta dalle funzioni SECURITY DEFINER.';

ALTER TABLE public.app_settings ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.app_settings FROM anon, authenticated;
-- Nessuna policy: solo service_role (bypassa RLS) e le SECURITY DEFINER fn accedono.

INSERT INTO public.app_settings (key, value) VALUES
  ('ocr_enabled',                       'true'::jsonb),
  ('claude_budget_scan-label_hourly',   '600'::jsonb),
  ('claude_budget_match-product-by-tag_hourly', '600'::jsonb)
ON CONFLICT (key) DO NOTHING;

-- ============================================================
-- 2. claude_usage_counter (contatore per finestra × funzione)
-- ============================================================

CREATE TABLE IF NOT EXISTS public.claude_usage_counter (
  window_start  timestamptz NOT NULL,
  function_name text        NOT NULL,
  n             int         NOT NULL DEFAULT 0,
  PRIMARY KEY (window_start, function_name)
);

COMMENT ON TABLE public.claude_usage_counter IS
  'Contatore atomico delle chiamate Claude per finestra oraria × funzione. Alimenta il cap di spesa globale. Potato da cron.';

ALTER TABLE public.claude_usage_counter ENABLE ROW LEVEL SECURITY;
REVOKE ALL ON public.claude_usage_counter FROM anon, authenticated;

-- ============================================================
-- 3. RPC atomica: kill-switch + cap globale
-- ============================================================

CREATE OR REPLACE FUNCTION public.check_and_record_global_budget(
  p_function       text,
  p_window_minutes int DEFAULT 60
)
RETURNS boolean
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
  v_enabled      boolean;
  v_max          int;
  v_window_start timestamptz;
  v_n            int;
BEGIN
  -- Kill-switch globale OCR (default acceso se la riga manca).
  SELECT (value #>> '{}')::boolean INTO v_enabled
  FROM app_settings WHERE key = 'ocr_enabled';
  IF v_enabled IS NOT NULL AND v_enabled = false THEN
    RETURN false;
  END IF;

  -- Cap orario per-funzione (default prudente se non configurato).
  SELECT (value #>> '{}')::int INTO v_max
  FROM app_settings WHERE key = 'claude_budget_' || p_function || '_hourly';
  v_max := coalesce(v_max, 600);

  -- Finestra allineata all'ora (p_window_minutes informativo; il bucket è orario).
  v_window_start := date_trunc('hour', now());

  INSERT INTO claude_usage_counter (window_start, function_name, n)
  VALUES (v_window_start, p_function, 1)
  ON CONFLICT (window_start, function_name)
  DO UPDATE SET n = claude_usage_counter.n + 1
  RETURNING n INTO v_n;

  RETURN v_n <= v_max;
END;
$$;

COMMENT ON FUNCTION public.check_and_record_global_budget IS
  'Cap di spesa GLOBALE Claude: legge kill-switch + cap orario da app_settings, incrementa atomicamente claude_usage_counter, ritorna false se OCR spento o oltre soglia. Da chiamare PRIMA del fetch a Claude.';

REVOKE ALL ON FUNCTION public.check_and_record_global_budget(text, int)
  FROM PUBLIC, anon, authenticated;
GRANT EXECUTE ON FUNCTION public.check_and_record_global_budget(text, int)
  TO service_role;

-- ============================================================
-- 4. Cron cleanup contatori vecchi
-- ============================================================

SELECT cron.schedule(
  'cleanup-claude-usage',
  '17 * * * *',
  $$DELETE FROM claude_usage_counter WHERE window_start < now() - interval '7 days'$$
);
