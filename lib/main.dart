import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DEKK FOOD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

// ==========================================
// BARRE DE NAVIGATION PRINCIPALE (2026)
// ==========================================
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const FavoritesScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.explore_outlined),
            selectedIcon: Icon(Icons.explore, color: Colors.deepOrange),
            label: 'Découvrir',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_border),
            selectedIcon: Icon(Icons.favorite, color: Colors.deepOrange),
            label: 'Favoris',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings, color: Colors.deepOrange),
            label: 'Paramètres',
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 1. ÉCRAN DÉCOUVRIR (LISTE DES RESTOS DE DAKAR)
// ==========================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';

  // Les plus grands restaurants de Dakar avec menus, prix, avis et localisation complets
  final List<Map<String, dynamic>> restaurants = const [
    {
      'name': 'Seven Seven Dakar',
      'neighborhood': 'Ngor',
      'cuisine': 'International & Grillades',
      'rating': 4.8,
      'reviews': 2122,
      'price': '3 000 – 10 000 FCFA',
      'phone': '+221 78 593 78 78',
      'whatsapp': '+221 78 593 78 78',
      'address': 'Route de Ngor, Dakar',
      'image': 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4',
      'description': 'Restaurant spécialisé dans la cuisine internationale et les grillades de premier choix dans un cadre exceptionnel à Ngor.',
      'menu': [
        {'name': 'Brochettes géantes de gambas', 'price': '8 500 FCFA', 'desc': 'Gambas fraîches marinées aux herbes.'},
        {'name': 'Filet de zébu sauce poivre', 'price': '7 000 FCFA', 'desc': 'Tendre morceau de zébu et frites maison.'},
        {'name': 'Jus de Bissap frais', 'price': '1 000 FCFA', 'desc': 'Fait maison à la menthe.'},
      ],
      'reviews_list': [
        {'author': 'Mamadou Diallo', 'rating': 5, 'comment': 'Superbe cadre à Ngor, les gambas étaient exceptionnelles !'},
        {'author': 'Awa Ndiaye', 'rating': 4, 'comment': 'Très bon service et plats délicieux.'},
      ]
    },
    {
      'name': 'Restaurant Le Lagon 1',
      'neighborhood': 'Plateau',
      'cuisine': 'Française & Poissons',
      'rating': 4.4,
      'reviews': 2345,
      'price': '5 000 – 15 000 FCFA',
      'phone': '+221 33 821 53 22',
      'whatsapp': '+221 33 821 53 22',
      'address': 'Route de la Corniche Est, Dakar',
      'image': 'https://images.unsplash.com/photo-1544025162-d76694265947',
      'description': 'Gastronomie française et poissons frais avec vue panoramique sur l’océan au Plateau.',
      'menu': [
        {'name': 'Langouste grillée au beurre blanc', 'price': '14 000 FCFA', 'desc': 'Pêche locale du jour.'},
        {'name': 'Mérou à la dieppoise', 'price': '8 500 FCFA', 'desc': 'Poisson frais mijoté aux petits légumes.'},
        {'name': 'Fondant au chocolat noir', 'price': '3 500 FCFA', 'desc': 'Cœur coulant maison.'},
      ],
      'reviews_list': [
        {'author': 'Jean Dupont', 'rating': 5, 'comment': 'Vue imprenable et cuisine gastronomique irréprochable.'},
      ]
    },
    {
      'name': 'Chez Fatou',
      'neighborhood': 'Almadies',
      'cuisine': 'Sénégalaise & Grillades',
      'rating': 4.0,
      'reviews': 2265,
      'price': '3 000 – 8 000 FCFA',
      'phone': '+221 33 820 92 38',
      'whatsapp': '+221 33 820 92 38',
      'address': 'Corniche des Almadies, Dakar',
      'image': 'https://images.unsplash.com/photo-1537047902294-62a40c20a6ae',
      'description': 'La référence incontournable de la cuisine sénégalaise traditionnelle les pieds dans l’eau aux Almadies.',
      'menu': [
        {'name': 'Ceebu Jën (Riz au poisson)', 'price': '3 500 FCFA', 'desc': 'Le plat national authentique rouge.'},
        {'name': 'Poulet Yassa', 'price': '3 000 FCFA', 'desc': 'Poulet mariné oignons et citron vert.'},
        {'name': 'Thiéboudienne poulet', 'price': '3 500 FCFA', 'desc': 'Riz au poisson blanc ou poulet.'},
      ],
      'reviews_list': [
        {'author': 'Fatou Sow', 'rating': 4, 'comment': 'Le meilleur ceebu jën de Dakar, ambiance authentique.'},
      ]
    },
    {
      'name': 'Reine Margarita',
      'neighborhood': 'Plateau',
      'cuisine': 'Italienne & Pizzeria',
      'rating': 4.4,
      'reviews': 396,
      'price': '3 000 – 7 000 FCFA',
      'phone': '+221 78 444 99 55',
      'whatsapp': '+221 78 444 99 55',
      'address': 'Dakar Plateau',
      'image': 'https://images.unsplash.com/photo-1513104890138-7c749659a591',
      'description': 'Authentiques pizzas italiennes cuites au feu de bois et pâtes fraîches au cœur de Dakar.',
      'menu': [
        {'name': 'Pizza Margherita di Bufala', 'price': '5 500 FCFA', 'desc': 'Mozzarella di bufala et basilic frais.'},
        {'name': 'Tagliatelles aux fruits de mer', 'price': '6 500 FCFA', 'desc': 'Pâtes fraîches et gambas.'},
        {'name': 'Tiramisu classique', 'price': '3 000 FCFA', 'desc': 'Recette italienne traditionnelle.'},
      ],
      'reviews_list': [
        {'author': 'Omar Ba', 'rating': 5, 'comment': 'Pizza croustillante et goûteuse, un régal !'},
      ]
    },
    {
      'name': 'La Fourchette',
      'neighborhood': 'Plateau',
      'cuisine': 'Internationale & Grillades',
      'rating': 4.3,
      'reviews': 1110,
      'price': '4 000 – 12 000 FCFA',
      'phone': '+221 33 842 66 66',
      'whatsapp': '+221 33 842 66 66',
      'address': 'Rue Parent, Dakar Plateau',
      'image': 'https://images.unsplash.com/photo-1559339352-11d035aa65de',
      'description': 'Cadre élégant et climatisé proposant une carte variée de plats internationaux et grillades.',
      'menu': [
        {'name': 'Entrecôte grillée frites maison', 'price': '9 000 FCFA', 'desc': 'Viande tendre et sauce au choix.'},
        {'name': 'Salade César au poulet', 'price': '4 500 FCFA', 'desc': 'Laitue, croûtons, parmesan et poulet croustillant.'},
      ],
      'reviews_list': [
        {'author': 'Sophie Martin', 'rating': 4, 'comment': 'Idéal pour un déjeuner d’affaires au Plateau.'},
      ]
    },
  ];

  @override
  Widget build(BuildContext context) {
    final filteredRestaurants = restaurants.where((r) {
      final name = r['name'].toString().toLowerCase();
      final neighborhood = r['neighborhood'].toString().toLowerCase();
      final cuisine = r['cuisine'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();
      return name.contains(query) || neighborhood.contains(query) || cuisine.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('DEKK FOOD - Sénégal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepOrange,
        centerTitle: true,
      ),
      body: Column(
        children: [
          // Barre de recherche fluide
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Rechercher un restaurant, quartier, spécialité...',
                prefixIcon: const Icon(Icons.search, color: Colors.deepOrange),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                filled: true,
                fillColor: Colors.grey.shade100,
              ),
            ),
          ),
          Expanded(
            child: filteredRestaurants.isEmpty
                ? const Center(child: Text('Aucun restaurant trouvé.'))
                : ListView.builder(
                    itemCount: filteredRestaurants.length,
                    itemBuilder: (context, index) {
                      final r = filteredRestaurants[index];
                      return Card(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RestaurantDetailScreen(restaurant: r),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(r['image'], width: 70, height: 70, fit: BoxFit.cover),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(r['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(height: 4),
                                      Text('${r['neighborhood']} · ${r['cuisine']}', style: const TextStyle(color: Colors.grey, fontSize: 13)),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.star, color: Colors.amber, size: 16),
                                          Text(' ${r['rating']} (${r['reviews']} avis)', style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 12)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.deepOrange),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 2. FICHE RESTAURANT COMPLÈTE & IMMERSIVE
// ==========================================
class RestaurantDetailScreen extends StatelessWidget {
  final Map<String, dynamic> restaurant;

  const RestaurantDetailScreen({super.key, required this.restaurant});

  Future<void> _makePhoneCall(String phone) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phone);
    await launchUrl(launchUri);
  }

  Future<void> _openWhatsApp(String whatsapp) async {
    final Uri uri = Uri.parse('https://wa.me/${whatsapp.replaceAll(RegExp(r'[^0-9]'), '')}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _openMap(String address) async {
    final Uri uri = Uri.parse('https://maps.google.com/?q=${Uri.encodeComponent(address)}');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    final menu = restaurant['menu'] as List;
    final reviewsList = restaurant['reviews_list'] as List;

    return Scaffold(
      appBar: AppBar(
        title: Text(restaurant['name'], style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepOrange,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Grande photo de couverture
            Image.network(restaurant['image'], height: 230, width: double.infinity, fit: BoxFit.cover),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(restaurant['name'], style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      Text(' ${restaurant['rating']} (${restaurant['reviews']} avis) · 📍 ${restaurant['neighborhood']}'),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('💰 ${restaurant['price']}', style: const TextStyle(color: Colors.grey, fontWeight: FontWeight.w500)),
                  const SizedBox(height: 16),

                  // Boutons d'action rapide
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        onPressed: () => _makePhoneCall(restaurant['phone']),
                        icon: const Icon(Icons.phone),
                        label: const Text('Appeler'),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                        onPressed: () => _openWhatsApp(restaurant['whatsapp']),
                        icon: const Icon(Icons.chat),
                        label: const Text('WhatsApp'),
                      ),
                    ],
                  ),
                  const Divider(height: 30),

                  // À propos
                  const Text('À propos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(restaurant['description'], style: const TextStyle(color: Colors.black87, height: 1.4)),
                  const Divider(height: 30),

                  // Spécialités & Menu
                  const Text('⭐ Spécialités & Menu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...menu.map((item) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        elevation: 1,
                        child: ListTile(
                          title: Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                          subtitle: Text(item['desc'], style: const TextStyle(fontSize: 13, color: Colors.grey)),
                          trailing: Text(item['price'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                        ),
                      )),
                  const Divider(height: 30),

                  // Localisation
                  const Text('📍 Localisation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Text(restaurant['address']),
                  const SizedBox(height: 10),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
                    onPressed: () => _openMap(restaurant['address']),
                    icon: const Icon(Icons.map),
                    label: const Text('Voir l’itinéraire sur la carte'),
                  ),
                  const Divider(height: 30),

                  // Avis clients
                  const Text('⭐ Avis des clients', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  ...reviewsList.map((rev) => Card(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        color: Colors.grey.shade50,
                        elevation: 0,
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(rev['author'], style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const Spacer(),
                                  const Icon(Icons.star, color: Colors.amber, size: 16),
                                  Text(' ${rev['rating']}/5'),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(rev['comment'], style: const TextStyle(color: Colors.black87)),
                            ],
                          ),
                        ),
                      )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 3. ÉCRAN FAVORIS
// ==========================================
class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Favoris', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepOrange,
        centerTitle: true,
      ),
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.favorite_border, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text('Aucun favori pour le moment.', style: TextStyle(color: Colors.grey, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 4. ÉCRAN PARAMÈTRES
// ==========================================
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepOrange,
        centerTitle: true,
      ),
      body: ListView(
        children: const [
          ListTile(
            leading: Icon(Icons.language, color: Colors.deepOrange),
            title: Text('Langue'),
            subtitle: Text('Français'),
          ),
          ListTile(
            leading: Icon(Icons.location_city, color: Colors.deepOrange),
            title: Text('Ville par défaut'),
            subtitle: Text('Dakar, Sénégal'),
          ),
          ListTile(
            leading: Icon(Icons.info_outline, color: Colors.deepOrange),
            title: Text('À propos de DEKK FOOD'),
            subtitle: Text('Version 1.0.0 (Standards 2026)'),
          ),
        ],
      ),
    );
  }
}
