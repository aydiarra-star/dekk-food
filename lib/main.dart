import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialisation de Supabase (Remplacez par vos clés si nécessaire)
  await Supabase.initialize(
    url: 'VOTRE_SUPABASE_URL',
    anonKey: 'VOTRE_SUPABASE_ANON_KEY',
  );

  runApp(const DekkFoodApp());
}

class DekkFoodApp extends StatelessWidget {
  const DekkFoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Dekk Food',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.orange,
        scaffoldBackgroundColor: Colors.grey[50],
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Dekk Food - Sénégal',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
        ),
        backgroundColor: Colors.deepOrange,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // CORRIGÉ ICI (anciennement mainCenter)
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Icon(
                Icons.restaurant_menu,
                size: 80,
                color: Colors.deepOrange,
              ),
              const SizedBox(height: 20),
              const Text(
                'Bienvenue sur Dekk Food',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              const Text(
                'Découvrez les meilleurs restaurants et saveurs du Sénégal en un clic.',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: () {
                  // Action future
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                icon: const Icon(Icons.explore),
                label: const Text(
                  'Explorer les restaurants',
                  style: TextStyle(fontSize: 16),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
