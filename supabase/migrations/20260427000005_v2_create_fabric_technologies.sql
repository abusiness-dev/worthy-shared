-- Worthy Score v2 - Tabella anagrafica tecnologie tessili.
--
-- Risolve l'anomalia "100% poliestere Stone Island = 100% poliestere Shein"
-- del Worthy Score v1. Un capo con tecnologia branded (Polartec, GORE-TEX,
-- PrimaLoft, ECONYL, ...) viene riconosciuto dalla technical_lens (peso 10%
-- sul totale Worthy Score v2) anche se la composizione percentuale è 100%
-- sintetica.
--
-- Lo score è curato basandosi su:
--   - Riconoscimento industriale e accademico
--   - Performance reale (membrane breathable, insulation thermal, abrasion)
--   - Percezione di qualità sul mercato
--
-- I brand "tech proprietary" (Stone Island Lab, Patagonia H2No, C.P. Company)
-- sono inclusi come tecnologie a sé stanti perché producono materiali in-house
-- non standardizzati.

CREATE TABLE fabric_technologies (
  id                 text     PRIMARY KEY,
  display_name       text     NOT NULL,
  brand_owner        text,
  technology_score   smallint NOT NULL CHECK (technology_score BETWEEN 0 AND 100),
  fiber_compatibility text[] NOT NULL DEFAULT '{}'::text[],
  category_hint      text[]   NOT NULL DEFAULT '{}'::text[],
  notes              text
);

COMMENT ON TABLE fabric_technologies IS 'Tecnologie/marchi di tessuti tecnici; alimenta technical_lens.';
COMMENT ON COLUMN fabric_technologies.fiber_compatibility IS 'Su quali fibre la tecnologia si applica (matching con composition.fiber).';
COMMENT ON COLUMN fabric_technologies.category_hint        IS 'Categorie suggerite (giacche, felpe, ...) usate per validazione/UX, non per scoring.';

-- ============================================================
-- Seed
-- ============================================================

-- POLARTEC (US)
INSERT INTO fabric_technologies (id, display_name, brand_owner, technology_score, fiber_compatibility, category_hint, notes) VALUES
  ('polartec_thermal_pro',  'Polartec® Thermal Pro™',  'Polartec LLC', 90, ARRAY['polyester'],          ARRAY['felpe','giacche','piumino'], 'Shearling-style fleece, warmth retention, breathable'),
  ('polartec_power_dry',    'Polartec® Power Dry™',    'Polartec LLC', 85, ARRAY['polyester','nylon'],  ARRAY['t-shirt','felpe'],            'Bi-component knit, moisture-wicking'),
  ('polartec_power_stretch','Polartec® Power Stretch™','Polartec LLC', 85, ARRAY['polyester','nylon','elastane'], ARRAY['felpe','leggings'], '4-way stretch dual-surface'),
  ('polartec_alpha',        'Polartec® Alpha®',         'Polartec LLC', 85, ARRAY['polyester','nylon'],  ARRAY['giacche','piumino'],          'Active insulation breathable'),
  ('polartec_neoshell',     'Polartec® NeoShell®',      'Polartec LLC', 88, ARRAY['polyester','nylon'],  ARRAY['giacche','parka'],            'Soft-shell waterproof breathable');

-- GORE-TEX (W. L. Gore, US)
INSERT INTO fabric_technologies (id, display_name, brand_owner, technology_score, fiber_compatibility, category_hint, notes) VALUES
  ('goretex',          'GORE-TEX®',          'W. L. Gore', 92, ARRAY['polyester','nylon'], ARRAY['giacche','parka','piumino','scarpe-eleganti','sneakers'], 'ePTFE membrane; gold standard waterproof breathable'),
  ('goretex_pro',      'GORE-TEX Pro®',      'W. L. Gore', 95, ARRAY['polyester','nylon'], ARRAY['giacche','parka'], 'Performance estremo per outdoor severo'),
  ('goretex_paclite',  'GORE-TEX Paclite®',  'W. L. Gore', 88, ARRAY['polyester','nylon'], ARRAY['giacche'],          'Lightweight packable variant'),
  ('goretex_infinium', 'GORE-TEX Infinium™', 'W. L. Gore', 82, ARRAY['polyester','nylon'], ARRAY['giacche'],          'Wind/water resistant non-waterproof');

-- SYMPATEX (DE) / EVENT
INSERT INTO fabric_technologies (id, display_name, brand_owner, technology_score, fiber_compatibility, category_hint, notes) VALUES
  ('sympatex',         'Sympatex®',          'Sympatex Technologies', 88, ARRAY['polyester','nylon'], ARRAY['giacche','parka'], 'Membrane PFC-free 100% recyclable; eco-conscious alternative to GORE-TEX'),
  ('event',            'eVent®',             'BHA Technologies',      85, ARRAY['polyester','nylon'], ARRAY['giacche','parka'], 'ePTFE non-fluoropolymeric, no PFC');

-- PERTEX (UK)
INSERT INTO fabric_technologies (id, display_name, brand_owner, technology_score, fiber_compatibility, category_hint, notes) VALUES
  ('pertex_shield',    'Pertex® Shield',     'Pertex (Mitsui)', 85, ARRAY['polyester','nylon'], ARRAY['giacche','piumino'], 'Waterproof breathable woven face'),
  ('pertex_quantum',   'Pertex® Quantum',    'Pertex (Mitsui)', 82, ARRAY['nylon'],             ARRAY['piumino','giacche'], 'Ultralight downproof, used in down jackets'),
  ('pertex_endurance', 'Pertex® Endurance',  'Pertex (Mitsui)', 80, ARRAY['polyester','nylon'], ARRAY['giacche'], NULL);

-- PRIMALOFT (US)
INSERT INTO fabric_technologies (id, display_name, brand_owner, technology_score, fiber_compatibility, category_hint, notes) VALUES
  ('primaloft_gold',   'PrimaLoft® Gold',    'PrimaLoft Inc.', 90, ARRAY['polyester'], ARRAY['piumino','giacche'], 'Down alternative; +14% warmth dry, +24% wet'),
  ('primaloft_silver', 'PrimaLoft® Silver',  'PrimaLoft Inc.', 82, ARRAY['polyester'], ARRAY['piumino','giacche'], NULL),
  ('primaloft_black',  'PrimaLoft® Black',   'PrimaLoft Inc.', 75, ARRAY['polyester'], ARRAY['piumino','giacche'], 'Tier entry-level');

-- INSULATION ALTERNATIVE
INSERT INTO fabric_technologies (id, display_name, brand_owner, technology_score, fiber_compatibility, category_hint, notes) VALUES
  ('thermolite',       'Thermolite®',        'Invista', 75, ARRAY['polyester'], ARRAY['piumino','giacche','t-shirt'], 'Hollow core fibers thermal regulation'),
  ('thinsulate',       'Thinsulate™',        '3M',      78, ARRAY['polyester'], ARRAY['piumino','giacche','calzini'], 'Microfiber insulation thin profile');

-- DURABILITY / ABRASION
INSERT INTO fabric_technologies (id, display_name, brand_owner, technology_score, fiber_compatibility, category_hint, notes) VALUES
  ('cordura',          'CORDURA®',           'Invista',     80, ARRAY['nylon','polyester'],   ARRAY['giacche','pantaloni','cargo','borse'], 'High-tenacity yarn, abrasion-resistant; rPET version available'),
  ('dyneema',          'Dyneema®',           'DSM',         92, ARRAY['polyester','nylon'],   ARRAY['giacche','borse'], 'UHMWPE; tensile strength estremo, ultralight');

-- MOISTURE / TEMPERATURE MGMT
INSERT INTO fabric_technologies (id, display_name, brand_owner, technology_score, fiber_compatibility, category_hint, notes) VALUES
  ('coolmax',          'Coolmax®',           'Invista',     78, ARRAY['polyester'],            ARRAY['t-shirt','calzini','intimo'],          'Four-pipe fiber moisture transmission'),
  ('outlast',          'Outlast®',           'Outlast Tech', 75, ARRAY['polyester','nylon'],  ARRAY['t-shirt','intimo','felpe'],             'PCM phase change material thermal balance');

-- SCHOELLER (CH)
INSERT INTO fabric_technologies (id, display_name, brand_owner, technology_score, fiber_compatibility, category_hint, notes) VALUES
  ('schoeller_c_change','Schoeller® c_change®','Schoeller', 90, ARRAY['polyester','nylon','elastane'], ARRAY['giacche','pantaloni','blazer'], 'Adaptive membrane temperature/humidity'),
  ('schoeller_dynamic', 'Schoeller® Dynamic',  'Schoeller', 85, ARRAY['polyester','nylon','elastane'], ARRAY['pantaloni','blazer','giacche'],  'Stretch performance fabric');

-- ECONYL (IT, Aquafil) - regenerated nylon (anche in fiber_origins ma è anche un branded fabric)
INSERT INTO fabric_technologies (id, display_name, brand_owner, technology_score, fiber_compatibility, category_hint, notes) VALUES
  ('econyl',           'ECONYL®',            'Aquafil',     82, ARRAY['nylon'], ARRAY['costume','giacche','leggings','top-sportivo'], 'Italian regenerated nylon from fishing nets/fabric scraps');

-- BRAND PROPRIETARY (Stone Island, Patagonia, C.P. Company)
INSERT INTO fabric_technologies (id, display_name, brand_owner, technology_score, fiber_compatibility, category_hint, notes) VALUES
  ('stone_island_lab',     'Stone Island Lab proprietary',         'Stone Island', 90, ARRAY['polyester','nylon','cotton','wool'], ARRAY['giacche','felpe','parka','bomber'], 'In-house Ghost Piece, Reflective Fabric, ICE Jacket Thermosensitive, Alcantara® applications'),
  ('cp_company_proprietary','C.P. Company proprietary',            'C.P. Company', 85, ARRAY['polyester','nylon','cotton'],         ARRAY['giacche','bomber','parka'],          'Garment dyeing tradition + Goggle Jacket fabric innovations'),
  ('patagonia_h2no',       'Patagonia H2No® Performance Standard', 'Patagonia',    85, ARRAY['polyester','nylon'],                  ARRAY['giacche','parka'],                    'Proprietary waterproof/breathable; Torrentshell line'),
  ('patagonia_capilene',   'Patagonia Capilene®',                  'Patagonia',    80, ARRAY['polyester'],                          ARRAY['t-shirt','intimo'],                   'Polyester base layer technology');

-- WAXED COTTON (Barbour)
INSERT INTO fabric_technologies (id, display_name, brand_owner, technology_score, fiber_compatibility, category_hint, notes) VALUES
  ('barbour_sylkoil_wax',   'Barbour Sylkoil Wax',     'Barbour', 78, ARRAY['cotton'], ARRAY['giacche','parka','bomber'], 'Unshorn cotton waxed; matte finish; soften over time'),
  ('barbour_thornproof_wax','Barbour Thornproof Wax',  'Barbour', 78, ARRAY['cotton'], ARRAY['giacche','parka'],          'Calendered wax, glossy finish');

-- TREATMENTS GENERICI (DWR water repellent, anti-odor)
INSERT INTO fabric_technologies (id, display_name, brand_owner, technology_score, fiber_compatibility, category_hint, notes) VALUES
  ('dwr_pfc_free',     'DWR (PFC-free)',     NULL, 65, ARRAY['polyester','nylon','cotton'], ARRAY['giacche','parka','pantaloni'], 'Durable Water Repellent senza PFC');
