-- Espansione massiccia del catalogo brand: porta il database da 12 a 70+ brand.
-- Copre tre segmenti: fast_fashion (mass-market), premium (contemporary/designer
-- accessibile) e maison (lusso/alta moda).
-- Idempotente: ON CONFLICT (slug) DO NOTHING, i brand già presenti nel seed
-- originale (zara, h-and-m, uniqlo, shein, bershka, pull-and-bear, stradivarius,
-- primark, asos, mango, cos, massimo-dutti) non vengono duplicati né alterati.

INSERT INTO brands (id, name, slug, description, origin_country, market_segment) VALUES

  -- ============================================================
  -- FAST FASHION
  -- ============================================================
  (gen_random_uuid(), 'Zara',            'zara',            'Ammiraglia spagnola del gruppo Inditex, pioniera del fast fashion globale con rotazione settimanale delle collezioni.', 'Spain',       'fast_fashion'),
  (gen_random_uuid(), 'H&M',             'h-and-m',         'Colosso svedese del fast fashion, offerta democratica con collezioni capsule di alto profilo.',                       'Sweden',      'fast_fashion'),
  (gen_random_uuid(), 'Uniqlo',          'uniqlo',          'Brand giapponese di basics tecnici, focus sulla qualità dei tessuti LifeWear a prezzi accessibili.',                  'Japan',       'fast_fashion'),
  (gen_random_uuid(), 'Shein',           'shein',           'Gigante cinese dell''ultra fast fashion online, assortimento sconfinato e prezzi stracciati con forte impatto ambientale.', 'China',  'fast_fashion'),
  (gen_random_uuid(), 'Primark',         'primark',         'Catena irlandese di ultra fast fashion offline, prezzi tra i più bassi del mercato europeo.',                        'Ireland',     'fast_fashion'),
  (gen_random_uuid(), 'Bershka',         'bershka',         'Brand Inditex rivolto alla Gen Z, streetwear e trend urban a prezzi aggressivi.',                                    'Spain',       'fast_fashion'),
  (gen_random_uuid(), 'Pull&Bear',       'pull-and-bear',   'Brand Inditex dall''anima casual-giovane, ispirazione californiana e skate culture.',                                'Spain',       'fast_fashion'),
  (gen_random_uuid(), 'Stradivarius',    'stradivarius',    'Brand femminile del gruppo Inditex, trend-driven con prezzi da fast fashion.',                                       'Spain',       'fast_fashion'),
  (gen_random_uuid(), 'Reserved',        'reserved',        'Flagship del gruppo polacco LPP, fast fashion contemporaneo per tutta la famiglia.',                                 'Poland',      'fast_fashion'),
  (gen_random_uuid(), 'Sinsay',          'sinsay',          'Brand ultra fast fashion di LPP, prezzi bassissimi e collezioni trend-driven per teenager.',                         'Poland',      'fast_fashion'),
  (gen_random_uuid(), 'C&A',             'c-and-a',         'Storico retailer europeo di fast fashion, focus su basics democratici e linee di cotone sostenibile.',               'Germany',     'fast_fashion'),
  (gen_random_uuid(), 'Kiabi',           'kiabi',           'Catena francese di fast fashion low-cost pensata per famiglie con budget contenuti.',                                'France',      'fast_fashion'),
  (gen_random_uuid(), 'OVS',             'ovs',             'Leader italiano del fast fashion, assortimento famiglia con crescente focus su materiali sostenibili.',               'Italy',       'fast_fashion'),
  (gen_random_uuid(), 'Tezenis',         'tezenis',         'Brand italiano del gruppo Calzedonia, intimo e homewear giovane a prezzi contenuti.',                                'Italy',       'fast_fashion'),
  (gen_random_uuid(), 'Alcott',          'alcott',          'Fast fashion italiano con target teen, stile casual e streetwear a prezzi aggressivi.',                              'Italy',       'fast_fashion'),
  (gen_random_uuid(), 'Terranova',       'terranova',       'Catena italiana di fast fashion con offerta basic e trend a prezzi molto contenuti.',                                'Italy',       'fast_fashion'),
  (gen_random_uuid(), 'Subdued',         'subdued',         'Brand italiano indipendente amato dalle teenager, estetica Y2K e prezzi fast fashion.',                              'Italy',       'fast_fashion'),
  (gen_random_uuid(), 'Weekday',         'weekday',         'Label svedese del gruppo H&M focalizzata su denim e streetwear dall''anima scandinava.',                             'Sweden',      'fast_fashion'),
  (gen_random_uuid(), 'Monki',           'monki',           'Brand svedese del gruppo H&M con stile giocoso e colorato rivolto al pubblico Gen Z.',                               'Sweden',      'fast_fashion'),
  (gen_random_uuid(), 'ASOS',            'asos',            'Retailer online britannico di fast fashion, catalogo multi-brand con forte identità Gen Z.',                         'United Kingdom', 'fast_fashion'),
  (gen_random_uuid(), 'Mango',           'mango',           'Brand spagnolo di fast fashion dall''estetica mediterranea, posizionato un gradino sopra il mass-market puro.',       'Spain',       'fast_fashion'),
  (gen_random_uuid(), 'Arket',           'arket',           'Label del gruppo H&M di fascia alta, estetica minimal scandinava e maggiore attenzione ai materiali.',               'Sweden',      'fast_fashion'),
  (gen_random_uuid(), '& Other Stories', 'and-other-stories','Brand femminile del gruppo H&M, collezioni curate con feeling boutique e design atelier-like.',                      'Sweden',      'fast_fashion'),
  (gen_random_uuid(), 'Calzedonia',      'calzedonia',      'Colosso italiano di calzetteria e beachwear, distribuzione capillare e prezzi mid-market.',                          'Italy',       'fast_fashion'),
  (gen_random_uuid(), 'Intimissimi',     'intimissimi',     'Marchio italiano del gruppo Calzedonia specializzato in lingerie e homewear accessibile.',                           'Italy',       'fast_fashion'),
  (gen_random_uuid(), 'Nike',            'nike',            'Gigante americano dello sportswear, leader mondiale in sneakers e abbigliamento atletico-lifestyle.',                'United States','fast_fashion'),
  (gen_random_uuid(), 'Adidas',          'adidas',          'Multinazionale tedesca dello sportswear, icona delle sneakers e delle collaborazioni fashion.',                      'Germany',     'fast_fashion'),
  (gen_random_uuid(), 'Puma',            'puma',            'Sportswear brand tedesco con forte focus su lifestyle e collaborazioni celebrity.',                                  'Germany',     'fast_fashion'),
  (gen_random_uuid(), 'New Balance',     'new-balance',     'Storico produttore americano di sneakers, reputazione di qualità con linee made in USA e UK.',                       'United States','fast_fashion'),
  (gen_random_uuid(), 'Levi''s',         'levis',           'Icona americana del denim dal 1853, riferimento mondiale per jeans e workwear.',                                     'United States','fast_fashion'),
  (gen_random_uuid(), 'Guess',           'guess',           'Brand americano premium-fast, denim e glamour californiano dai tempi degli anni ''80.',                              'United States','fast_fashion'),
  (gen_random_uuid(), 'Desigual',        'desigual',        'Brand spagnolo noto per le stampe colorate e lo stile eclettico mediterraneo.',                                      'Spain',       'fast_fashion'),
  (gen_random_uuid(), 'Brandy Melville', 'brandy-melville', 'Brand italo-americano amato dalla Gen Z, estetica californiana e controversa taglia unica.',                         'Italy',       'fast_fashion'),

  -- ============================================================
  -- PREMIUM
  -- ============================================================
  (gen_random_uuid(), 'COS',                   'cos',                   'Brand premium del gruppo H&M, estetica architettonica e minimalismo scandinavo.',                           'Sweden',         'premium'),
  (gen_random_uuid(), 'Massimo Dutti',         'massimo-dutti',         'Brand premium del gruppo Inditex, sartoria accessibile e stile classico-contemporaneo.',                   'Spain',          'premium'),
  (gen_random_uuid(), 'Suitsupply',            'suitsupply',            'Brand olandese di sartoria maschile accessibile, taglio italiano e filati di qualità.',                    'Netherlands',    'premium'),
  (gen_random_uuid(), 'Tommy Hilfiger',        'tommy-hilfiger',        'Lifestyle brand americano preppy, icona del casualwear premium con forte heritage East Coast.',           'United States',  'premium'),
  (gen_random_uuid(), 'Calvin Klein',          'calvin-klein',          'Brand americano minimalista, pilastro del lusso accessibile tra denim, intimo e ready-to-wear.',          'United States',  'premium'),
  (gen_random_uuid(), 'Ralph Lauren',          'ralph-lauren',          'Casa americana simbolo dell''eleganza preppy, dal polo iconico al ready-to-wear sofisticato.',             'United States',  'premium'),
  (gen_random_uuid(), 'American Vintage',      'american-vintage',      'Brand francese di knitwear e basics dai tessuti morbidi, estetica parigina rilassata.',                   'France',         'premium'),
  (gen_random_uuid(), 'Sandro',                'sandro',                'Contemporary brand parigino, chic effortless con prezzi premium accessibili.',                             'France',         'premium'),
  (gen_random_uuid(), 'Maje',                  'maje',                  'Label francese femminile dallo stile parigino boho-chic, forte presenza retail internazionale.',        'France',         'premium'),
  (gen_random_uuid(), 'Hugo Boss',             'hugo-boss',             'Casa tedesca di abbigliamento formale, sartoria business e linea Hugo più giovane.',                      'Germany',        'premium'),
  (gen_random_uuid(), 'Ted Baker',             'ted-baker',             'Brand britannico eccentrico, tailoring colorato con dettagli lavorati e grafica distintiva.',            'United Kingdom', 'premium'),
  (gen_random_uuid(), 'Reiss',                 'reiss',                 'Brand britannico di contemporary tailoring, capi versatili tra ufficio e sera.',                           'United Kingdom', 'premium'),
  (gen_random_uuid(), 'AllSaints',             'allsaints',             'Label londinese rock-luxe, celebre per pelle, denim grezzo e maglieria destrutturata.',                  'United Kingdom', 'premium'),
  (gen_random_uuid(), 'Theory',                'theory',                'Brand newyorkese minimalista, sartoria contemporary con focus sui tessuti tecnici.',                       'United States',  'premium'),
  (gen_random_uuid(), 'Zadig & Voltaire',      'zadig-and-voltaire',    'Maison parigina rock-chic, cashmere ricercato e grafismi iconici.',                                        'France',         'premium'),
  (gen_random_uuid(), 'Isabel Marant Étoile',  'isabel-marant-etoile',  'Linea diffusion della designer parigina, boho borghese a prezzi più accessibili.',                        'France',         'premium'),
  (gen_random_uuid(), 'A.P.C.',                'apc',                   'Cult brand parigino di denim raw e basics, estetica minimale e qualità premium.',                         'France',         'premium'),

  -- ============================================================
  -- MAISON
  -- ============================================================
  (gen_random_uuid(), 'Ermenegildo Zegna',         'ermenegildo-zegna',         'Maison italiana del lusso maschile, leader mondiale nella lana tracciata e nella sartoria industriale.',  'Italy',          'maison'),
  (gen_random_uuid(), 'Loro Piana',                'loro-piana',                'Maison italiana sinonimo di lusso discreto, celebre per cashmere, vicuña e fibre pregiate.',              'Italy',          'maison'),
  (gen_random_uuid(), 'Brunello Cucinelli',        'brunello-cucinelli',        'Maison del "lusso umanistico" da Solomeo, cashmere di altissima gamma e artigianalità italiana.',          'Italy',          'maison'),
  (gen_random_uuid(), 'Giorgio Armani',            'giorgio-armani',            'Maison italiana icona della sartoria destrutturata, eleganza pulita e raffinata.',                           'Italy',          'maison'),
  (gen_random_uuid(), 'Ralph Lauren Purple Label', 'ralph-lauren-purple-label', 'Linea top di Ralph Lauren, sartoria uomo di altissima gamma prodotta in Italia.',                           'United States',  'maison'),
  (gen_random_uuid(), 'Kiton',                     'kiton',                     'Maison napoletana del lusso maschile, sartoria hand-made ai vertici mondiali.',                              'Italy',          'maison'),
  (gen_random_uuid(), 'Saint Laurent',             'saint-laurent',             'Maison parigina del gruppo Kering, rock chic e tailoring seducente.',                                        'France',         'maison'),
  (gen_random_uuid(), 'Gucci',                     'gucci',                     'Maison fiorentina del gruppo Kering, riferimento globale del lusso italiano contemporaneo.',                'Italy',          'maison'),
  (gen_random_uuid(), 'Prada',                     'prada',                     'Maison milanese iconica per il suo minimalismo intellettuale e l''innovazione tessile.',                    'Italy',          'maison'),
  (gen_random_uuid(), 'Bottega Veneta',            'bottega-veneta',            'Maison veneta del quiet luxury, celebre per la pelle intrecciata e il lusso silenzioso.',                    'Italy',          'maison'),
  (gen_random_uuid(), 'Valentino',                 'valentino',                 'Maison romana dell''alta moda, celebre per il rosso iconico e l''haute couture.',                            'Italy',          'maison'),
  (gen_random_uuid(), 'Balenciaga',                'balenciaga',                'Maison del gruppo Kering, avanguardia e sovversione del lusso contemporaneo.',                               'France',         'maison'),
  (gen_random_uuid(), 'Burberry',                  'burberry',                  'Casa britannica storica, trench iconici e check riconoscibile a livello mondiale.',                          'United Kingdom', 'maison'),
  (gen_random_uuid(), 'Dior Homme',                'dior-homme',                'Linea maschile della maison parigina sotto LVMH, sartoria di lusso e direzione creativa d''autore.',        'France',         'maison'),
  (gen_random_uuid(), 'Tom Ford',                  'tom-ford',                  'Brand americano di lusso glamour, sartoria sensuale e accessori high-end.',                                  'United States',  'maison'),
  (gen_random_uuid(), 'Hermès',                    'hermes',                    'Maison parigina vertice del lusso, pelletteria e sartoria artigianale da oltre 185 anni.',                   'France',         'maison'),
  (gen_random_uuid(), 'Louis Vuitton',             'louis-vuitton',             'Maison francese del gruppo LVMH, riferimento globale per pelletteria e lusso travel.',                       'France',         'maison'),
  (gen_random_uuid(), 'Fendi',                     'fendi',                     'Maison romana del gruppo LVMH, sinonimo di pellicce e pelletteria di lusso.',                                'Italy',          'maison'),
  (gen_random_uuid(), 'Versace',                   'versace',                   'Maison milanese iconica, massimalismo barocco e glamour mediterraneo.',                                      'Italy',          'maison'),
  (gen_random_uuid(), 'Dolce & Gabbana',           'dolce-and-gabbana',         'Maison italiana barocca e sensuale, immaginario mediterraneo e sartoria couture.',                           'Italy',          'maison'),
  (gen_random_uuid(), 'Moncler',                   'moncler',                   'Brand italiano del piumino di lusso, outerwear performance diventato icona fashion.',                        'Italy',          'maison'),
  (gen_random_uuid(), 'Stone Island',              'stone-island',              'Brand italiano del lusso tecnico, ricerca sui tessuti e sulle tinture a livelli industriali.',              'Italy',          'maison'),
  (gen_random_uuid(), 'Loewe',                     'loewe',                     'Maison spagnola del gruppo LVMH, pelletteria artigianale e direzione creativa di JW Anderson.',             'Spain',          'maison'),
  (gen_random_uuid(), 'Brioni',                    'brioni',                    'Maison romana della sartoria uomo, icona dell''abito su misura da oltre 75 anni.',                           'Italy',          'maison'),
  (gen_random_uuid(), 'Canali',                    'canali',                    'Maison italiana di sartoria maschile, formalwear made in Italy di alta gamma.'                              ,'Italy',          'maison')

ON CONFLICT (slug) DO NOTHING;
