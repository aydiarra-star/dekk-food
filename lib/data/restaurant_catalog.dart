import '../models/restaurant.dart';

/// Catalogue local utilisé immédiatement au démarrage.
///
/// Les écrans consomment des objets [Restaurant] typés; le format brut reste
/// isolé ici afin qu'il puisse être remplacé par Supabase sans toucher l'UI.
class RestaurantCatalog {
  RestaurantCatalog._();

  static final List<Restaurant> all = List<Restaurant>.unmodifiable(
    _records.map(Restaurant.fromCatalogJson),
  );

  static final List<Map<String, dynamic>> _records = [
    // --- DAKAR ---
    {
      'name': 'Seven Seven Dakar',
      'neighborhood': 'Ngor',
      'zone': 'Dakar',
      'cuisine': 'International & Grillades',
      'rating': 4.8,
      'reviews': 2122,
      'price': '3 000 – 10 000 FCFA',
      'phone': '+221 78 593 78 78',
      'whatsapp': '+221 78 593 78 78',
      'address': 'Route de Ngor, Dakar',
      'gpsQuery': 'Seven Seven Dakar Ngor',
      'image': 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4',
      'description': 'Restaurant incontournable de grillades et de cuisine internationale à Ngor.',
      'menu': [
        {
          'name': 'Brochettes géantes de gambas',
          'price': '8 500 FCFA',
          'desc': 'Gambas fraîches marinées aux herbes fines, grillées à la flamme et riz parfumé.',
          'image': 'https://images.unsplash.com/photo-1565557623262-b51c2513a641',
          'available': true,
          'hygiene': 'Gambas de la pêche locale du jour, contrôlées selon les normes HACCP. Cuisine désinfectée en continu.'
        },
        {
          'name': 'Filet de zébu sauce poivre',
          'price': '7 000 FCFA',
          'desc': 'Tendre morceau de zébu sélectionné, nappé d’une sauce au poivre vert et frites maison.',
          'image': 'https://images.unsplash.com/photo-1558030006-450675393462',
          'available': true,
          'hygiene': 'Viande certifiée et conservée en chambre froide à température contrôlée.'
        },
      ],
    },
    {
      'name': 'Restaurant Le Lagon 1',
      'neighborhood': 'Plateau',
      'zone': 'Dakar',
      'cuisine': 'Française & Poissons',
      'rating': 4.4,
      'reviews': 2345,
      'price': '5 000 – 15 000 FCFA',
      'phone': '+221 33 821 53 22',
      'whatsapp': '+221 33 821 53 22',
      'address': 'Route de la Corniche Est, Dakar',
      'gpsQuery': 'Le Lagon 1 Dakar Plateau',
      'image': 'https://images.unsplash.com/photo-1544025162-d76694265947',
      'description': 'Gastronomie française et poissons frais avec vue panoramique sur l’océan au Plateau.',
      'menu': [
        {
          'name': 'Langouste grillée au beurre blanc',
          'price': '14 000 FCFA',
          'desc': 'Pêche locale du jour cuisinée au beurre blanc onctueux.',
          'image': 'https://images.unsplash.com/photo-1535400255456-984241443b28',
          'available': true,
          'hygiene': 'Arrivage direct des pêcheurs artisanaux sans rupture de la chaîne du froid.'
        },
      ],
    },
    {
      'name': 'Chez Fatou',
      'neighborhood': 'Almadies',
      'zone': 'Dakar',
      'cuisine': 'Sénégalaise & Grillades',
      'rating': 4.0,
      'reviews': 2265,
      'price': '3 000 – 8 000 FCFA',
      'phone': '+221 33 820 92 38',
      'whatsapp': '+221 33 820 92 38',
      'address': 'Corniche des Almadies, Dakar',
      'gpsQuery': 'Chez Fatou Almadies Dakar',
      'image': 'https://images.unsplash.com/photo-1537047902294-62a40c20a6ae',
      'description': 'La référence incontournable de la cuisine sénégalaise traditionnelle aux Almadies.',
      'menu': [
        {
          'name': 'Ceebu Jën (Riz au poisson)',
          'price': '3 500 FCFA',
          'desc': 'Le plat national authentique rouge, avec thiof frais et légumes variés.',
          'image': 'https://images.unsplash.com/photo-1541544741938-0af808871cc0',
          'available': true,
          'hygiene': 'Poisson frais du marché de Soumbédioune lavé à l’eau purifiée.'
        },
        {
          'name': 'Poulet Yassa',
          'price': '3 000 FCFA',
          'desc': 'Poulet fermier mariné longuement aux oignons confits, citron vert et moutarde.',
          'image': 'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46',
          'available': true,
          'hygiene': 'Poulets rigoureusement lavés au vinaigre et citron avant marinade.'
        },
      ],
    },
    {
      'name': 'Reine Margarita',
      'neighborhood': 'Plateau',
      'zone': 'Dakar',
      'cuisine': 'Italienne & Pizzeria',
      'rating': 4.4,
      'reviews': 396,
      'price': '3 000 – 7 000 FCFA',
      'phone': '+221 78 444 99 55',
      'whatsapp': '+221 78 444 99 55',
      'address': 'Dakar Plateau',
      'gpsQuery': 'Reine Margarita Dakar Plateau',
      'image': 'https://images.unsplash.com/photo-1513104890138-7c749659a591',
      'description': 'Authentiques pizzas italiennes cuites au feu de bois et pâtes fraîches au cœur de Dakar.',
      'menu': [
        {
          'name': 'Pizza Margherita di Bufala',
          'price': '5 500 FCFA',
          'desc': 'Mozzarella di bufala fondante, sauce tomate italienne et basilic frais.',
          'image': 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002',
          'available': true,
          'hygiene': 'Pâte pétrie chaque matin dans un laboratoire désinfecté.'
        },
      ],
    },
    {
      'name': 'Le Jardin Thaï',
      'neighborhood': 'Mermoz',
      'zone': 'Dakar',
      'cuisine': 'Asiatique & Thaïlandaise',
      'rating': 4.6,
      'reviews': 950,
      'price': '4 000 – 11 000 FCFA',
      'phone': '+221 33 825 12 34',
      'whatsapp': '+221 33 825 12 34',
      'address': 'Avenue Bourguiba, Mermoz',
      'gpsQuery': 'Le Jardin Thai Mermoz Dakar',
      'image': 'https://images.unsplash.com/photo-1552611052-33e04de081de',
      'description': 'Spécialités thaïlandaises authentiques et nouilles sautées dans un jardin verdoyant.',
      'menu': [
        {
          'name': 'Pad Thaï aux crevettes',
          'price': '6 500 FCFA',
          'desc': 'Nouilles de riz sautées, crevettes fraîches et sauce tamarin.',
          'image': 'https://images.unsplash.com/photo-1559847844-5315695dadae',
          'available': true,
          'hygiene': 'Ingrédients frais triés et lavés selon les normes HACCP.'
        },
      ],
    },
    {
      'name': 'Le Alkimia',
      'neighborhood': 'Fann Résidence',
      'zone': 'Dakar',
      'cuisine': 'Gastronomie Internationale',
      'rating': 4.7,
      'reviews': 1420,
      'price': '6 000 – 18 000 FCFA',
      'phone': '+221 33 869 00 00',
      'whatsapp': '+221 33 869 00 00',
      'address': 'Fann Résidence, Dakar',
      'gpsQuery': 'Le Alkimia Fann Résidence Dakar',
      'image': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5',
      'description': 'Restaurant lounge haut de gamme proposant une cuisine raffinée à Fann Résidence.',
      'menu': [
        {
          'name': 'Pavé de saumon grillé',
          'price': '11 000 FCFA',
          'desc': 'Saumon frais, mousseline de patate douce et réduction d’agrumes.',
          'image': 'https://images.unsplash.com/photo-1467003909585-2f8a72700288',
          'available': true,
          'hygiene': 'Saumon frais certifié qualité supérieure conservé sous chaîne du froid.'
        },
      ],
    },
    {
      'name': 'N’Gor Bi',
      'neighborhood': 'Ngor',
      'zone': 'Dakar',
      'cuisine': 'Poissons & Grillades',
      'rating': 4.5,
      'reviews': 1890,
      'price': '3 000 – 9 000 FCFA',
      'phone': '+221 77 632 45 89',
      'whatsapp': '+221 77 632 45 89',
      'address': 'Plage de Ngor, Dakar',
      'gpsQuery': 'Plage de Ngor Dakar',
      'image': 'https://images.unsplash.com/photo-1544025162-d76694265947',
      'description': 'Grillades de poissons les pieds dans le sable sur la magnifique plage de Ngor.',
      'menu': [
        {
          'name': 'Thiof entier braisé',
          'price': '8 000 FCFA',
          'desc': 'Gros thiof frais aux épices locales, manioc et aloco.',
          'image': 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2',
          'available': true,
          'hygiene': 'Poisson pêché du jour par les pêcheurs de l’île de Ngor.'
        },
      ],
    },
    {
      'name': 'Le Cozy',
      'neighborhood': 'Point E',
      'zone': 'Dakar',
      'cuisine': 'Brasserie & Burgers',
      'rating': 4.4,
      'reviews': 820,
      'price': '3 500 – 9 000 FCFA',
      'phone': '+221 33 824 11 22',
      'whatsapp': '+221 33 824 11 22',
      'address': 'Point E, Dakar',
      'gpsQuery': 'Le Cozy Point E Dakar',
      'image': 'https://images.unsplash.com/photo-1550547660-d9450f859349',
      'description': 'Ambiance cosy et décontractée au Point E, idéal pour des burgers et grillades.',
      'menu': [
        {
          'name': 'Burger double cheddar bacon',
          'price': '6 500 FCFA',
          'desc': 'Deux steaks hachés, double cheddar coulant, bacon croustillant et frites.',
          'image': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd',
          'available': true,
          'hygiene': 'Viande fraîche hachée sur place chaque matin.'
        },
      ],
    },
    {
      'name': 'Le Patio',
      'neighborhood': 'Ouakam',
      'zone': 'Dakar',
      'cuisine': 'Libanaise & Méditerranéenne',
      'rating': 4.5,
      'reviews': 640,
      'price': '3 500 – 10 000 FCFA',
      'phone': '+221 77 123 44 55',
      'whatsapp': '+221 77 123 44 55',
      'address': 'Route de Ouakam, Dakar',
      'gpsQuery': 'Le Patio Ouakam Dakar',
      'image': 'https://images.unsplash.com/photo-1544025162-d76694265947',
      'description': 'Mezzés libanais authentiques, chawarmas et grillades orientales à Ouakam.',
      'menu': [
        {
          'name': 'Assortiment de Mezzés libanais',
          'price': '7 000 FCFA',
          'desc': 'Houmous, moutabal, falafels croustillants et feuilles de vigne.',
          'image': 'https://images.unsplash.com/photo-1541544741938-0af808871cc0',
          'available': true,
          'hygiene': 'Préparation artisanale journalière avec des produits frais.'
        },
      ],
    },

    // --- RUFISQUE ---
    {
      'name': 'Le Requin Rufisque',
      'neighborhood': 'Rufisque Centre',
      'zone': 'Rufisque',
      'cuisine': 'Poissons & Cuisine Sénégalaise',
      'rating': 4.2,
      'reviews': 410,
      'price': '2 500 – 6 000 FCFA',
      'phone': '+221 33 836 10 20',
      'whatsapp': '+221 33 836 10 20',
      'address': 'Boulevard Maurice Delafosse, Rufisque',
      'gpsQuery': 'Rufisque Centre',
      'image': 'https://images.unsplash.com/photo-1537047902294-62a40c20a6ae',
      'description': 'Institution historique de Rufisque proposant du poisson frais et des plats locaux.',
      'menu': [
        {
          'name': 'Thieboudienne rouge de Rufisque',
          'price': '3 000 FCFA',
          'desc': 'Riz au poisson traditionnel préparé selon la pure tradition rufisquoise.',
          'image': 'https://images.unsplash.com/photo-1541544741938-0af808871cc0',
          'available': true,
          'hygiene': 'Poisson frais du port de Rufisque lavé et contrôlé.'
        },
      ],
    },

    // --- DIAMNIADIO / AIBD ---
    {
      'name': 'Diamniadio Express Diner',
      'neighborhood': 'Diamniadio',
      'zone': 'Diamniadio / AIBD',
      'cuisine': 'Fast-Food & Repas Rapides',
      'rating': 4.3,
      'reviews': 450,
      'price': '2 500 – 6 000 FCFA',
      'phone': '+221 78 111 22 33',
      'whatsapp': '+221 78 111 22 33',
      'address': 'Sphères Ministérielles, Diamniadio',
      'gpsQuery': 'Diamniadio Express Diner',
      'image': 'https://images.unsplash.com/photo-1550547660-d9450f859349',
      'description': 'Idéal pour les employés et voyageurs cherchant un repas rapide et savoureux à Diamniadio.',
      'menu': [
        {
          'name': 'Burger Géant Diamniadio',
          'price': '4 500 FCFA',
          'desc': 'Steak haché gros format, cheddar fondant et frites dorées.',
          'image': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd',
          'available': true,
          'hygiene': 'Cuisson express sécurisée et respect des températures.'
        },
      ],
    },
    {
      'name': 'La Halte AIBD',
      'neighborhood': 'AIBD',
      'zone': 'Diamniadio / AIBD',
      'cuisine': 'Traditionnelle & Snack Aéroport',
      'rating': 4.4,
      'reviews': 920,
      'price': '3 000 – 8 000 FCFA',
      'phone': '+221 77 888 99 00',
      'whatsapp': '+221 77 888 99 00',
      'address': 'Route de l’Aéroport Blaise Diagne',
      'gpsQuery': 'Aéroport International Blaise Diagne AIBD',
      'image': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5',
      'description': 'Le point de restauration idéal avant votre vol ou juste après votre atterrissage.',
      'menu': [
        {
          'name': 'Mafé traditionnel au bœuf',
          'price': '3 500 FCFA',
          'desc': 'Tendre bœuf mijoté dans une riche sauce onctueuse à la pâte d’arachide.',
          'image': 'https://images.unsplash.com/photo-1541544741938-0af808871cc0',
          'available': true,
          'hygiene': 'Préparation chaude maintenue à température réglementaire.'
        },
      ],
    },

    // --- PETITE CÔTE (MBOUR, SALY, NGAPAROU, SOMONE, POPENGUINE, NIANING) ---
    {
      'name': 'Le Baobab Saly',
      'neighborhood': 'Saly',
      'zone': 'Petite Côte',
      'cuisine': 'Poissons & Fruits de mer',
      'rating': 4.7,
      'reviews': 1530,
      'price': '4 000 – 12 000 FCFA',
      'phone': '+221 33 957 12 34',
      'whatsapp': '+221 33 957 12 34',
      'address': 'Station Saly, Saly Portudal',
      'gpsQuery': 'Le Baobab Saly Portudal',
      'image': 'https://images.unsplash.com/photo-1537047902294-62a40c20a6ae',
      'description': 'Cadre paradisiaque en bord de mer à Saly, spécialisé dans les produits de la mer.',
      'menu': [
        {
          'name': 'Lotte braisée aux épices douces',
          'price': '9 000 FCFA',
          'desc': 'Queue de lotte fraîche marinée au piment doux et cuite au feu de bois.',
          'image': 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2',
          'available': true,
          'hygiene': 'Poissons de la criée de Mbour contrôlés rigoureusement.'
        },
      ],
    },
    {
      'name': 'La Kaz’ Mbour',
      'neighborhood': 'Mbour',
      'zone': 'Petite Côte',
      'cuisine': 'Sénégalaise & Grillades',
      'rating': 4.5,
      'reviews': 890,
      'price': '2 500 – 7 000 FCFA',
      'phone': '+221 77 412 88 99',
      'whatsapp': '+221 77 412 88 99',
      'address': 'Avenue Demba Diop, Mbour',
      'gpsQuery': 'Mbour Centre',
      'image': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5',
      'description': 'Le repère incontournable des grillades et plats locaux au cœur de Mbour.',
      'menu': [
        {
          'name': 'Poulet Yassa Mbourou',
          'price': '3 000 FCFA',
          'desc': 'Poulet fermier aux oignons caramélisés et riz brisé parfumé.',
          'image': 'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46',
          'available': true,
          'hygiene': 'Volaille fraîche locale lavée au citron et vinaigre.'
        },
      ],
    },
    {
      'name': 'Le Pelican Ngaparou',
      'neighborhood': 'Ngaparou',
      'zone': 'Petite Côte',
      'cuisine': 'Française & Fusion',
      'rating': 4.6,
      'reviews': 710,
      'price': '5 000 – 14 000 FCFA',
      'phone': '+221 33 958 60 50',
      'whatsapp': '+221 33 958 60 50',
      'address': 'Route de la Corniche, Ngaparou',
      'gpsQuery': 'Ngaparou Petite Cote',
      'image': 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4',
      'description': 'Restaurant pieds dans l’eau à Ngaparou proposant une cuisine raffinée.',
      'menu': [
        {
          'name': 'Filet de Dorade royale',
          'price': '8 500 FCFA',
          'desc': 'Dorade fraîche pêchée à Ngaparou, écrasé de pomme de terre.',
          'image': 'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb',
          'available': true,
          'hygiene': 'Produits frais garantis du jour.'
        },
      ],
    },
    {
      'name': 'La Case de la Somone',
      'neighborhood': 'Somone',
      'zone': 'Petite Côte',
      'cuisine': 'Poissons & Spécialités locales',
      'rating': 4.7,
      'reviews': 620,
      'price': '4 000 – 10 000 FCFA',
      'phone': '+221 33 957 88 00',
      'whatsapp': '+221 33 957 88 00',
      'address': 'Lagune de la Somone',
      'gpsQuery': 'Somone Lagoon',
      'image': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e',
      'description': 'Vue imprenable sur la lagune de la Somone avec des poissons frais et grillades.',
      'menu': [
        {
          'name': 'Capitaine grillé de la lagune',
          'price': '7 500 FCFA',
          'desc': 'Poisson capitaine frais grillé aux herbes et bananes plantains.',
          'image': 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2',
          'available': true,
          'hygiene': 'Poissons rigoureusement contrôlés.'
        },
      ],
    },
    {
      'name': 'L’Escale de Popenguine',
      'neighborhood': 'Popenguine',
      'zone': 'Petite Côte',
      'cuisine': 'Traditionnelle & Poissons',
      'rating': 4.5,
      'reviews': 340,
      'price': '3 000 – 8 000 FCFA',
      'phone': '+221 33 952 11 11',
      'whatsapp': '+221 33 952 11 11',
      'address': 'Sanctuaire Popenguine',
      'gpsQuery': 'Popenguine',
      'image': 'https://images.unsplash.com/photo-1544025162-d76694265947',
      'description': 'Restaurant paisible face à l’océan à Popenguine.',
      'menu': [
        {
          'name': 'Couscous de la mer',
          'price': '6 500 FCFA',
          'desc': 'Couscous aux poissons frais de roche et légumes.',
          'image': 'https://images.unsplash.com/photo-1541544741938-0af808871cc0',
          'available': true,
          'hygiene': 'Produits frais locaux préparés dans le respect des normes d’hygiène.'
        },
      ],
    },
    {
      'name': 'Le Palm Beach Nianing',
      'neighborhood': 'Nianing',
      'zone': 'Petite Côte',
      'cuisine': 'Grillades & Plage',
      'rating': 4.6,
      'reviews': 480,
      'price': '4 000 – 11 000 FCFA',
      'phone': '+221 33 957 44 33',
      'whatsapp': '+221 33 957 44 33',
      'address': 'Baie de Nianing',
      'gpsQuery': 'Nianing',
      'image': 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4',
      'description': 'Détente et grillades au bord des baobabs et de la plage à Nianing.',
      'menu': [
        {
          'name': 'Brochettes de lotte marinées',
          'price': '8 000 FCFA',
          'desc': 'Lotte fraîche, poivrons grillés et riz basmati.',
          'image': 'https://images.unsplash.com/photo-1565557623262-b51c2513a641',
          'available': true,
          'hygiene': 'Chaîne du froid respectée et nettoyage constant des cuisines.'
        },
      ],
    },
  ];
}
