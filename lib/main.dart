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
      theme: ThemeData(primarySwatch: Colors.deepOrange),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _restaurants = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final res = await _supabase.from('restaurants').select().order('rating', ascending: false);
      setState(() {
        _restaurants = List<Map<String, dynamic>>.from(res);
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
        title: const Text('DEKK FOOD - Sénégal', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.deepOrange,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _restaurants.length,
              itemBuilder: (context, index) {
                final r = _restaurants[index];
                return Card(
                  margin: const EdgeInsets.all(8),
                  child: ListTile(
                    leading: const Icon(Icons.restaurant, color: Colors.deepOrange, size: 40),
                    title: Text(r['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('${r['neighborhood'] ?? ''} · ⭐ ${r['rating']}'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => DetailsScreen(restaurant: r),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
    );
  }
}

class DetailsScreen extends StatelessWidget {
  final Map<String, dynamic> restaurant;
  const DetailsScreen({super.key, required this.restaurant});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(restaurant['name'] ?? 'Détails'),
        backgroundColor: Colors.deepOrange,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(restaurant['name'] ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Text('📍 Quartier : ${restaurant['neighborhood']}'),
            Text('⭐ Note : ${restaurant['rating']}'),
            Text('📞 Téléphone : ${restaurant['phone'] ?? 'N/A'}'),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: () async {
                final phone = restaurant['phone'];
                if (phone != null) {
                  await launchUrl(Uri(scheme: 'tel', path: phone));
                }
              },
              icon: const Icon(Icons.phone),
              label: const Text('Appeler le restaurant'),
            ),
          ],
        ),
      ),
    );
  }
}
