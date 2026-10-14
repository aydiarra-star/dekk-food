-- =============================================================================
-- DEKK FOOD / DAKA FOOD — Référentiel national (données de référence)
-- 14 régions, 46 départements, communes/quartiers, nomenclatures et sources.
-- Ce fichier ne contient AUCUN restaurant : il ne décrit que le référentiel.
-- =============================================================================

-- -----------------------------------------------------------------------------
-- 1. Les 14 régions du Sénégal
-- -----------------------------------------------------------------------------
insert into public.regions (id, code, nom, chef_lieu) values
  (1,  'DK', 'Dakar',        'Dakar'),
  (2,  'DB', 'Diourbel',     'Diourbel'),
  (3,  'FK', 'Fatick',       'Fatick'),
  (4,  'KA', 'Kaffrine',     'Kaffrine'),
  (5,  'KL', 'Kaolack',      'Kaolack'),
  (6,  'KE', 'Kédougou',     'Kédougou'),
  (7,  'KD', 'Kolda',        'Kolda'),
  (8,  'LG', 'Louga',        'Louga'),
  (9,  'MT', 'Matam',        'Matam'),
  (10, 'SL', 'Saint-Louis',  'Saint-Louis'),
  (11, 'SE', 'Sédhiou',      'Sédhiou'),
  (12, 'TC', 'Tambacounda',  'Tambacounda'),
  (13, 'TH', 'Thiès',        'Thiès'),
  (14, 'ZG', 'Ziguinchor',   'Ziguinchor')
on conflict (id) do update set nom = excluded.nom, chef_lieu = excluded.chef_lieu, code = excluded.code;

select setval(pg_get_serial_sequence('public.regions', 'id'), (select max(id) from public.regions));

-- -----------------------------------------------------------------------------
-- 2. Les 46 départements (découpage administratif en vigueur, Keur Massar inclus)
-- -----------------------------------------------------------------------------
insert into public.departements (region_id, code, nom) values
  -- Dakar (5)
  (1, 'DK-DAKAR',   'Dakar'),
  (1, 'DK-GUEDIAWAYE', 'Guédiawaye'),
  (1, 'DK-PIKINE',  'Pikine'),
  (1, 'DK-KEURMASSAR', 'Keur Massar'),
  (1, 'DK-RUFISQUE', 'Rufisque'),
  -- Diourbel (3)
  (2, 'DB-BAMBEY',  'Bambey'),
  (2, 'DB-DIOURBEL', 'Diourbel'),
  (2, 'DB-MBACKE',  'Mbacké'),
  -- Fatick (3)
  (3, 'FK-FATICK',  'Fatick'),
  (3, 'FK-FOUNDIOUGNE', 'Foundiougne'),
  (3, 'FK-GOSSAS',  'Gossas'),
  -- Kaffrine (4)
  (4, 'KA-BIRKELANE', 'Birkelane'),
  (4, 'KA-KAFFRINE', 'Kaffrine'),
  (4, 'KA-KOUNGHEUL', 'Koungheul'),
  (4, 'KA-MALEMHODAR', 'Malem Hodar'),
  -- Kaolack (3)
  (5, 'KL-GUINGUINEO', 'Guinguinéo'),
  (5, 'KL-KAOLACK',  'Kaolack'),
  (5, 'KL-NIORO',    'Nioro du Rip'),
  -- Kédougou (3)
  (6, 'KE-KEDOUGOU', 'Kédougou'),
  (6, 'KE-SALEMATA', 'Salémata'),
  (6, 'KE-SARAYA',   'Saraya'),
  -- Kolda (3)
  (7, 'KD-KOLDA',    'Kolda'),
  (7, 'KD-MEDINAYORO', 'Médina Yoro Foulah'),
  (7, 'KD-VELINGARA', 'Vélingara'),
  -- Louga (3)
  (8, 'LG-KEBEMER',  'Kébémer'),
  (8, 'LG-LINGUERE', 'Linguère'),
  (8, 'LG-LOUGA',    'Louga'),
  -- Matam (3)
  (9, 'MT-KANEL',    'Kanel'),
  (9, 'MT-MATAM',    'Matam'),
  (9, 'MT-RANEROU',  'Ranérou Ferlo'),
  -- Saint-Louis (3)
  (10, 'SL-DAGANA',  'Dagana'),
  (10, 'SL-PODOR',   'Podor'),
  (10, 'SL-SAINTLOUIS', 'Saint-Louis'),
  -- Sédhiou (3)
  (11, 'SE-BOUNKILING', 'Bounkiling'),
  (11, 'SE-GOUDOMP', 'Goudomp'),
  (11, 'SE-SEDHIOU', 'Sédhiou'),
  -- Tambacounda (4)
  (12, 'TC-BAKEL',   'Bakel'),
  (12, 'TC-GOUDIRY', 'Goudiry'),
  (12, 'TC-KOUMPENTOUM', 'Koumpentoum'),
  (12, 'TC-TAMBACOUNDA', 'Tambacounda'),
  -- Thiès (3)
  (13, 'TH-MBOUR',   'Mbour'),
  (13, 'TH-THIES',   'Thiès'),
  (13, 'TH-TIVAOUANE', 'Tivaouane'),
  -- Ziguinchor (3)
  (14, 'ZG-BIGNONA', 'Bignona'),
  (14, 'ZG-OUSSOUYE', 'Oussouye'),
  (14, 'ZG-ZIGUINCHOR', 'Ziguinchor')
on conflict (code) do update set nom = excluded.nom, region_id = excluded.region_id;

-- -----------------------------------------------------------------------------
-- 3. Communes et villes (chefs-lieux + localités de collecte)
--    Extensible : chaque nouvelle localité collectée est ajoutée ici.
-- -----------------------------------------------------------------------------
insert into public.communes (departement_id, nom, type)
select d.id, v.nom, v.type
from (values
  -- Dakar
  ('DK-DAKAR', 'Dakar Plateau', 'commune'), ('DK-DAKAR', 'Médina', 'commune'),
  ('DK-DAKAR', 'Fann-Point E-Amitié', 'commune'), ('DK-DAKAR', 'Mermoz-Sacré-Cœur', 'commune'),
  ('DK-DAKAR', 'Ouakam', 'commune'), ('DK-DAKAR', 'Ngor', 'commune'), ('DK-DAKAR', 'Yoff', 'commune'),
  ('DK-DAKAR', 'Grand Dakar', 'commune'), ('DK-DAKAR', 'Biscuiterie', 'commune'),
  ('DK-DAKAR', 'Dieuppeul-Derklé', 'commune'), ('DK-DAKAR', 'Hann Bel-Air', 'commune'),
  ('DK-DAKAR', 'Sicap-Liberté', 'commune'), ('DK-DAKAR', 'HLM', 'commune'),
  ('DK-DAKAR', 'Grand Yoff', 'commune'), ('DK-DAKAR', 'Patte d''Oie', 'commune'),
  ('DK-DAKAR', 'Cambérène', 'commune'), ('DK-DAKAR', 'Gueule Tapée-Fass-Colobane', 'commune'),
  ('DK-GUEDIAWAYE', 'Guédiawaye', 'commune'), ('DK-GUEDIAWAYE', 'Golf Sud', 'commune'),
  ('DK-GUEDIAWAYE', 'Médina Gounass', 'commune'), ('DK-GUEDIAWAYE', 'Wakhinane Nimzatt', 'commune'),
  ('DK-GUEDIAWAYE', 'Sahm Notaire', 'commune'),
  ('DK-PIKINE', 'Pikine', 'commune'), ('DK-PIKINE', 'Thiaroye-sur-Mer', 'commune'),
  ('DK-PIKINE', 'Thiaroye Gare', 'commune'), ('DK-PIKINE', 'Diamaguène', 'commune'),
  ('DK-PIKINE', 'Mbao', 'commune'), ('DK-PIKINE', 'Keur Massar', 'commune'),
  ('DK-PIKINE', 'Malika', 'commune'), ('DK-PIKINE', 'Yeumbeul', 'commune'),
  ('DK-KEURMASSAR', 'Keur Massar Nord', 'commune'), ('DK-KEURMASSAR', 'Keur Massar Sud', 'commune'),
  ('DK-KEURMASSAR', 'Malika', 'commune'), ('DK-KEURMASSAR', 'Yeumbeul Nord', 'commune'),
  ('DK-RUFISQUE', 'Rufisque Est', 'commune'), ('DK-RUFISQUE', 'Rufisque Nord', 'commune'),
  ('DK-RUFISQUE', 'Rufisque Ouest', 'commune'), ('DK-RUFISQUE', 'Bargny', 'commune'),
  ('DK-RUFISQUE', 'Diamniadio', 'commune'), ('DK-RUFISQUE', 'Sébikotane', 'commune'),
  ('DK-RUFISQUE', 'Sangalkam', 'commune'), ('DK-RUFISQUE', 'Yène', 'commune'),
  ('DK-RUFISQUE', 'Bambilor', 'commune'), ('DK-RUFISQUE', 'Sendou', 'commune'),
  -- Diourbel
  ('DB-DIOURBEL', 'Diourbel', 'commune'), ('DB-DIOURBEL', 'Ndoulo', 'commune'),
  ('DB-MBACKE', 'Mbacké', 'commune'), ('DB-MBACKE', 'Touba Mosquée', 'commune'),
  ('DB-MBACKE', 'Taïf', 'commune'), ('DB-BAMBEY', 'Bambey', 'commune'),
  ('DB-BAMBEY', 'Baba Garage', 'commune'),
  -- Fatick
  ('FK-FATICK', 'Fatick', 'commune'), ('FK-FATICK', 'Diofior', 'commune'),
  ('FK-FOUNDIOUGNE', 'Foundiougne', 'commune'), ('FK-FOUNDIOUGNE', 'Sokone', 'commune'),
  ('FK-FOUNDIOUGNE', 'Karang Poste', 'commune'), ('FK-GOSSAS', 'Gossas', 'commune'),
  -- Kaffrine
  ('KA-KAFFRINE', 'Kaffrine', 'commune'), ('KA-KAFFRINE', 'Nganda', 'commune'),
  ('KA-KOUNGHEUL', 'Koungheul', 'commune'), ('KA-BIRKELANE', 'Birkelane', 'commune'),
  ('KA-MALEMHODAR', 'Malem Hodar', 'commune'),
  -- Kaolack
  ('KL-KAOLACK', 'Kaolack', 'commune'), ('KL-KAOLACK', 'Kahone', 'commune'),
  ('KL-KAOLACK', 'Ndoffane', 'commune'), ('KL-KAOLACK', 'Sibassor', 'commune'),
  ('KL-KAOLACK', 'Keur Socé', 'commune'),
  ('KL-GUINGUINEO', 'Guinguinéo', 'commune'), ('KL-NIORO', 'Nioro du Rip', 'commune'),
  ('KL-NIORO', 'Keur Madiabel', 'commune'), ('KL-NIORO', 'Médina Sabak', 'commune'),
  -- Kédougou
  ('KE-KEDOUGOU', 'Kédougou', 'commune'), ('KE-KEDOUGOU', 'Bandafassi', 'commune'),
  ('KE-SALEMATA', 'Salémata', 'commune'), ('KE-SARAYA', 'Saraya', 'commune'),
  -- Kolda
  ('KD-KOLDA', 'Kolda', 'commune'), ('KD-KOLDA', 'Dabo', 'commune'), ('KD-KOLDA', 'Salikégné', 'commune'),
  ('KD-VELINGARA', 'Vélingara', 'commune'), ('KD-VELINGARA', 'Kounkané', 'commune'),
  ('KD-MEDINAYORO', 'Médina Yoro Foulah', 'commune'),
  -- Louga
  ('LG-LOUGA', 'Louga', 'commune'), ('LG-LOUGA', 'Guet Ndar', 'commune'),
  ('LG-KEBEMER', 'Kébémer', 'commune'), ('LG-KEBEMER', 'Guéoul', 'commune'),
  ('LG-KEBEMER', 'Diokoul Diawrigne', 'commune'),
  ('LG-LINGUERE', 'Linguère', 'commune'), ('LG-LINGUERE', 'Dahra', 'commune'),
  -- Matam
  ('MT-MATAM', 'Matam', 'commune'), ('MT-MATAM', 'Ourossogui', 'commune'),
  ('MT-MATAM', 'Thilogne', 'commune'),
  ('MT-KANEL', 'Kanel', 'commune'), ('MT-KANEL', 'Sémé', 'commune'), ('MT-KANEL', 'Waoundé', 'commune'),
  ('MT-RANEROU', 'Ranérou', 'commune'),
  -- Saint-Louis
  ('SL-SAINTLOUIS', 'Saint-Louis', 'commune'), ('SL-SAINTLOUIS', 'Mpal', 'commune'),
  ('SL-SAINTLOUIS', 'Gandon', 'commune'), ('SL-SAINTLOUIS', 'Ndiébène Gandiol', 'commune'),
  ('SL-SAINTLOUIS', 'Fass Ngom', 'commune'),
  ('SL-DAGANA', 'Dagana', 'commune'), ('SL-DAGANA', 'Richard-Toll', 'commune'),
  ('SL-DAGANA', 'Rosso Sénégal', 'commune'), ('SL-DAGANA', 'Gaé', 'commune'),
  ('SL-PODOR', 'Podor', 'commune'), ('SL-PODOR', 'Ndioum', 'commune'),
  ('SL-PODOR', 'Golléré', 'commune'), ('SL-PODOR', 'Aéré Lao', 'commune'),
  -- Sédhiou
  ('SE-SEDHIOU', 'Sédhiou', 'commune'), ('SE-SEDHIOU', 'Marsassoum', 'commune'),
  ('SE-BOUNKILING', 'Bounkiling', 'commune'), ('SE-BOUNKILING', 'Diattacounda', 'commune'),
  ('SE-GOUDOMP', 'Goudomp', 'commune'), ('SE-GOUDOMP', 'Diattacounda', 'commune'),
  ('SE-GOUDOMP', 'Oudoucar', 'commune'),
  -- Tambacounda
  ('TC-TAMBACOUNDA', 'Tambacounda', 'commune'), ('TC-TAMBACOUNDA', 'Koussanar', 'commune'),
  ('TC-BAKEL', 'Bakel', 'commune'), ('TC-BAKEL', 'Kidira', 'commune'),
  ('TC-GOUDIRY', 'Goudiry', 'commune'), ('TC-KOUMPENTOUM', 'Koumpentoum', 'commune'),
  -- Thiès
  ('TH-THIES', 'Thiès', 'commune'), ('TH-THIES', 'Thiès Est', 'commune'),
  ('TH-THIES', 'Thiès Nord', 'commune'), ('TH-THIES', 'Khombole', 'commune'),
  ('TH-THIES', 'Pout', 'commune'), ('TH-THIES', 'Kayar', 'commune'), ('TH-THIES', 'Fandène', 'commune'),
  ('TH-MBOUR', 'Mbour', 'commune'), ('TH-MBOUR', 'Saly Portudal', 'commune'),
  ('TH-MBOUR', 'Ngaparou', 'commune'), ('TH-MBOUR', 'Somone', 'commune'),
  ('TH-MBOUR', 'Nianing', 'commune'), ('TH-MBOUR', 'Joal-Fadiouth', 'commune'),
  ('TH-MBOUR', 'Popenguine', 'commune'), ('TH-MBOUR', 'Nguékokh', 'commune'),
  ('TH-MBOUR', 'Malicounda', 'commune'), ('TH-MBOUR', 'Sandiaara', 'commune'),
  ('TH-MBOUR', 'Warang', 'commune'),
  ('TH-TIVAOUANE', 'Tivaouane', 'commune'), ('TH-TIVAOUANE', 'Mékhé', 'commune'),
  ('TH-TIVAOUANE', 'Mboro', 'commune'), ('TH-TIVAOUANE', 'Pambal', 'commune'),
  ('TH-TIVAOUANE', 'Chérif Lô', 'commune'), ('TH-TIVAOUANE', 'Notto Gouye Diama', 'commune'),
  -- Ziguinchor
  ('ZG-ZIGUINCHOR', 'Ziguinchor', 'commune'), ('ZG-ZIGUINCHOR', 'Niaguis', 'commune'),
  ('ZG-ZIGUINCHOR', 'Adéane', 'commune'), ('ZG-ZIGUINCHOR', 'Boutoupa', 'commune'),
  ('ZG-BIGNONA', 'Bignona', 'commune'), ('ZG-BIGNONA', 'Thionck Essyl', 'commune'),
  ('ZG-BIGNONA', 'Diouloulou', 'commune'), ('ZG-BIGNONA', 'Sindian', 'commune'),
  ('ZG-BIGNONA', 'Kafountine', 'commune'), ('ZG-BIGNONA', 'Cap Skirring', 'commune'),
  ('ZG-OUSSOUYE', 'Oussouye', 'commune'), ('ZG-OUSSOUYE', 'Diembéring', 'commune'),
  ('ZG-OUSSOUYE', 'Mlomp', 'commune'), ('ZG-OUSSOUYE', 'Santhiaba Manjack', 'commune')
) as v(code_departement, nom, type)
join public.departements d on d.code = v.code_departement
on conflict (departement_id, nom) do nothing;

-- -----------------------------------------------------------------------------
-- 4. Quartiers (agglomération dakaroise et Petite Côte — extensible)
-- -----------------------------------------------------------------------------
insert into public.quartiers (commune_id, nom)
select c.id, v.nom
from (values
  ('Dakar Plateau', 'Plateau Centre'), ('Dakar Plateau', 'Sandaga'), ('Dakar Plateau', 'Kermel'),
  ('Dakar Plateau', 'Corniche Est'), ('Dakar Plateau', 'Rue Carnot'),
  ('Médina', 'Médina'), ('Médina', 'Fass'), ('Médina', 'Gueule Tapée'), ('Médina', 'Colobane'),
  ('Fann-Point E-Amitié', 'Fann'), ('Fann-Point E-Amitié', 'Fann Résidence'),
  ('Fann-Point E-Amitié', 'Point E'), ('Fann-Point E-Amitié', 'Amitié'),
  ('Mermoz-Sacré-Cœur', 'Mermoz'), ('Mermoz-Sacré-Cœur', 'Sacré-Cœur 1'),
  ('Mermoz-Sacré-Cœur', 'Sacré-Cœur 2'), ('Mermoz-Sacré-Cœur', 'Sacré-Cœur 3'),
  ('Mermoz-Sacré-Cœur', 'Fann Hock'),
  ('Ouakam', 'Ouakam'), ('Ouakam', 'Cité Avion'), ('Ouakam', 'Mamelles'),
  ('Ngor', 'Ngor'), ('Ngor', 'Ngor Village'), ('Ngor', 'Ngor Almadies'),
  ('Yoff', 'Yoff'), ('Yoff', 'Yoff Layène'), ('Yoff', 'Aéroport LSS'),
  ('Almadies', 'Almadies'), ('Almadies', 'Pointe des Almadies'),
  ('Grand Yoff', 'Grand Yoff'), ('Grand Yoff', 'Parcelles Assainies'),
  ('Grand Yoff', 'Parcelles Unité 15'), ('Grand Yoff', 'Cité Comico'),
  ('Grand Dakar', 'Grand Dakar'), ('Grand Dakar', 'Colobane Fass'),
  ('HLM', 'HLM 1'), ('HLM', 'HLM 2'), ('HLM', 'HLM 3'), ('HLM', 'HLM 4'), ('HLM', 'HLM 5'),
  ('Sicap-Liberté', 'Liberté 1'), ('Sicap-Liberté', 'Liberté 2'), ('Sicap-Liberté', 'Liberté 5'),
  ('Sicap-Liberté', 'Sicap Baobab'), ('Sicap-Liberté', 'Sicap Sacré-Cœur'),
  ('Biscuiterie', 'Biscuiterie'), ('Biscuiterie', 'Boabab'),
  ('Dieuppeul-Derklé', 'Dieuppeul'), ('Dieuppeul-Derklé', 'Derklé'),
  ('Hann Bel-Air', 'Hann Bel-Air'), ('Hann Bel-Air', 'Hann Maristes'),
  ('Patte d''Oie', 'Patte d''Oie'), ('Patte d''Oie', 'Sahm Notaire'),
  ('Cambérène', 'Cambérène'), ('Cambérène', 'Cité Keur Gorgui'),
  ('Guédiawaye', 'Guédiawaye Nord'), ('Guédiawaye', 'Cité Comico'),
  ('Médina Gounass', 'Médina Gounass'),
  ('Pikine', 'Pikine Centre'), ('Thiaroye-sur-Mer', 'Thiaroye-sur-Mer'),
  ('Mbao', 'Mbao'), ('Keur Massar', 'Keur Massar'), ('Malika', 'Malika'),
  ('Rufisque Est', 'Rufisque Centre'), ('Rufisque Nord', 'Arafat'),
  ('Bargny', 'Bargny'), ('Diamniadio', 'Diamniadio'), ('Diamniadio', 'Sphères Ministérielles'),
  ('Diamniadio', 'AIBD'), ('Sébikotane', 'Sébikotane'), ('Sangalkam', 'Sangalkam'),
  ('Saly Portudal', 'Saly Niakhniakhal'), ('Saly Portudal', 'Saly Station'),
  ('Saly Portudal', 'Saly Portudal'), ('Ngaparou', 'Ngaparou Centre'),
  ('Somone', 'Somone'), ('Nianing', 'Nianing'), ('Mbour', 'Mbour Centre'),
  ('Mbour', 'Tefess'), ('Mbour', 'Grand Mbour'), ('Joal-Fadiouth', 'Joal'), ('Joal-Fadiouth', 'Fadiouth'),
  ('Popenguine', 'Popenguine'), ('Nguékokh', 'Nguékokh'), ('Malicounda', 'Malicounda'),
  ('Thiès', 'Thiès Centre'), ('Thiès Nord', 'M''Doucouré'), ('Thiès Nord', 'Randoulène'),
  ('Thiès Est', 'Escale'), ('Thiès Est', 'Som'), ('Tivaouane', 'Tivaouane Centre'),
  ('Mékhé', 'Mékhé'), ('Mboro', 'Mboro'),
  ('Saint-Louis', 'Île de Saint-Louis'), ('Saint-Louis', 'Sor'), ('Saint-Louis', 'Guet Ndar'),
  ('Saint-Louis', 'Nord'), ('Saint-Louis', 'Sud'), ('Saint-Louis', 'Hydrobase'),
  ('Richard-Toll', 'Richard-Toll Centre'), ('Dagana', 'Dagana'),
  ('Louga', 'Louga Centre'), ('Louga', 'HLM Bagdad'), ('Louga', 'Bango'),
  ('Touba Mosquée', 'Touba Mosquée'), ('Mbacké', 'Mbacké'),
  ('Diourbel', 'Escale Diourbel'), ('Diourbel', 'Diourbel Centre'),
  ('Kaolack', 'Kaolack Centre'), ('Kaolack', 'Léona'), ('Kaolack', 'Médina Baye'),
  ('Kaolack', 'Keur Socé'), ('Nioro du Rip', 'Nioro du Rip'),
  ('Fatick', 'Fatick Centre'), ('Foundiougne', 'Foundiougne'), ('Sokone', 'Sokone'),
  ('Kaffrine', 'Kaffrine Centre'), ('Koungheul', 'Koungheul'),
  ('Tambacounda', 'Tambacounda Centre'), ('Bakel', 'Bakel'), ('Kidira', 'Kidira'),
  ('Kédougou', 'Kédougou Centre'), ('Salémata', 'Salémata'), ('Saraya', 'Saraya'),
  ('Kolda', 'Kolda Centre'), ('Kolda', 'Doumassou'), ('Vélingara', 'Vélingara'),
  ('Kounkané', 'Kounkané'), ('Sédhiou', 'Sédhiou Centre'), ('Bounkiling', 'Bounkiling'),
  ('Goudomp', 'Goudomp'), ('Ziguinchor', 'Ziguinchor Centre'),
  ('Ziguinchor', 'Escales'), ('Ziguinchor', 'Boucotte'), ('Ziguinchor', 'Kénia'),
  ('Bignona', 'Bignona'), ('Oussouye', 'Oussouye'), ('Cap Skirring', 'Cap Skirring'),
  ('Kafountine', 'Kafountine'), ('Diembéring', 'Diembéring'), ('Thionck Essyl', 'Thionck Essyl')
) as v(commune_nom, nom)
join public.communes c on c.nom = v.commune_nom
on conflict (commune_id, nom) do nothing;

-- Cas particuliers : Almadies appartient à la commune de Ngor dans le référentiel officiel,
-- mais l'usage courant (et les sources collectées) la traite comme un quartier distinct.
insert into public.quartiers (commune_id, nom)
select c.id, 'Almadies'
from public.communes c where c.nom = 'Ngor'
on conflict (commune_id, nom) do nothing;

-- -----------------------------------------------------------------------------
-- 5. Nomenclatures
-- -----------------------------------------------------------------------------
insert into public.types_etablissement (code, libelle) values
  ('restaurant',           'Restaurant'),
  ('fast_food',            'Fast-food'),
  ('gargote',              'Gargote'),
  ('dibiterie',            'Dibiterie'),
  ('pizzeria',             'Pizzeria'),
  ('cafe_restaurant',      'Café-restaurant'),
  ('salon_de_the',         'Salon de thé'),
  ('patisserie',           'Pâtisserie'),
  ('boulangerie',          'Boulangerie'),
  ('glacier',              'Glacier'),
  ('grillades',            'Grillades / braiserie'),
  ('restaurant_hotel',     'Restaurant d''hôtel'),
  ('restaurant_plage',     'Restaurant de plage'),
  ('restaurant_rooftop',   'Restaurant / rooftop'),
  ('bar_lounge_restaurant','Bar-lounge avec restauration'),
  ('traiteur',             'Traiteur'),
  ('service_livraison',    'Service de livraison alimentaire'),
  ('snack',                'Snack'),
  ('maquis',               'Maquis'),
  ('cantine',              'Cantine'),
  ('food_truck',           'Food truck'),
  ('complexe_restauration','Complexe de restauration'),
  ('cuisine_centrale',     'Cuisine centrale')
on conflict (code) do update set libelle = excluded.libelle;

insert into public.categories_culinaires (code, libelle) values
  ('senegalaise',    'Cuisine sénégalaise'),
  ('africaine',      'Cuisine africaine'),
  ('creole',         'Cuisine créole / casamançaise'),
  ('congolaise',     'Cuisine congolaise'),
  ('ethiopienne',    'Cuisine éthiopienne'),
  ('maghrebine',     'Cuisine maghrébine'),
  ('libanaise',      'Cuisine libanaise / Moyen-Orient'),
  ('francaise',      'Cuisine française'),
  ('italienne',      'Cuisine italienne'),
  ('mediterraneenne','Cuisine méditerranéenne'),
  ('gastronomique',  'Gastronomie / haute cuisine'),
  ('internationale', 'Cuisine internationale'),
  ('asiatique',      'Cuisine asiatique'),
  ('chinoise',       'Cuisine chinoise'),
  ('thaie',          'Cuisine thaïlandaise'),
  ('japonaise',      'Cuisine japonaise'),
  ('indienne',       'Cuisine indienne'),
  ('americaine',     'Cuisine américaine'),
  ('burgers',        'Burgers & sandwichs'),
  ('pizza',          'Pizza'),
  ('fruits_de_mer',  'Poissons & fruits de mer'),
  ('grillades',      'Grillades & braisés'),
  ('street_food',    'Street food'),
  ('patisserie_dessert', 'Pâtisserie & desserts'),
  ('glaces',         'Glaces & crèmes'),
  ('petit_dejeuner', 'Petit-déjeuner'),
  ('brunch',         'Brunch'),
  ('vegetarienne',   'Végétarienne / végétalienne'),
  ('healthy',        'Healthy / saine'),
  ('buffet',         'Buffet à volonté')
on conflict (code) do update set libelle = excluded.libelle;

insert into public.services (code, libelle, categorie) values
  ('sur_place',      'Sur place', 'reception'),
  ('a_emporter',     'À emporter', 'reception'),
  ('retrait_sur_place', 'Retrait sur place', 'reception'),
  ('livraison_restaurant', 'Livraison assurée par le restaurant', 'livraison'),
  ('livraison_partenaire', 'Livraison assurée par un partenaire', 'livraison'),
  ('commande_telephone', 'Commande par téléphone', 'commande'),
  ('commande_whatsapp',  'Commande par WhatsApp', 'commande'),
  ('commande_site_web',  'Commande sur le site du restaurant', 'commande'),
  ('commande_dekk_food', 'Commande intégrée DEKK FOOD', 'commande'),
  ('reservation',    'Réservation possible', 'reception'),
  ('traiteur',       'Service traiteur', 'reception'),
  ('buffet',         'Buffet', 'reception'),
  ('terrasse',       'Terrasse', 'autre'),
  ('climatisation',  'Salle climatisée', 'autre'),
  ('wifi',           'Wi-Fi', 'autre'),
  ('parking',        'Parking', 'autre'),
  ('acces_pmr',      'Accessible aux personnes à mobilité réduite', 'autre'),
  ('espace_enfants', 'Espace enfants', 'autre'),
  ('salle_privee',   'Salle privée / événements', 'autre'),
  ('vue_mer',        'Vue mer', 'autre'),
  ('piscine',        'Piscine', 'autre'),
  ('paiement_especes', 'Paiement en espèces', 'autre'),
  ('paiement_carte',  'Paiement par carte bancaire', 'autre'),
  ('paiement_mobile_money', 'Paiement mobile money (Wave, Orange Money…)', 'autre')
on conflict (code) do update set libelle = excluded.libelle, categorie = excluded.categorie;

insert into public.allergenes (code, libelle) values
  ('gluten', 'Gluten'), ('crustaces', 'Crustacés'), ('oeufs', 'Œufs'), ('poisson', 'Poisson'),
  ('arachides', 'Arachides'), ('soja', 'Soja'), ('lait', 'Lait'), ('fruits_a_coque', 'Fruits à coque'),
  ('celeri', 'Céleri'), ('moutarde', 'Moutarde'), ('sesame', 'Sésame'), ('sulfites', 'Sulfites'),
  ('mollusques', 'Mollusques')
on conflict (code) do update set libelle = excluded.libelle;

insert into public.regimes_alimentaires (code, libelle) values
  ('vegetarien', 'Végétarien'), ('vegan', 'Végétalien'), ('sans_gluten', 'Sans gluten'),
  ('halal', 'Halal'), ('sans_porc', 'Sans porc'), ('hypocalorique', 'Faible en calories'),
  ('sans_lactose', 'Sans lactose')
on conflict (code) do update set libelle = excluded.libelle;

-- -----------------------------------------------------------------------------
-- 6. Sources effectivement utilisées par la collecte
-- -----------------------------------------------------------------------------
insert into public.sources (code, nom, url, type, conditions_utilisation, contenu_reutilisable, notes) values
  ('senefinder', 'Senefinder — annuaire d''entreprises du Sénégal',
   'https://senefinder.com/fr/search?category=food_restaurants&origin=category', 'annuaire',
   'Annuaire public consultable. Les fiches sont déclaratives (remplies par les entreprises). Réutilisation limitée aux données factuelles (nom, adresse, téléphone public) ; les images restent la propriété de leurs auteurs.',
   true, '376 établissements annoncés dans la catégorie « Alimentation et Restaurants » au 13/10/2026.'),
  ('senlocal', 'Senlocal — annuaire local vérifié',
   'https://senlocal.com/categories/restaurants', 'annuaire',
   'Annuaire public. Fiches marquées « Vérifié » par l''éditeur du site, sans date de vérification publiée. Données factuelles réutilisées avec mention de la source.',
   true, '87 fiches « Restaurants » dont 73 à Dakar au 13/10/2026.'),
  ('saintlouisdusenegal', 'Saint-Louis du Sénégal — guide local',
   'https://www.saintlouisdusenegal.com/restaurants/', 'guide',
   'Guide touristique public. Extraction textuelle limitée par la mise en page (carte intégrée). À compléter manuellement.',
   true, 'Page consultée le 13/10/2026 : contenu utile non extractible automatiquement (carte Google Maps).'),
  ('fadidi', 'Fadidi.sn — annuaire sénégalais',
   'https://fadidi.sn/restaurants', 'annuaire',
   'Annuaire public. Page inaccessible lors de la collecte du 13/10/2026.',
   true, 'Indisponible au 13/10/2026 (échec de récupération).'),
  ('senegal_online', 'Senegal-Online — portail touristique',
   'https://www.senegal-online.com/', 'guide',
   'Portail public d''information touristique.',
   true, 'Non exploité lors de cette première phase.'),
  ('application_existante', 'Application DEKK FOOD existante (données héritées)',
   null, 'application_existante',
   'Données internes déjà présentes dans l''application. Conservées, mais reclassées « à confirmer » : elles n''étaient accompagnées d''aucune source.',
   true, '14 établissements et leurs plats, issus de lib/main.dart (version 2.1.0).'),
  ('recherche_web', 'Recherche web publique (moteur de recherche)',
   null, 'recherche_web',
   'Résultats publics de moteurs de recherche. Utilisés uniquement comme indice de piste, jamais comme preuve d''activité.',
   true, 'Sert à identifier des pistes à vérifier, pas à publier des données.'),
  ('restaurateur_terrain', 'Informations fournies par le restaurateur / relevé terrain',
   null, 'restaurateur',
   'Informations transmises directement par l''établissement, avec son accord.',
   true, 'Source de plus haute valeur pour les horaires, menus et photos.'),
  ('openstreetmap', 'OpenStreetMap — base cartographique ouverte (ODbL)',
   'https://www.openstreetmap.org/', 'fiche_publique',
   'Données ouvertes sous licence ODbL : réutilisation autorisée avec attribution « © OpenStreetMap contributors » et partage à l''identique. Les positions et horaires étant contributifs, ils ne valent pas vérification sur place (gps_verifie et confirme restent à false).',
   true, 'Interrogée via l''API Overpass le 13/10/2026 sur des rectangles de recherche urbains (Fatick, Kaffrine, Tambacounda, Kédougou, Sédhiou, Matam). Matam n''a renvoyé aucun établissement nommé.')
on conflict (code) do update set nom = excluded.nom, url = excluded.url, notes = excluded.notes;
