import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://bfuvbshocvpfeqfabwti.supabase.co',
    anonKey: 'sb_publishable_HrtEKNqvrIH6PSAHC5FqKw_J0Lgp_6j',
  );

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
      home: const RestaurantListScreen(),
    );
  }
}

class RestaurantListScreen extends StatefulWidget {
  const RestaurantListScreen({super.key});

  @override
  State<RestaurantListScreen> createState() => _RestaurantListScreenState();
}

class _RestaurantListScreenState extends State<RestaurantListScreen> {
  final SupabaseClient _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _restaurants = [];
  List<Map<String, dynamic>> _filteredRestaurants = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchRestaurants();
  }

  Future<void> _fetchRestaurants() async {
    try {
      final response = await _supabase.from('restaurants').select().order('rating', ascending: false);
      setState(() {
        _restaurants = List<Map<String, dynamic>>.from(response);
        _filteredRestaurants = _restaurants;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur lors du chargement : $e')),
        );
      }
    }
  }

  void _filterRestaurants(String query) {
    setState(() {
      _searchQuery = query;
      if (query.isEmpty) {
        _filteredRestaurants = _restaurants;
      } else {
        _filteredRestaurants = _restaurants.where((restaurant) {
          final name = (restaurant['name'] ?? '').toString().toLowerCase();
          final neighborhood = (restaurant['neighborhood'] ?? '').toString().toLowerCase();
          final cuisine = (restaurant['cuisine_type'] ?? '').toString().toLowerCase();
          final search = query.toLowerCase();

          return name.contains(search) || neighborhood.contains(search) || cuisine.contains(search);
        }).toList();
      }
    });
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(
      scheme: 'tel',
      path: phoneNumber,
    );
    await launchUrl(launchUri);
  }

  // Fonction pour retourner des menus et spécialités adaptés selon le restaurant
  Map<String, String> _getMenuAndSpecialty(String restaurantName) {
    switch (restaurantName) {
      case 'Seven Seven Dakar':
        return {
          'specialty': 'Cuisine internationale raffinée et grillades de premier choix.',
          'menus': '• Brochettes géantes de gambas\n• Filet de zébu sauce poivre\n• Cocktails tropicaux maison'
        };
      case 'Restaurant Le Lagon 1':
        return {
          'specialty': 'Gastronomie française et poissons frais avec vue panoramique sur l’océan.',
          'menus': '• Langouste grillée au beurre blanc\n• Mérou à la dieppoise\n• Fondant au chocolat noir'
        };
      case 'YOUYOU':
        return {
          'specialty': 'Plats internationaux branchés, ambiance lounge et moderne.',
          'menus': '• Burgers gourmets signature\n• Wok de poulet aux légumes croquants\n• Tiramisu revisité'
        };
      case 'Casa Teranga':
        return {
          'specialty': 'Fusion entre cuisine locale sénégalaise et saveurs internationales.',
          'menus': '• Thiéboudienne revisité en bento\n• Carpaccio de dorade aux agrumes\n• Poulet Yassa moderne'
        };
      case 'Reine Margarita':
        return {
          'specialty': 'Authentiques pizzas italiennes cuites au feu de bois et pâtes fraîches.',
          'menus': '• Pizza Margherita di Bufala\n• Tagliatelles aux fruits de mer\n• Panna Cotta aux fruits rouges'
        };
      case 'La Fourchette':
        return {
          'specialty': 'Carte internationale variée, cadre climatisé et élégant au Plateau.',
          'menus': '• Entrecôte grillée frites maison\n• Salade César au poulet croustillant\n• Crêpes suzette'
        };
      case 'Chez Fatou':
        return {
          'specialty': 'La référence incontournable de la cuisine sénégalaise traditionnelle les pieds dans l’eau.',
          'menus': '• Ceebu Jën (Riz au poisson traditionnel)\n• Soupou Kandia (Soupe de gombos)\n• Poisson braisé aux oignons confits'
        };
      case 'Club de Pêche':
        return {
          'specialty': 'Spécialités de la mer ultra-fraîches pêchées du jour.',
          'menus': '• Plateau de fruits de mer royal\n• Poisson capitaine grillé\n• Brochettes de lotte'
        };
      case 'Le Coste Dakar':
        return {
          'specialty': 'Cuisine fusion moderne, ambiance chic et branchée.',
          'menus': '• Tataki de thon sésame\n• Filet de bœuf Rossini\n• Moelleux au chocolat coulant'
        };
      case 'Nostra Restaurant':
        return {
          'specialty': 'Saveurs italiennes et méditerranéennes au cœur de Dakar.',
          'menus': '• Lasagnes traditionnelles au four\n• Risotto aux gambas\n• Tiramisu classique'
        };
      case 'Restaurant Altiné':
        return {
          'specialty': 'Saveurs authentiques d’Afrique de l’Ouest et plats sénégalais faits maison.',
          'menus': '• Mafé traditionnel au bœuf\n• Thiéboudienne rouge\n• Bissap frais et gingembre'
        };
      case 'Restaurant Le Carré':
        return {
          'specialty': 'Brasserie chic et lounge aux Almadies, idéal pour dîner ou verre entre amis.',
          'menus': '• Burger Le Carré & frites fraîches\n• Tartare de bœuf à l’italienne\n• Salade gourmande au saumon'
        };
      case 'La Terrasse Farid':
        return {
          'specialty': 'Cuisine libanaise authentique et plats internationaux sur une magnifique terrasse.',
          'menus': '• Assortiment de mezzés libanais\n• Grillades mixtes (chawarma, taouk)\n• Baklavas traditionnels'
        };
      default:
        return {
          'specialty': 'Cuisine variée et de qualité.',
          'menus': '• Plats du chef\n• Desserts maison'
        };
    }
  }

  void _showRestaurantDetails(BuildContext context, Map<String, dynamic> restaurant) {
    final name = restaurant['name'] ?? 'Restaurant';
    final details = _getMenuAndSpecialty(name);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (restaurant['image_url'] != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(restaurant['image_url'], height: 140, width: double.infinity, fit: BoxFit.cover),
                  ),
                const SizedBox(height: 12),
                Text('📍 Quartier : ${restaurant['neighborhood'] ?? 'N/A'}', style: const TextStyle(fontWeight: FontWeight.w500)),
                Text('🍽️ Cuisine : ${restaurant['cuisine_type'] ?? 'N/A'}'),
                Text('⭐ Note : ${restaurant['rating']} (${restaurant['review_count'] ?? 0} avis)'),
                Text('🏠 Adresse : ${restaurant['address'] ?? 'N/A'}'),
                Text('📞 Téléphone : ${restaurant['phone'] ?? 'N/A'}'),
                const Divider(height: 20, thickness: 1.5),
                const Text('🔥 Spécialité :', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                Text(details['specialty'] ?? '', style: const TextStyle(fontStyle: FontStyle.italic)),
                const SizedBox(height: 8),
                const Text('📋 Menus Phares :', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87)),
                Text(details['menus'] ?? ''),
                const SizedBox(height: 10),
                const Text('🟢 Statut : Vérifié par DEKK FOOD', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
          actions: [
            if (restaurant['phone'] != null)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                onPressed: () {
                  _makePhoneCall(restaurant['phone']);
                },
                icon: const Icon(Icons.phone),
                label: const Text('Appeler'),
              ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fermer'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DEKK FOOD - Sénégal', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: Colors.deepOrange,
        centerTitle: true,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              onChanged: _filterRestaurants,
              decoration: InputDecoration(
                hintText: 'Rechercher un restaurant, quartier, spécialité...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => _filterRestaurants(''),
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredRestaurants.isEmpty
                    ? const Center(child: Text('Aucun restaurant trouvé.'))
                    : ListView.builder(
                        itemCount: _filteredRestaurants.length,
                        itemBuilder: (context, index) {
                          final restaurant = _filteredRestaurants[index];
                          final reviews = restaurant['review_count'] ?? 0;
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            elevation: 2,
                            child: InkWell(
                              onTap: () => _showRestaurantDetails(context, restaurant),
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: restaurant['image_url'] != null && restaurant['image_url'].toString().isNotEmpty
                                        ? Image.network(
                                            restaurant['image_url'],
                                            width: 60,
                                            height: 60,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) =>
                                                const Icon(Icons.restaurant, size: 40, color: Colors.deepOrange),
                                          )
                                        : const Icon(Icons.restaurant, size: 40, color: Colors.deepOrange),
                                  ),
                                  title: Text(
                                    restaurant['name'] ?? 'Nom inconnu',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text('${restaurant['cuisine_type'] ?? ''} • ${restaurant['neighborhood'] ?? ''}'),
                                      if (restaurant['phone'] != null)
                                        InkWell(
                                          onTap: () => _makePhoneCall(restaurant['phone']),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 2.0),
                                            child: Text(
                                              '📞 ${restaurant['phone']}',
                                              style: const TextStyle(color: Colors.blue, decoration: TextDecoration.underline),
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  trailing: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          const Icon(Icons.star, color: Colors.amber, size: 18),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${restaurant['rating'] ?? '4.0'}',
                                            style: const TextStyle(fontWeight: FontWeight.bold),
                                          ),
                                        ],
                                      ),
                                      if (reviews > 0)
                                        Text(
                                          '($reviews avis)',
                                          style: const TextStyle(fontSize: 10, color: Colors.grey),
                                        ),
                                    ],
                                  ),
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
