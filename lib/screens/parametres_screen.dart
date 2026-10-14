/// Paramètres, informations légales et accès aux contributions.
library;

import 'package:flutter/material.dart';

import '../data/catalogue_repository.dart';
import '../widgets/communs.dart';
import 'contributions_screen.dart';
import 'diagnostic_screen.dart';

class ParametresScreen extends StatelessWidget {
  const ParametresScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final depot = CatalogueRepository.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres', style: TextStyle(color: Colors.white)),
        backgroundColor: couleurPrincipale,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: AnimatedBuilder(
        animation: depot,
        builder: (context, _) => ListView(
          children: [
            const TitreSection('Catalogue', icone: Icons.dataset_outlined),
            ListTile(
              leading: const Icon(Icons.insights_outlined, color: couleurPrincipale),
              title: const Text('Couverture du recensement'),
              subtitle: Text(
                '${depot.qualite['fiches_total']} fiches · ${depot.regions.length} région(s) couverte(s)',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const DiagnosticScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_off_outlined, color: couleurPrincipale),
              title: const Text('État de la base communautaire'),
              subtitle: Text(
                depot.baseConnectee
                    ? 'Connectée : avis et signalements transmis pour modération'
                    : 'Non connectée dans cette version : contributions conservées localement',
              ),
            ),
            ListTile(
              leading: const Icon(Icons.event_outlined, color: couleurPrincipale),
              title: const Text('Date de génération du catalogue'),
              subtitle: Text(depot.genereLe.isEmpty ? 'inconnue' : depot.genereLe),
            ),
            const TitreSection('Participer', icone: Icons.groups_outlined),
            ListTile(
              leading: const Icon(Icons.add_business_outlined, color: couleurPrincipale),
              title: const Text('Proposer un établissement absent'),
              subtitle: const Text('Signalez un restaurant, un fast-food ou une gargote non recensé'),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const ContributionsScreen(
                    mode: ModeContribution.proposerEtablissement,
                  ),
                ),
              ),
            ),
            const TitreSection('Bon à savoir', icone: Icons.gavel_outlined),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                '• DEKK FOOD publie des informations collectées depuis des sources publiques et les affiche '
                'avec un niveau de vérification explicite.\n'
                '• Aucun menu, prix, délai de livraison ou frais n\u2019est inventé : l\u2019absence d\u2019information '
                'est affichée comme telle.\n'
                '• Les photos génériques sont signalées : elles ne représentent pas l\u2019établissement.\n'
                '• Un propriétaire n\u2019est mentionné que si une source publique fiable le documente.\n'
                '• Toute personne peut demander la correction ou le retrait d\u2019une information la concernant.',
                style: TextStyle(height: 1.5, fontSize: 13),
              ),
            ),
            const SizedBox(height: 24),
            Center(
              child: Text(
                'DEKK FOOD 3.0.0 — catalogue national',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ),
            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
