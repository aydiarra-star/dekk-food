import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

// ==========================================
// 1. POINT D'ENTRÉE & CONFIGURATION
// ==========================================
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // REMPLACER ICI PAR VOS IDENTIFIANTS SUPABASE DÈS CRÉATION DU PROJET
  await Supabase.initialize(
    url: 'https://VOTRE_PROJET_SUPABASE.supabase.co',
    anonKey: 'VOTRE_CLE_ANONYME_SUPABASE',
  );

  runApp(const DekkFoodApp());
}

class DekkFoodApp extends StatelessWidget {
  const DekkFoodApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DEKK FOOD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.deepOrange,
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

// ==========================================
// 2. MODÈLES DE DONNÉES
// ==========================================
class Restaurant {
  final String id;
  final String name;
  final String cuisineType;
  final String neighborhood;
  final String? address;
  final String? phone;
  final String? whatsapp;
  final double? latitude;
  final double? longitude;

  Restaurant({
    required this.id,
    required this.name,
    required this.cuisineType,
    required this.neighborhood,
    this.address,
    this.phone,
    this.whatsapp,
    this.latitude,
    this.longitude,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    return Restaurant(
      id: json['id'],
      name: json['name'],
      cuisineType: json['cuisine_type'],
      neighborhood: json['neighborhood'],
      address: json['address'],
      phone: json['phone'],
      whatsapp: json['whatsapp'],
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
    );
  }
}

class MenuItem {
  final String id;
  final String restaurantId;
  final String title;
  final String? description;
  final double price;
  final String? category;

  MenuItem({
    required this.id,
    required this.restaurantId,
    required this.title,
    this.description,
    required this.price,
    this.category,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id'],
      restaurantId: json['restaurant_id'],
      title: json['title'],
      description: json['description'],
      price: (json['price'] as num).toDouble(),
      category: json['category'],
    );
  }
}

// ==========================================
// 3. SERVICE SUPABASE
// ==========================================
class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<List<Restaurant>> getRestaurants({String? neighborhoodQuery}) async {
    var query = _client.from('restaurants').select().eq('is_active', true);

    if (neighborhoodQuery != null && neighborhoodQuery.isNotEmpty) {
      query = query.ilike('neighborhood', '%$neighborhoodQuery%');
    }

    final response = await query;
    return (response as List).map((json) => Restaurant.fromJson(json)).toList();
  }

  Future<List<MenuItem>> getMenuItems(String restaurantId) async {
    final response = await _client
        .from('menu_items')
        .select()
        .eq('restaurant_id', restaurantId)
        .eq('is_available', true);

    return (response as List).map((json) => MenuItem.fromJson(json)).toList();
  }
}

// ==========================================
// 4. ÉCRAN PRINCIPAL (RECHERCHE & LISTE)
// ==========================================
class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  final TextEditingController _searchController = TextEditingController();
  List<Restaurant> _restaurants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchRestaurants();
  }

  Future<void> _fetchRestaurants({String? query}) async {
    setState(() => _isLoading = true);
    try {
      final data = await _supabaseService.getRestaurants(neighborhoodQuery: query);
      setState(() {
        _restaurants = data;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('DEKK FOOD'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Rechercher par quartier (ex: Almadies, Plateau...)',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _searchController.clear();
                    _fetchRestaurants();
                  },
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onSubmitted: (value) => _fetchRestaurants(query: value),
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _restaurants.isEmpty
                    ? const Center(child: Text('Aucun restaurant trouvé.'))
                    : ListView.builder(
                        itemCount: _restaurants.length,
                        itemBuilder: (context, index) {
                          final resto = _restaurants[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: ListTile(
                              leading: const CircleAvatar(
                                backgroundColor: Colors.deepOrange,
                                child: Icon(Icons.restaurant, color: Colors.white),
                              ),
                              title: Text(resto.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('${resto.cuisineType} • ${resto.neighborhood}'),
                              trailing: const Icon(Icons.chevron_right),
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => RestaurantDetailScreen(restaurant: resto),
                                  ),
                                );
                              },
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
// 5. ÉCRAN DÉTAIL RESTAURANT & MENU
// ==========================================
class RestaurantDetailScreen extends StatefulWidget {
  final Restaurant restaurant;

  const RestaurantDetailScreen({Key? key, required this.restaurant}) : super(key: key);

  @override
  State<RestaurantDetailScreen> createState() => _RestaurantDetailScreenState();
}

class _RestaurantDetailScreenState extends State<RestaurantDetailScreen> {
  final SupabaseService _supabaseService = SupabaseService();
  List<MenuItem> _menuItems = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchMenu();
  }

  Future<void> _fetchMenu() async {
    try {
      final items = await _supabaseService.getMenuItems(widget.restaurant.id);
      setState(() {
        _menuItems = items;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _openWhatsApp(String number) async {
    final cleanNumber = number.replaceAll(RegExp(r'[^\d+]'), '');
    final url = Uri.parse('https://wa.me/$cleanNumber');
    if (await canLaunchUrl(url)) {
      await launchUrl(url, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.restaurant.name),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.restaurant.name,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            Text(
              '${widget.restaurant.cuisineType} • ${widget.restaurant.neighborhood}',
              style: TextStyle(color: Colors.grey[700], fontSize: 16),
            ),
            if (widget.restaurant.address != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.location_on, size: 18, color: Colors.deepOrange),
                  const SizedBox(width: 4),
                  Expanded(child: Text(widget.restaurant.address!)),
                ],
              ),
            ],
            const SizedBox(height: 16),
            if (widget.restaurant.whatsapp != null)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () => _openWhatsApp(widget.restaurant.whatsapp!),
                  icon: const Icon(Icons.chat),
                  label: const Text('Contacter sur WhatsApp'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
            const Divider(height: 32),
            const Text(
              'Menu',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _menuItems.isEmpty
                    ? const Text('Aucun plat disponible pour le moment.')
                    : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _menuItems.length,
                        itemBuilder: (context, index) {
                          final item = _menuItems[index];
                          return Card(
                            child: ListTile(
                              title: Text(item.title, style: const TextStyle(fontWeight: FontWeight.w600)),
                              subtitle: item.description != null ? Text(item.description!) : null,
                              trailing: Text(
                                '${item.price.toStringAsFixed(0)} FCFA',
                                style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.deepOrange),
                              ),
                            ),
                          );
                        },
                      ),
          ],
        ),
      ),
    );
  }
}
