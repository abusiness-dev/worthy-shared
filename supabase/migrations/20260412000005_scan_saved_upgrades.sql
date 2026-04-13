-- Upgrade non-distruttivo per scan_history e saved_products.
-- Lo schema esistente è preservato (colonne, nomi, tipi enum) per non rompere
-- il codice già in uso. Aggiungiamo solo:
--   1) Indice (user_id, created_at DESC) su scan_history per la cronologia personale
--      (esiste già un indice su (product_id, created_at DESC), ma non su user_id)
--   2) Indice (user_id, created_at DESC) su saved_products per listare i salvati
--      dell'utente ordinati cronologicamente
--   3) Policy RLS DELETE su scan_history (mancante): consente all'utente di
--      cancellare le proprie voci di cronologia

CREATE INDEX IF NOT EXISTS idx_scan_history_user_date
  ON scan_history(user_id, created_at DESC);

CREATE INDEX IF NOT EXISTS idx_saved_products_user_date
  ON saved_products(user_id, created_at DESC);

CREATE POLICY "scan_history_delete_own"
  ON scan_history FOR DELETE
  TO authenticated
  USING (auth.uid() = user_id);
