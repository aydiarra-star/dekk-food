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

// ==========================================
// 1. ÉCRAN PRINCIPAL : LISTE & RECHERCHE
// ==========================================
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
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    await launchUrl(launchUri);
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
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                          final coverImg = restaurant['cover_photo'] ?? restaurant['image_url'] ?? '';

                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            elevation: 2,
                            child: InkWell(
                              onTap: () {
                                // Redirection vers la Super Fiche Restaurant
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RestaurantDetailScreen(restaurant: restaurant),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: ListTile(
                                  leading: ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: coverImg.isNotEmpty
                                        ? Image.network(
                                            coverImg,
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
                                      Text('${restaurant['neighborhood'] ?? ''} · ${restaurant['price_range'] ?? ''}'),
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

// ==========================================
// 2. LA SUPER FICHE RESTAURANT (DÉTAILS)
// ==========================================
class RestaurantDetailScreen extends StatefulWidget {
  final Map<String, dynamic> restaurant;

  const RestaurantDetailScreen({super.key, required this.restaurant});

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  String _menuSearchQuery = '';

  Future<void> _launchUrl(String urlString) async {
    final Uri uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _makePhoneCall(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    await launchUrl(launchUri);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.restaurant;
    final String name = r['name'] ?? 'Restaurant';
    final double rating = (r['rating'] ?? 4.0).toDouble();
    final int reviewCount = r['review_count'] ?? 0;
    final String neighborhood = r['neighborhood'] ?? 'Dakar';
    final String priceRange = r['price_range'] ?? 'Prix non spécifié';
    final String coverPhoto = r['cover_photo'] ?? r['image_url'] ?? 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4';
    final String description = r['description'] ?? 'Restaurant vérifié par DEKK FOOD proposant de superbes spécialités.';
    final String phone = r['phone'] ?? '';
    final String whatsapp = r['whatsapp'] ?? '';

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 240.0,
            pinned: true,
            backgroundColor: Colors.deepOrange,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(coverPhoto, fit: BoxFit.cover),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.between,
                    children: [
                      Expanded(
                        child: Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green),
                        ),
                        child: const Text('🟢 Ouvert', style: TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.star, color: Colors.amber, size: 18),
                      const SizedBox(width: 4),
                      Text('$rating', style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text(' · ($reviewCount avis) · ', style: const TextStyle(color: Colors.grey)),
                      const Icon(Icons.location_on, color: Colors.red, size: 16),
                      Text(neighborhood),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text('💰 $priceRange', style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.grey)),
                  const SizedBox(height: 16),

                  // Boutons d'Action Rapide
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _buildActionButton(Icons.directions, 'Itinéraire', () {
                        _launchUrl('https://maps.google.com/?q=${Uri.encodeComponent(name + ' ' + neighborhood)}');
                      }),
                      if (phone.isNotEmpty)
                        _buildActionButton(Icons.phone, 'Appeler', () => _makePhoneCall(phone)),
                      if (whatsapp.isNotEmpty)
                        _buildActionButton(Icons.chat, 'WhatsApp', () => _launchUrl('https://wa.me/${whatsapp.replaceAll(RegExp(r'[^0-9]'), '')}')),
                      _buildActionButton(Icons.share, 'Partager', () {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Lien copié !')));
                      }),
                    ],
                  ),
                  const Divider(height: 30),

                  // À propos
                  const Text('À propos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text(description, style: const TextStyle(color: Colors.black87, height: 1.4)),
                  const Divider(height: 30),

                  // Recherche dans le menu (« Que veux-tu manger ? »)
                  const Text('🔎 Rechercher dans le menu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  TextField(
                    onChanged: (value) => setState(() => _menuSearchQuery = value.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Ex: yassa, bissap, gambas...',
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Menu & Spécialités
                  const Text('⭐ Spécialités & Menu', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  _buildMenuItem('Brochettes géantes de gambas', 'Gambas fraîches marinées aux herbes.', '8 500 FCFA'),
                  _buildMenuItem('Filet de zébu sauce poivre', 'Tendre morceau de zébu et frites.', '7 000 FCFA'),
                  _buildMenuItem('Poulet braisé signature', 'Mariné aux épices locales.', '4 500 FCFA'),
                  _buildMenuItem('Jus de Bissap frais', 'Fait maison à la menthe.', '1 000 FCFA'),

                  const Divider(height: 30),

                  // Horaires
                  const Text('🕐 Horaires', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  const Text('Lundi - Jeudi : 11:00 – 23:30'),
                  const Text('Vendredi - Samedi : 11:00 – 00:00'),
                  const Text('Dimanche : 12:00 – 23:00'),
                  const SizedBox(height: 4),
                  const Text('Dernière mise à jour : 13 septembre 2026', style: TextStyle(fontSize: 11, color: Colors.grey)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(IconData icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: Colors.deepOrange.shade50,
            child: Icon(icon, color: Colors.deepOrange, size: 20),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildMenuItem(String title, String desc, String price) {
    if (_menuSearchQuery.isNotEmpty &&
        !title.toLowerCase().contains(_menuSearchQuery) &&
        !desc.toLowerCase().contains(_menuSearchQuery)) {
      return const SizedBox.shrink();
    }

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 1,
      child: ListTile(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(desc, style: const TextStyle(fontSize: 13, color: Colors.grey)),
        trailing: Text(price, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange)),
      ),
    );
  }
}
