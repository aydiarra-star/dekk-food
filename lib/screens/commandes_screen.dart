/// Historique des commandes préparées / envoyées.
///
/// Le statut « message préparé » indique que le message a été ouvert dans
/// WhatsApp : l'application ne peut pas savoir si l'établissement a confirmé la
/// commande, aucun statut n'est donc inventé.
library;

import 'package:flutter/material.dart';

import '../state/panier.dart';
import '../widgets/communs.dart';

class CommandesScreen extends StatelessWidget {
  const CommandesScreen({super.key});

  static const _libellesStatut = {
    'message_prepare': 'Message préparé (à envoyer/confirmer)',
    'confirme_restaurant': 'Confirmée par l\u2019établissement',
    'en_preparation': 'En préparation',
    'prete': 'Prête',
    'en_livraison': 'En livraison',
    'servie': 'Servie',
    'annulee': 'Annulée',
  };

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: orderHistoryManager,
      builder: (context, _) {
        final commandes = orderHistoryManager.orders;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Mes commandes', style: TextStyle(color: Colors.white)),
            backgroundColor: couleurPrincipale,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: commandes.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.receipt_long_outlined, size: 64, color: Colors.grey.shade400),
                        const SizedBox(height: 12),
                        const Text('Aucune commande enregistrée', style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 6),
                        const Text(
                          'Les commandes préparées depuis cette application apparaîtront ici, '
                          'avec leur statut réel.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  itemCount: commandes.length,
                  itemBuilder: (context, index) {
                    final commande = commandes[index];
                    final articles = (commande['articles'] as List? ?? const []);
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: ExpansionTile(
                        title: Text(commande['etablissement']?.toString() ?? 'Établissement'),
                        subtitle: Text(
                          '${articles.length} article(s) · ${commande['total_estime']} FCFA estimés\n'
                          '${_libellesStatut[commande['statut']] ?? commande['statut']}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        children: [
                          for (final article in articles)
                            ListTile(
                              dense: true,
                              title: Text('${article['quantity']} × ${article['name']}'),
                              subtitle: Text(
                                article['prix_confirme'] == true
                                    ? '${article['price']}'
                                    : '${article['price']} — non confirmé',
                              ),
                            ),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: BandeauInformation(
                              couleur: Colors.blueGrey,
                              icone: Icons.info_outline,
                              message: 'Date : ${commande['cree_le']}. '
                                  'Aucun frais de livraison ni délai n\u2019est affiché : ces informations '
                                  'sont communiquées par l\u2019établissement.',
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        );
      },
    );
  }
}
