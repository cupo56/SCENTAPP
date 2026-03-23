-- Scent Wheel: Duftfamilien-Zuweisung für alle notes
-- Basierend auf den 302 Noten aus der DB (Stand: 24.03.2026)
-- Familien: Floral, Woody, Oriental, Fresh, Citrus, Gourmand, Aquatic, Green, Spicy, Musky

-- =========================================================
-- FLORAL (55 Noten)
-- Blüten, Rosen, Jasmin, Orchideen, Lavendel usw.
-- =========================================================
UPDATE public.notes SET family = 'Floral' WHERE name IN (
    'Birnenblüte',
    'Blumen',
    'Blumige Noten',
    'Blüten',
    'Bulgarische Rose',
    'Damaszener Rose',
    'Florale Noten',
    'Frangipani',
    'Freesie',
    'Gardenie',
    'Geißblatt',
    'Geranie',
    'Geranium',
    'Gezuckerte Blüten',
    'Heliotrop',
    'Hibiskus',
    'Hyazinthe',
    'Iris',
    'Iriswurzel',
    'Jasmin',
    'Jasmin Sambac',
    'Jasmin-Sambac',
    'Kamelien Accord',
    'Lavandin',
    'Lavendel',
    'Lilie',
    'Longoza',
    'Lotus',
    'Magnolie',
    'Maiglöckchen',
    'Mimose',
    'Mondblume',
    'Narzisse',
    'Neroli',
    'Neroli-Knospen-Essenz',
    'Orangenblüte',
    'Orchidee',
    'Osmanthus',
    'Petalia',
    'Pfingstrose',
    'Robinie',
    'Rose',
    'Rosen',
    'Rosenwasser',
    'Sakura',
    'Sambac-Jasmin',
    'Tuberose',
    'Tulpe',
    'Türkische Rose',
    'Veilchen',
    'Veilchenblatt',
    'Veilchenblätter',
    'Weiße Blüten',
    'Wilde Orchidee',
    'Ylang-Ylang',
    'Zyklamen'
);

-- =========================================================
-- WOODY (44 Noten)
-- Holz, Zeder, Oud, Patchouli, Vetiver, Moos usw.
-- =========================================================
UPDATE public.notes SET family = 'Woody' WHERE name IN (
    'Adlerholz (Oud)',
    'Amberholz',
    'Ambraholz',
    'Amyris',
    'Atlas Zeder',
    'Atlaszeder',
    'Birke',
    'Ebenholz',
    'Eiche',
    'Eichenmoos',
    'Elemiharz',
    'Erdige Noten',
    'Fichte',
    'Guaiacholz',
    'Guajak',
    'Guajakholz',
    'Helle Hölzer',
    'Holz',
    'Hölzer',
    'Holzige Noten',
    'Holznoten',
    'Kaschmir-Holz',
    'Kaschmirholz',
    'Kiefer',
    'Mahagoni',
    'Moos',
    'Nagarmotha',
    'Oud',
    'Patchouli',
    'Patschuli',
    'Pinie',
    'Sandelholz',
    'Silberkiefer',
    'Tannenharz',
    'Traumholz',
    'Vetiver',
    'Virginia Zeder',
    'Zeder',
    'Zederholz',
    'Zedernholz',
    'Zedernholzblätter',
    'Zypresse'
);

-- =========================================================
-- ORIENTAL (24 Noten)
-- Amber, Harze, Weihrauch, Tabak, Tonka, Leder usw.
-- =========================================================
UPDATE public.notes SET family = 'Oriental' WHERE name IN (
    'Amber',
    'Ambra',
    'Balsamische Noten',
    'Benzoe',
    'Benzoin',
    'Harze',
    'Labdanum',
    'Labdanum Absolue',
    'Myrrhe',
    'Myrrhe Absolue',
    'Opoponax',
    'Orcanox',
    'Roter Amber',
    'Safran',
    'Tabak',
    'Tolu Balsam',
    'Tolu-Balsam',
    'Tonka',
    'Tonkabohne',
    'Weihrauch'
);

-- =========================================================
-- FRESH (41 Noten)
-- Früchte (nicht Zitrus), Beeren, Solare Noten, Salz usw.
-- =========================================================
UPDATE public.notes SET family = 'Fresh' WHERE name IN (
    'Aldehyde',
    'Ananas',
    'Apfel',
    'Aprikose',
    'Beeren',
    'Birne',
    'Brombeere',
    'Drachenfrucht',
    'Erdbeere',
    'Feige',
    'Feigenbaum',
    'Feigenkonzentrat',
    'Frische Noten',
    'Früchte',
    'Fruchtige Noten',
    'Granatapfel',
    'Grüner Apfel',
    'Himbeere',
    'Johannisbeere',
    'Kirsche',
    'Litschi',
    'Mango',
    'Mediterrane Früchte',
    'Meersalz',
    'Mineralnoten',
    'Nektarine',
    'Passionsfrucht',
    'Pfirsich',
    'Pflaume',
    'Rote Beeren',
    'Rote Früchte',
    'Salz',
    'Schwarze Johannisbeere',
    'Schwarze Kirsche',
    'Schwarze Pflaume',
    'Schwarzkirsche',
    'Solare Noten',
    'Sonnennoten',
    'Tropische Früchte',
    'Waldfrüchte',
    'Wassermelone'
);

-- =========================================================
-- CITRUS (38 Noten)
-- Bergamotte, Zitrone, Orange, Mandarine, Yuzu usw.
-- =========================================================
UPDATE public.notes SET family = 'Citrus' WHERE name IN (
    'Amalfi Zitrone',
    'Bergamotte',
    'Bigarade',
    'Bitterorange',
    'Blutmandarine',
    'Blutorange',
    'Brasilianische Orange',
    'Calabrian Bergamotte',
    'Calabrische Bergamotte',
    'Cedrat',
    'Chinotto',
    'Citron',
    'Gelbe Mandarine',
    'Grapefruit',
    'Grüne Mandarine',
    'Kalabrische Bergamotte',
    'Limette',
    'Mandarine',
    'Mandarinblätter',
    'Mandarinen-Essenz',
    'Orange',
    'Orangenblatt',
    'Orangenblätter Absolue',
    'Petitgrain',
    'Rhabarber',
    'Sizilianische Orange',
    'Sizilianische Zitrone',
    'Sizilische Zitrone',
    'Sizilische Zitrusfrüchte',
    'Süße Orange',
    'Süßorange',
    'Verbena',
    'Yuzu',
    'Zitrone',
    'Zitronenverbene',
    'Zitrus',
    'Zitrusfrüchte',
    'Zitrusnoten',
    'Zitrusschale'
);

-- =========================================================
-- GOURMAND (33 Noten)
-- Vanille, Schokolade, Karamell, Kaffee, Nüsse usw.
-- =========================================================
UPDATE public.notes SET family = 'Gourmand' WHERE name IN (
    'Baiser',
    'Bittermandel',
    'Brauner Zucker',
    'Dattel',
    'Dunkle Schokolade',
    'Eiscreme',
    'Grüne Mandeln',
    'Haselnuss',
    'Honig',
    'Kaffee',
    'Kakao',
    'Kakaobutter',
    'Karamell',
    'Kokosnuss',
    'Kokoswasser',
    'Lakritz',
    'Macarons',
    'Madagaskar Vanille',
    'Mandel',
    'Marshmallow',
    'Milch',
    'Nussige Noten',
    'Praline',
    'Reis',
    'Rum',
    'Schlagsahne',
    'Schokolade',
    'Süße Noten',
    'Toffee',
    'Vanille',
    'Vanille-Kaviar',
    'Vanille-Macaron',
    'Vanilleorchidee',
    'Weiße Schokolade',
    'Zucker',
    'Zuckerwatte'
);

-- =========================================================
-- AQUATIC (6 Noten)
-- Ozeanische, marine, aquatische Noten
-- =========================================================
UPDATE public.notes SET family = 'Aquatic' WHERE name IN (
    'Aquatische Noten',
    'Marine Noten',
    'Meereichenalgen',
    'Meeresbrise',
    'Ozonische Noten',
    'Seenoten'
);

-- =========================================================
-- GREEN (26 Noten)
-- Kräuter, Tee, Minze, Gras, Wacholder usw.
-- =========================================================
UPDATE public.notes SET family = 'Green' WHERE name IN (
    'Aromatische Noten',
    'Artemisia',
    'Basilikum',
    'Eukalyptus',
    'Fenchel',
    'Galbanum',
    'Grün',
    'Grüne Noten',
    'Grüner Tee',
    'Kalmus',
    'Kräuter',
    'Kräuternoten',
    'Lentiskus',
    'Lentiskus Absolue',
    'Lorbeerblatt',
    'Minze',
    'Myrte',
    'Pfefferminz',
    'Rosmarin',
    'Schwarzer Tee',
    'Shiso',
    'Spearmint',
    'Tee',
    'Wacholder',
    'Wacholderbeeren',
    'Roter Thymian'
);

-- =========================================================
-- SPICY (26 Noten)
-- Pfeffer, Ingwer, Zimt, Gewürze, Safran usw.
-- =========================================================
UPDATE public.notes SET family = 'Spicy' WHERE name IN (
    'Absinth',
    'Anis',
    'Chili Pfeffer',
    'Gewürze',
    'Ingwer',
    'Kardamom',
    'Koriander',
    'Kümmel',
    'Muskat',
    'Muskatellersalbei',
    'Muskatnuss',
    'Nelke',
    'Oregano',
    'Paprika',
    'Pfeffer',
    'Piment',
    'Rosa Pfeffer',
    'Rosenpfeffer',
    'Roter Pfeffer',
    'Schwarzer Pfeffer',
    'Sichuan Pfeffer',
    'Sichuanpfeffer',
    'Sternanis',
    'Würzige Noten',
    'Zimt'
);

-- =========================================================
-- MUSKY (10 Noten)
-- Moschus, Leder, Puder, Cashmeran usw.
-- =========================================================
UPDATE public.notes SET family = 'Musky' WHERE name IN (
    'Ambrette',
    'Ambrettolid',
    'Ambroxan',
    'Cashmeran',
    'Leder',
    'Lederakkord',
    'Moschus',
    'Puder',
    'Weißer Moschus',
    'Wildleder'
);

-- =========================================================
-- Prüfung: Noten ohne family anzeigen
-- =========================================================
-- SELECT name FROM public.notes WHERE family IS NULL ORDER BY name;
