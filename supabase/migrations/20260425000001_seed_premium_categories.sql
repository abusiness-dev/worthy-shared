-- Aggiunge 3 categorie premium per supportare brand sartoriali (SUITSUPPLY,
-- Brioni, Boggi, Burberry, Mackintosh ecc):
--   - abito: completo giacca+pantalone, distinto da blazer (giacca singola)
--   - cappotto: outerwear lungo (peacoat, caban), distinto da bomber/giubbotto
--   - trench: impermeabile lungo cotone/poly, distinto da parka/giubbotto
--
-- Idempotente: ON CONFLICT (slug) DO NOTHING. avg_price/avg_composition_score
-- riflettono la fascia premium (lana, cashmere, cotone tecnico).

INSERT INTO categories (id, name, slug, icon, avg_price, avg_composition_score) VALUES
  (gen_random_uuid(), 'Abiti',     'abito',    '🤵', 599.00, 75.00),
  (gen_random_uuid(), 'Cappotti',  'cappotto', '🧥', 549.00, 78.00),
  (gen_random_uuid(), 'Trench',    'trench',   '🧥', 399.00, 65.00)
ON CONFLICT (slug) DO NOTHING;
