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
        // Parcours public : seules les fiches publiées sont listées et ouvrables.
        // Les favoris pointant vers une fiche non publiée ou disparue sont
        // signalés juste en dessous, sans diffuser leurs données.
        final favoris = depot.favorisPublies;
        final horsPublication = depot.favorisNonPublies.length;
        final orphelins = depot.favorisOrphelins.length;

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
                        Text(
                          (horsPublication + orphelins) > 0
                              ? 'Aucun favori publié'
                              : 'Aucun favori pour le moment',
                          style: const TextStyle(fontSize: 16),
                        ),
                        if ((horsPublication + orphelins) > 0) ...[
                          const SizedBox(height: 6),
                          Text(
                            '$horsPublication fiche(s) enregistrée(s) en favori ne sont pas publiées'
                            '${orphelins > 0 ? ' et $orphelins ne figurent plus dans le catalogue' : ''}. '
                            'Elles ne sont pas affichées ici.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                        ],
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
                  itemCount: favoris.length + ((horsPublication + orphelins) > 0 ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == favoris.length) {
                      return _AvisFavorisIndisponibles(
                        horsPublication: horsPublication,
                        orphelins: orphelins,
                      );
                    }
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

/// Avis affiché à la fin des favoris lorsqu'une fiche enregistrée n'est pas
/// publiable : aucune donnée de ces fiches n'est diffusée ici.
class _AvisFavorisIndisponibles extends StatelessWidget {
  final int horsPublication;
  final int orphelins;

  const _AvisFavorisIndisponibles({required this.horsPublication, required this.orphelins});

  @override
  Widget build(BuildContext context) {
    final details = <String>[
      if (horsPublication > 0)
        '$horsPublication fiche(s) enregistrée(s) en favori ne sont pas publiées '
            '(conservées dans la base interne, non affichées publiquement).',
      if (orphelins > 0)
        '$orphelins favori(s) ne correspondent plus à aucune fiche du catalogue.',
    ];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      child: BandeauInformation(
        couleur: Colors.orange,
        icone: Icons.info_outline,
        message: '${details.join(' ')} Vos favoris sont conservés : ils réapparaîtront '
            'si les fiches sont publiées.',
      ),
    );
  }
}
