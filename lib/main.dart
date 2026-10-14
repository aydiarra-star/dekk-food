/// DEKK FOOD — catalogue national des établissements du Sénégal.
///
/// Cette version étend l'application existante (parcours découverte → fiche →
/// plat → panier → commande WhatsApp → historique) au catalogue national :
/// l'interface et l'identité visuelle sont conservées, les données codées en
/// dur sont remplacées par le catalogue versionné `assets/data/catalogue.json`.
library;

import 'package:flutter/material.dart';

import 'data/catalogue_repository.dart';
import 'screens/commandes_screen.dart';
import 'screens/decouvrir_screen.dart';
import 'screens/favoris_screen.dart';
import 'screens/panier_screen.dart';
import 'screens/parametres_screen.dart';
import 'state/panier.dart';
import 'widgets/communs.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Le catalogue se charge en mémoire (asset) ; la base est optionnelle.
  await CatalogueRepository.instance.charger();
  runApp(const DekkFoodApp());
}

class DekkFoodApp extends StatelessWidget {
  const DekkFoodApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'DEKK FOOD',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: couleurPrincipale,
        colorScheme: ColorScheme.fromSeed(seedColor: couleurPrincipale),
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
        appBarTheme: const AppBarTheme(
          backgroundColor: couleurPrincipale,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        useMaterial3: true,
      ),
      home: const Accueil(),
    );
  }
}

/// Navigation principale : Découvrir · Favoris · Commandes · Paramètres,
/// avec accès permanent au panier.
class Accueil extends StatefulWidget {
  const Accueil({super.key});

  @override
  State<Accueil> createState() => _AccueilState();
}

class _AccueilState extends State<Accueil> {
  int _onglet = 0;

  static const _ecrans = [
    DecouvrirScreen(),
    FavorisScreen(),
    CommandesScreen(),
    ParametresScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: cartManager,
      builder: (context, _) {
        return Scaffold(
          body: IndexedStack(index: _onglet, children: _ecrans),
          floatingActionButton: cartManager.totalItems == 0
              ? null
              : FloatingActionButton.extended(
                  backgroundColor: couleurPrincipale,
                  foregroundColor: Colors.white,
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const PanierScreen()),
                  ),
                  icon: const Icon(Icons.shopping_cart),
                  label: Text('${cartManager.totalItems} · ${cartManager.subtotal} FCFA'),
                ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _onglet,
            onDestinationSelected: (index) => setState(() => _onglet = index),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.explore_outlined), label: 'Découvrir'),
              NavigationDestination(icon: Icon(Icons.favorite_border), label: 'Favoris'),
              NavigationDestination(icon: Icon(Icons.receipt_long_outlined), label: 'Commandes'),
              NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Paramètres'),
            ],
          ),
        );
      },
    );
  }
}
