import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(const MyApp());
}

// ==========================================
// GESTIONNAIRE GLOBAL DU PANIER (STATE)
// ==========================================
class CartModel extends ChangeNotifier {
  static final CartModel _instance = CartModel._internal();
  factory CartModel() => _instance;
  CartModel._internal();

  String? restaurantName;
  String? restaurantPhone;
  final List<Map<String, dynamic>> items = [];

  int get totalItems {
    int count = 0;
    for (var item in items) {
      count += (item['quantity'] as int);
    }
    return count;
  }

  int get subtotal {
    int sum = 0;
    for (var item in items) {
      int price = int.parse(item['price'].replaceAll(RegExp(r'[^0-9]'), ''));
      sum += price * (item['quantity'] as int);
    }
    return sum;
  }

  void addItem(String resName, String resPhone, Map<String, dynamic> dish, {int quantity = 1}) {
    if (restaurantName != null && restaurantName != resName) {
      return; 
    }
    restaurantName = resName;
    restaurantPhone = resPhone;

    final index = items.indexWhere((i) => i['name'] == dish['name']);
    if (index >= 0) {
      items[index]['quantity'] = (items[index]['quantity'] as int) + quantity;
    } else {
      items.add({
        'name': dish['name'],
        'price': dish['price'],
        'image': dish['image'],
        'quantity': quantity,
      });
    }
    notifyListeners();
  }

  void updateQuantity(int index, int delta) {
    items[index]['quantity'] = (items[index]['quantity'] as int) + delta;
    if (items[index]['quantity'] <= 0) {
      items.removeAt(index);
    }
    if (items.isEmpty) {
      restaurantName = null;
      restaurantPhone = null;
    }
    notifyListeners();
  }

  void clear() {
    restaurantName = null;
    restaurantPhone = null;
    items.clear();
    notifyListeners();
  }
}

final cartManager = CartModel();

class OrderHistoryModel extends ChangeNotifier {
  static final OrderHistoryModel _instance = OrderHistoryModel._internal();
  factory OrderHistoryModel() => _instance;
  OrderHistoryModel._internal();

  final List<Map<String, dynamic>> orders = [];

  void addOrder(Map<String, dynamic> order) {
    orders.insert(0, order);
    notifyListeners();
  }
}

final orderHistoryManager = OrderHistoryModel();

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DEKK FOOD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepOrange),
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        useMaterial3: true,
      ),
      home: const MainNavigationScreen(),
    );
  }
}

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const HomeScreen(),
    const OrdersScreen(),
    const FavoritesScreen(),
    const SettingsScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _screens[_currentIndex],
      bottomNavigationBar: AnimatedBuilder(
        animation: cartManager,
        builder: (context, child) {
          return NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) => setState(() => _currentIndex = index),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.explore_outlined),
                selectedIcon: Icon(Icons.explore, color: Colors.deepOrange),
                label: 'Découvrir',
              ),
              NavigationDestination(
                icon: const Icon(Icons.receipt_long_outlined),
                selectedIcon: const Icon(Icons.receipt_long, color: Colors.deepOrange),
                label: 'Commandes',
              ),
              const NavigationDestination(
                icon: Icon(Icons.favorite_border),
                selectedIcon: Icon(Icons.favorite, color: Colors.deepOrange),
                label: 'Favoris',
              ),
              const NavigationDestination(
                icon: Icon(Icons.settings_outlined),
                selectedIcon: Icon(Icons.settings, color: Colors.deepOrange),
                label: 'Paramètres',
              ),
            ],
          );
        },
      ),
    );
  }
}

// ==========================================
// 1. ÉCRAN DÉCOUVRIR (TOUS LES RESTOS DU SÉNÉGAL)
// ==========================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _searchQuery = '';
  String _selectedNeighborhood = 'Tous';

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
      'description': 'Restaurant spécialisé dans la cuisine internationale et les grillades de premier choix à Ngor.',
      'menu': [
        {
          'name': 'Brochettes géantes de gambas',
          'price': '8 500 FCFA',
          'desc': 'Gambas fraîches marinées aux herbes fines, grillées à la flamme et servies avec du riz parfumé.',
          'image': 'https://images.unsplash.com/photo-1565557623262-b51c2513a641',
          'available': true,
          'hygiene': 'Gambas issues de la pêche locale du jour, contrôlées et déveinées selon les normes strictes d’hygiène HACCP. Cuisine entièrement désinfectée après chaque service.'
        },
        {
          'name': 'Filet de zébu sauce poivre',
          'price': '7 000 FCFA',
          'desc': 'Tendre morceau de zébu sélectionné, nappé d’une sauce au poivre vert et accompagné de frites maison.',
          'image': 'https://images.unsplash.com/photo-1558030006-450675393462',
          'available': true,
          'hygiene': 'Viande certifiée, conservée en chambre froide à température contrôlée. Cuisson à cœur rigoureuse pour garantir sécurité et tendreté.'
        },
        {
          'name': 'Burger signature Seven',
          'price': '6 000 FCFA',
          'desc': 'Bœuf haché pur muscle, cheddar, crudités fraîches du marché et sauce secrète du chef.',
          'image': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd',
          'available': true,
          'hygiene': 'Légumes trempés dans une solution assainissante avant découpe. Personnel portant gants et charlottes en cuisine.'
        },
        {
          'name': 'Jus de Bissap frais',
          'price': '1 000 FCFA',
          'desc': 'Fait maison à la menthe et à la fleur d’oranger, fraîchement pressé.',
          'image': 'https://images.unsplash.com/photo-1556679343-c7306c1976bc',
          'available': true,
          'hygiene': 'Préparé avec de l’eau filtrée et purifiée. Mis en bouteille stérile dans un environnement propre et climatisé.'
        },
      ],
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
        {
          'name': 'Langouste grillée au beurre blanc',
          'price': '14 000 FCFA',
          'desc': 'Pêche locale du jour cuisinée au beurre blanc onctueux.',
          'image': 'https://images.unsplash.com/photo-1535400255456-984241443b28',
          'available': true,
          'hygiene': 'Arrivage direct des pêcheurs artisanaux sans rupture de la chaîne du froid. Contrôle vétérinaire rigoureux.'
        },
        {
          'name': 'Mérou à la dieppoise',
          'price': '8 500 FCFA',
          'desc': 'Poisson frais mijoté aux petits légumes et fruits de mer.',
          'image': 'https://images.unsplash.com/photo-1519708227418-c8fd9a32b7a2',
          'available': true,
          'hygiene': 'Ustensiles en inox stérilisés et plans de travail lavés avec des produits désinfectants professionnels.'
        },
        {
          'name': 'Fondant au chocolat noir',
          'price': '3 500 FCFA',
          'desc': 'Cœur coulant maison au chocolat noir pur beurre de cacao.',
          'image': 'https://images.unsplash.com/photo-1606313564200-e75d5e30476c',
          'available': true,
          'hygiene': 'Ingrédients de première qualité manipulés dans le strict respect de l’hygiène pâtissière.'
        },
      ],
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
        {
          'name': 'Ceebu Jën (Riz au poisson)',
          'price': '3 500 FCFA',
          'desc': 'Le plat national authentique rouge, avec thiof frais, légumes variés du terroir et bissap blanc.',
          'image': 'https://images.unsplash.com/photo-1541544741938-0af808871cc0',
          'available': true,
          'hygiene': 'Poisson frais du marché de Soumbédioune lavé à l’eau purifiée. Cuisson traditionnelle irréprochable.'
        },
        {
          'name': 'Poulet Yassa',
          'price': '3 000 FCFA',
          'desc': 'Poulet fermier mariné longuement aux oignons confits, citron vert et moutarde.',
          'image': 'https://images.unsplash.com/photo-1626777552726-4a6b54c97e46',
          'available': true,
          'hygiene': 'Poulets rigoureusement lavés au vinaigre et citron avant marinade. Cuisine désinfectée en continu.'
        },
        {
          'name': 'Soupou Kandia',
          'price': '3 500 FCFA',
          'desc': 'Soupe de gombos fondants à l’huile de palme, crevettes et morceaux de viande.',
          'image': 'https://images.unsplash.com/photo-1547592180-85f173990554',
          'available': true,
          'hygiene': 'Gombos frais triés un à un et lavés avec soin. Respect strict de la chaîne du chaud.'
        },
      ],
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
        {
          'name': 'Pizza Margherita di Bufala',
          'price': '5 500 FCFA',
          'desc': 'Mozzarella di bufala fondante, sauce tomate italienne et basilic frais.',
          'image': 'https://images.unsplash.com/photo-1574071318508-1cdbab80d002',
          'available': true,
          'hygiene': 'Pâte pétrie chaque matin dans un laboratoire désinfecté. Cuisson au four à bois à haute température.'
        },
        {
          'name': 'Tagliatelles aux fruits de mer',
          'price': '6 500 FCFA',
          'desc': 'Pâtes fraîches maison et gambas sautées à l’ail.',
          'image': 'https://images.unsplash.com/photo-1551183053-bf91a1d81141',
          'available': true,
          'hygiene': 'Produits de la mer frais conservés sous glace contrôlée. Respect des normes d’hygiène.'
        },
      ],
    },
  ];

  @override
  Widget build(BuildContext context) {
    final neighborhoods = ['Tous', 'Plateau', 'Almadies', 'Ngor'];

    final filtered = restaurants.where((r) {
      final name = r['name'].toString().toLowerCase();
      final neighborhood = r['neighborhood'].toString().toLowerCase();
      final cuisine = r['cuisine'].toString().toLowerCase();
      final query = _searchQuery.toLowerCase();

      final matchesSearch = name.contains(query) || neighborhood.contains(query) || cuisine.contains(query);
      final matchesNeighborhood = _selectedNeighborhood == 'Tous' || r['neighborhood'] == _selectedNeighborhood;

      return matchesSearch && matchesNeighborhood;
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('DEKK FOOD - Sénégal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepOrange,
        centerTitle: true,
        actions: [
          AnimatedBuilder(
            animation: cartManager,
            builder: (context, child) {
              if (cartManager.totalItems == 0) return const SizedBox.shrink();
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart, color: Colors.white),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen())),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.yellow, shape: BoxShape.circle),
                      child: Text('${cartManager.totalItems}', style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              onChanged: (val) => setState(() => _searchQuery = val),
              decoration: InputDecoration(
                hintText: 'Rechercher un restaurant, plat ou spécialité...',
                prefixIcon: const Icon(Icons.search, color: Colors.deepOrange),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                filled: true,
                fillColor: Colors.white,
              ),
            ),
          ),
          SizedBox(
            height: 45,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: neighborhoods.length,
              itemBuilder: (context, index) {
                final nbr = neighborhoods[index];
                final isSelected = _selectedNeighborhood == nbr;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(nbr),
                    selected: isSelected,
                    selectedColor: Colors.deepOrange,
                    labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87, fontWeight: FontWeight.bold),
                    onSelected: (selected) {
                      setState(() => _selectedNeighborhood = nbr);
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: filtered.isEmpty
                ? const Center(child: Text('Aucun restaurant trouvé dans cette zone.'))
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final r = filtered[index];
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE5E7EB),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RestaurantDetailScreen(restaurant: r),
                              ),
                            );
                          },
                          child: Padding(
                            padding: const EdgeInsets.all(10.0),
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(10),
                                  child: Image.network(r['image'], width: 75, height: 75, fit: BoxFit.cover),
                                ),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(r['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                      const SizedBox(height: 4),
                                      Text('📍 ${r['neighborhood']} · ${r['cuisine']}', style: const TextStyle(color: Colors.black54, fontSize: 13)),
                                      const SizedBox(height: 6),
                                      Row(
                                        children: [
                                          const Icon(Icons.star, color: Colors.amber, size: 16),
                                          Text(' ${r['rating']} (${r['reviews']} avis)', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
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
// 2. FICHE RESTAURANT COMPLÈTE & LISTE DES PLATS
// ==========================================
class RestaurantDetailScreen extends StatelessWidget {
  final Map<String, dynamic> restaurant;

  const RestaurantDetailScreen({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    final menu = restaurant['menu'] as List;

    return Scaffold(
      appBar: AppBar(
        title: Text(restaurant['name'], style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepOrange,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          AnimatedBuilder(
            animation: cartManager,
            builder: (context, child) {
              if (cartManager.totalItems == 0) return const SizedBox.shrink();
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart, color: Colors.white),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen())),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.yellow, shape: BoxShape.circle),
                      child: Text('${cartManager.totalItems}', style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                        onPressed: () => launchUrl(Uri(scheme: 'tel', path: restaurant['phone'])),
                        icon: const Icon(Icons.phone),
                        label: const Text('Appeler'),
                      ),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
                        onPressed: () => launchUrl(Uri.parse('https://wa.me/${restaurant['whatsapp'].replaceAll(RegExp(r'[^0-9]'), '')}')),
                        icon: const Icon(Icons.chat),
                        label: const Text('WhatsApp'),
                      ),
                    ],
                  ),
                  const Divider(height: 30),
                  const Text('📜 Menu Complet & Commander', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  const Text('Touchez un plat pour voir les détails et les garanties d’hygiène :', style: TextStyle(color: Colors.grey, fontSize: 13)),
                  const SizedBox(height: 12),
                  ...menu.map((item) {
                    final bool isAvailable = item['available'] ?? true;
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      elevation: 1,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DishDetailScreen(
                                restaurant: restaurant,
                                dish: item,
                              ),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(10.0),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item['image'],
                                  width: 70,
                                  height: 70,
                                  fit: BoxFit.cover,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                    const SizedBox(height: 2),
                                    Text(item['desc'], maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                    const SizedBox(height: 4),
                                    Text(item['price'], style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange, fontSize: 13)),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              isAvailable
                                  ? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.deepOrange)
                                  : const Text('Indisponible', style: TextStyle(color: Colors.red, fontSize: 11)),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: cartManager,
        builder: (context, child) {
          if (cartManager.totalItems == 0 || cartManager.restaurantName != restaurant['name']) {
            return const SizedBox.shrink();
          }
          return Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.all(14)),
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen())),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_cart),
                  const SizedBox(width: 8),
                  Text('Passer la commande (${cartManager.totalItems} articles) · ${cartManager.subtotal} FCFA', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

// ==========================================
// 3. PAGE DÉTAIL DU PLAT, HYGIÈNE & COMMANDE
// ==========================================
class DishDetailScreen extends StatefulWidget {
  final Map<String, dynamic> restaurant;
  final Map<String, dynamic> dish;

  const DishDetailScreen({super.key, required this.restaurant, required this.dish});

  @override
  State<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends State<DishDetailScreen> {
  int quantity = 1;

  void _addToCartAndNotify() {
    final resName = widget.restaurant['name'];
    final resPhone = widget.restaurant['phone'];

    if (cartManager.restaurantName != null && cartManager.restaurantName != resName) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Changer de restaurant ?'),
          content: Text('Votre panier contient des articles de ${cartManager.restaurantName}. Voulez-vous le vider pour commander chez $resName ?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
              onPressed: () {
                cartManager.clear();
                cartManager.addItem(resName, resPhone, widget.dish, quantity: quantity);
                Navigator.pop(ctx);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$quantity x ${widget.dish['name']} ajouté au panier !')));
              },
              child: const Text('Vider et continuer'),
            ),
          ],
        ),
      );
    } else {
      cartManager.addItem(resName, resPhone, widget.dish, quantity: quantity);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$quantity x ${widget.dish['name']} ajouté au panier !')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.dish['name'], style: const TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepOrange,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          AnimatedBuilder(
            animation: cartManager,
            builder: (context, child) {
              if (cartManager.totalItems == 0) return const SizedBox.shrink();
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart, color: Colors.white),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const CartScreen())),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(color: Colors.yellow, shape: BoxShape.circle),
                      child: Text('${cartManager.totalItems}', style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Image.network(
              widget.dish['image'],
              height: 280,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          widget.dish['name'],
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                      ),
                      Text(
                        widget.dish['price'],
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepOrange),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Restaurant : ${widget.restaurant['name']} (📍 ${widget.restaurant['neighborhood']})',
                    style: const TextStyle(color: Colors.grey, fontSize: 14),
                  ),
                  const SizedBox(height: 16),
                  const Text('Description du plat', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 6),
                  Text(
                    widget.dish['desc'],
                    style: const TextStyle(fontSize: 15, color: Colors.black87, height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  
                  // Encadré hygiène et propreté rassurant
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.green.shade50,
                      border: Border.all(color: Colors.green.shade200),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.verified, color: Colors.green, size: 22),
                            SizedBox(width: 8),
                            Text(
                              'Garantie Hygiène & Propreté',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.dish['hygiene'] ?? 'Ingrédients frais rigoureusement contrôlés, préparés dans le strict respect des normes d’hygiène et de sécurité alimentaire DEKK FOOD.',
                          style: const TextStyle(fontSize: 13.5, color: Colors.black87, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Sélecteur de quantité
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Quantité : ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 28, color: Colors.deepOrange),
                        onPressed: () {
                          if (quantity > 1) setState(() => quantity--);
                        },
                      ),
                      Text('$quantity', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 28, color: Colors.deepOrange),
                        onPressed: () => setState(() => quantity++),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        color: Colors.white,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepOrange,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(14),
          ),
          onPressed: _addToCartAndNotify,
          child: Text(
            'Commander · (${int.parse(widget.dish['price'].replaceAll(RegExp(r'[^0-9]'), '')) * quantity} FCFA)',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 4. ÉCRAN PANIER & CHECKOUT
// ==========================================
class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon Panier', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepOrange,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: AnimatedBuilder(
        animation: cartManager,
        builder: (context, child) {
          if (cartManager.items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.shopping_cart_outlined, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text('Votre panier est vide.', style: TextStyle(fontSize: 16, color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Découvrir les restaurants'),
                  ),
                ],
              ),
            );
          }

          return Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.orange.shade50,
                child: Text('Restaurant : ${cartManager.restaurantName}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: cartManager.items.length,
                  itemBuilder: (context, index) {
                    final item = cartManager.items[index];
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.network(item['image'], width: 50, height: 50, fit: BoxFit.cover),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['name'], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                  Text(item['price'], style: const TextStyle(color: Colors.deepOrange, fontSize: 12)),
                                ],
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, size: 20),
                                  onPressed: () => cartManager.updateQuantity(index, -1),
                                ),
                                Text('${item['quantity']}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                IconButton(
                                  icon: const Icon(Icons.add_circle_outline, size: 20),
                                  onPressed: () => cartManager.updateQuantity(index, 1),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)]),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Sous-total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        Text('${cartManager.subtotal} FCFA', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white, padding: const EdgeInsets.all(14)),
                        onPressed: () {
                          Navigator.push(context, MaterialPageRoute(builder: (context) => const CheckoutScreen()));
                        },
                        child: const Text('Finaliser la commande', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

// ==========================================
// 5. CHECKOUT & WHATSAPP
// ==========================================
class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  String _orderType = 'Livraison';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finaliser la commande', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.deepOrange,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Mode de réception', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Row(
                children: [
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Livraison'),
                      value: 'Livraison',
                      groupValue: _orderType,
                      onChanged: (val) => setState(() => _orderType = val!),
                    ),
                  ),
                  Expanded(
                    child: RadioListTile<String>(
                      title: const Text('Retrait'),
                      value: 'Retrait',
                      groupValue: _orderType,
                      onChanged: (val) => setState(() => _orderType = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Votre Nom *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Veuillez entrer votre nom' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Numéro de téléphone *', border: OutlineInputBorder()),
                validator: (val) => val == null || val.isEmpty ? 'Veuillez entrer votre numéro' : null,
              ),
              if (_orderType == 'Livraison') ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _addressController,
                  decoration: const InputDecoration(labelText: 'Adresse de livraison *', border: OutlineInputBorder()),
                  validator: (val) => _orderType == 'Livraison' && (val == null || val.isEmpty) ? 'Adresse obligatoire' : null,
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white, padding: const EdgeInsets.all(14)),
                  onPressed: () async {
                    if (_formKey.currentState!.validate()) {
                      final orderId = 'DF-${DateTime.now().year}${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${DateTime.now().millisecondsSinceEpoch.toString().substring(8)}';
                      
                      final orderData = {
                        'orderId': orderId,
                        'restaurantName': cartManager.restaurantName,
                        'restaurantPhone': cartManager.restaurantPhone,
                        'items': List<Map<String, dynamic>>.from(cartManager.items),
                        'subtotal': cartManager.subtotal,
                        'name': _nameController.text,
                        'phone': _phoneController.text,
                        'address': _addressController.text,
                        'orderType': _orderType,
                        'date': DateTime.now().toString().substring(0, 16),
                        'status': 'En attente de confirmation',
                      };

                      orderHistoryManager.addOrder(orderData);

                      String msg = "Bonjour,\nNouvelle commande DEKK FOOD #$orderId\nRestaurant : ${cartManager.restaurantName}\n\nClient :\nNom : ${_nameController.text}\nTéléphone : ${_phoneController.text}\nMode : $_orderType\nAdresse : ${_addressController.text}\n\nCommande :\n";
                      for (var item in cartManager.items) {
                        msg += "- ${item['quantity']} × ${item['name']} (${item['price']})\n";
                      }
                      msg += "\nSous-total : ${cartManager.subtotal} FCFA\n(Commandé via DEKK FOOD)";

                      final whatsappUrl = Uri.parse('https://wa.me/${cartManager.restaurantPhone?.replaceAll(RegExp(r'[^0-9]'), '')}?text=${Uri.encodeComponent(msg)}');
                      
                      cartManager.clear();

                      if (await canLaunchUrl(whatsappUrl)) {
                        await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
                      }

                      if (context.mounted) {
                        Navigator.pushAndRemoveUntil(
                          context,
                          MaterialPageRoute(builder: (context) => OrderSuccessScreen(order: orderData)),
                          (route) => false,
                        );
                      }
                    }
                  },
                  child: const Text('Confirmer la commande (WhatsApp)', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ==========================================
// 6. ÉCRAN DE SUCCÈS & HISTORIQUE
// ==========================================
class OrderSuccessScreen extends StatelessWidget {
  final Map<String, dynamic> order;
  const OrderSuccessScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Commande Envoyée', style: TextStyle(color: Colors.white)), backgroundColor: Colors.deepOrange),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 80),
              const SizedBox(height: 16),
              const Text('🎉 Commande envoyée avec succès !', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Commande #${order['orderId']}', style: const TextStyle(fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 20),
              Text('Restaurant : ${order['restaurantName']}', style: const TextStyle(fontSize: 16)),
              Text('Montant : ${order['subtotal']} FCFA', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.deepOrange)),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.deepOrange, foregroundColor: Colors.white),
                onPressed: () {
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (context) => const MainNavigationScreen()),
                    (route) => false,
                  );
                },
                child: const Text('Retour à l’accueil'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes Commandes', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepOrange,
        centerTitle: true,
      ),
      body: AnimatedBuilder(
        animation: orderHistoryManager,
        builder: (context, child) {
          if (orderHistoryManager.orders.isEmpty) {
            return const Center(child: Text('Aucune commande enregistrée pour le moment.', style: TextStyle(color: Colors.grey)));
          }
          return ListView.builder(
            itemCount: orderHistoryManager.orders.length,
            itemBuilder: (context, index) {
              final ord = orderHistoryManager.orders[index];
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                child: ListTile(
                  title: Text('#${ord['orderId']} - ${ord['restaurantName']}', style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text('Total : ${ord['subtotal']} FCFA · ${ord['date']}\nStatut : ${ord['status']}'),
                  isThreeLine: true,
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.deepOrange),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mes Favoris', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.deepOrange, centerTitle: true),
      body: const Center(child: Text('Aucun favori pour le moment.', style: TextStyle(color: Colors.grey))),
    );
  }
}

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Paramètres', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: Colors.deepOrange, centerTitle: true),
      body: ListView(
        children: const [
          ListTile(leading: Icon(Icons.language, color: Colors.deepOrange), title: Text('Langue'), subtitle: Text('Français')),
          ListTile(leading: Icon(Icons.location_city, color: Colors.deepOrange), title: Text('Ville'), subtitle: Text('Dakar, Sénégal')),
          ListTile(leading: Icon(Icons.info_outline, color: Colors.deepOrange), title: Text('DEKK FOOD'), subtitle: Text('Version 1.5.0 - Production Ready')),
        ],
      ),
    );
  }
}
