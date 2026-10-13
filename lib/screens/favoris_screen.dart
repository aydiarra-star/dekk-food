/// Favoris (place-holder de la v2.1.0 devenu fonctionnel).
library;

import 'package:flutter/material.dart';

import '../data/catalogue_repository.dart';
import '../widgets/communs.dart';
import 'decouvrir_screen.dart';
import 'fiche_screen.dart';

class FavorisScreen extends StatelessWidget {
  const FavorisScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final depot = CatalogueRepository.instance;

    return AnimatedBuilder(
      animation: depot,
      builder: (context, _) {
        final favoris = depot.favorisEtablissements;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Mes favoris', style: TextStyle(color: Colors.white)),
            backgroundColor: couleurPrincipale,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: favoris.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.favorite_border, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text('Aucun favori pour le moment', style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 6),
                        const Text(
                          'Touchez le cœur sur une fiche pour la retrouver ici, '
                          'même sans connexion.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: couleurPrincipale,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const DecouvrirScreen()),
                          ),
                          child: const Text('Explorer le catalogue'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: favoris.length,
                  itemBuilder: (context, index) {
                    final etablissement = favoris[index];
                    return ListTile(
                      leading: const Icon(Icons.restaurant, color: couleurPrincipale),
                      title: Text(etablissement.nom),
                      subtitle: Text(etablissement.localisation),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => FicheScreen(etablissement: etablissement)),
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
