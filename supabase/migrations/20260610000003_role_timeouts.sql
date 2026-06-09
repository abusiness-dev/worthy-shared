-- ════════════════════════════════════════════════════════════════════
-- HARDENING pre-lancio (Wave 1.3) — statement_timeout / idle timeout per-ruolo.
--
-- PROBLEMA:
--   Nessuna migration imposta statement_timeout o idle_in_transaction_session_timeout
--   (grep su 90 migration = 0). A 400k utenti, una singola query lenta (es. una
--   scansione mal-indicizzata o un percentile_cont su cluster grosso) tiene occupato
--   un backend del pool a tempo indefinito; una scrittura bloccata trattiene lock e
--   va in cascata sugli scan concorrenti.
--
-- SOLUZIONE:
--   GUC per-ruolo via ALTER ROLE (applicati ad ogni nuova sessione del ruolo). Una
--   query oltre soglia fallisce pulita (57014) invece di saturare il pool.
--   - authenticated: 8s statement / 15s idle-in-tx
--   - anon:          5s statement / 10s idle-in-tx
--   - service_role:  NON toccato (lo usano i backfill di scoring e worthy-admin, che
--     devono poter girare lunghi).
--
-- NB: in Supabase il pooler (Supavisor/pgbouncer transaction-mode) propaga
--   statement_timeout per-ruolo; idle_in_transaction_session_timeout può variare per
--   modalità. VALIDARE in staging:
--     SELECT rolname, rolconfig FROM pg_roles WHERE rolname IN ('authenticated','anon');
-- ════════════════════════════════════════════════════════════════════

ALTER ROLE authenticated SET statement_timeout = '8s';
ALTER ROLE authenticated SET idle_in_transaction_session_timeout = '15s';

ALTER ROLE anon SET statement_timeout = '5s';
ALTER ROLE anon SET idle_in_transaction_session_timeout = '10s';
