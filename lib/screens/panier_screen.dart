/// Panier et commande.
///
/// La commande est un message WhatsApp préparé par l'application et envoyé par
/// le client à l'établissement : DEKK FOOD n'encaisse aucun paiement, ne fixe
/// aucun frais de livraison et n'annonce aucun délai. Toute commande intégrée
/// (panier transmis à la base) reste désactivée tant que l'établissement ne l'a
/// pas activée et confirmée.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../state/panier.dart';
import '../widgets/communs.dart';
import 'decouvrir_screen.dart';

class PanierScreen extends StatefulWidget {
  const PanierScreen({super.key});

  @override
  State<PanierScreen> createState() => _PanierScreenState();
}

class _PanierScreenState extends State<PanierScreen> {
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: cartManager,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Mon panier', style: TextStyle(color: Colors.white)),
            backgroundColor: couleurPrincipale,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: cartManager.items.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined, size: 70, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('Votre panier est vide', style: TextStyle(fontSize: 17)),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(builder: (context) => const DecouvrirScreen()),
                        ),
                        child: const Text('Explorer les établissements'),
                      ),
                    ],
                  ),
                )
              : Column(
                  children: [
                    Expanded(
                      child: ListView.builder(
                        itemCount: cartManager.items.length,
                        itemBuilder: (context, index) {
                          final item = cartManager.items[index];
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: ListTile(
                              title: Text(item['name'] as String),
                              subtitle: Text(
                                '${item['price']}${item['prix_confirme'] == true ? '' : ' · à confirmer'}',
                                style: TextStyle(
                                  color: item['prix_confirme'] == true ? Colors.grey.shade700 : Colors.orange.shade800,
                                ),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_circle_outline, color: couleurPrincipale),
                                    onPressed: () => cartManager.updateQuantity(index, -1),
                                  ),
                                  Text(
                                    '${item['quantity']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.add_circle_outline, color: couleurPrincipale),
                                    onPressed: () => cartManager.updateQuantity(index, 1),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (cartManager.restaurantName != null)
                            Text(
                              'Établissement : ${cartManager.restaurantName}',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          const SizedBox(height: 6),
                          if (cartManager.contientPrixAConfirmer)
                            const BandeauInformation(
                              couleur: Colors.orange,
                              icone: Icons.info_outline,
                              message: 'Certains articles n\u2019ont pas de prix confirmé : le total est une '
                                  'ESTIMATION. Le montant exact sera communiqué par l\u2019établissement.',
                            ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text('Total estimé', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                              Text(
                                '${cartManager.subtotal} FCFA',
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                  color: couleurPrincipale,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: couleurPrincipale,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.all(14),
                              ),
                              onPressed: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const CommandeScreen()),
                              ),
                              child: const Text('Passer la commande', style: TextStyle(fontWeight: FontWeight.bold)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        );
      },
    );
  }
}

/// Formulaire de commande : construit le message WhatsApp destiné à
/// l'établissement, puis enregistre la commande dans l'historique.
class CommandeScreen extends StatefulWidget {
  const CommandeScreen({super.key});

  @override
  State<CommandeScreen> createState() => _CommandeScreenState();
}

class _CommandeScreenState extends State<CommandeScreen> {
  final _formulaire = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _telephone = TextEditingController();
  final _adresse = TextEditingController();
  final _note = TextEditingController();

  @override
  void dispose() {
    _nom.dispose();
    _telephone.dispose();
    _adresse.dispose();
    _note.dispose();
    super.dispose();
  }

  String _construireMessage() {
    final lignes = <String>[
      'Bonjour ${cartManager.restaurantName ?? ''},',
      '',
      'Je souhaite passer une commande via DEKK FOOD :',
    ];
    for (final item in cartManager.items) {
      final prix = item['prix_confirme'] == true ? ' (${item['price']})' : ' (prix à confirmer)';
      lignes.add('• ${item['quantity']} × ${item['name']}$prix');
    }
    lignes
      ..add('')
      ..add('Total estimé : ${cartManager.subtotal} FCFA — à confirmer par vos soins.')
      ..add('')
      ..add('Nom : ${_nom.text.trim()}')
      ..add('Téléphone : ${_telephone.text.trim()}');
    if (_adresse.text.trim().isNotEmpty) lignes.add('Adresse de livraison : ${_adresse.text.trim()}');
    if (_note.text.trim().isNotEmpty) lignes.add('Précisions : ${_note.text.trim()}');
    lignes
      ..add('')
      ..add('Merci de me confirmer la disponibilité, le montant exact et le délai.')
      ..add('(Message préparé avec l\'application DEKK FOOD)');
    return lignes.join('\n');
  }

  Future<void> _envoyer() async {
    if (!(_formulaire.currentState?.validate() ?? false)) return;

    final message = _construireMessage();
    final telephone = cartManager.restaurantPhone;
    final uri = telephone != null
        ? Uri.parse('https://wa.me/${telephone.replaceAll(RegExp(r'[^0-9]'), '')}?text=${Uri.encodeComponent(message)}')
        : Uri.parse('https://wa.me/?text=${Uri.encodeComponent(message)}');

    orderHistoryManager.addOrder({
      'etablissement': cartManager.restaurantName,
      'etablissement_id': cartManager.etablissementId,
      'articles': List<Map<String, dynamic>>.from(cartManager.items),
      'total_estime': cartManager.subtotal,
      'prix_confirme': !cartManager.contientPrixAConfirmer,
      'nom_client': _nom.text.trim(),
      'telephone_client': _telephone.text.trim(),
      'adresse': _adresse.text.trim(),
      'note': _note.text.trim(),
      'cree_le': DateTime.now().toIso8601String(),
      'mode_commande': 'whatsapp',
      'statut': 'message_prepare',
    });

    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('WhatsApp n\u2019est pas disponible : la commande reste enregistrée dans « Commandes ».')),
      );
    }

    cartManager.clear();
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Message préparé'),
        content: const Text(
          'Votre commande a été préparée dans WhatsApp. Elle n\u2019est considérée comme transmise '
          'qu\u2019une fois le message envoyé par vos soins, et confirmée par l\u2019établissement.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text('Fermer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Finaliser la commande', style: TextStyle(color: Colors.white)),
        backgroundColor: couleurPrincipale,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formulaire,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const BandeauInformation(
                couleur: Colors.blueGrey,
                message: 'La commande est transmise par WhatsApp directement à l\u2019établissement. '
                    'DEKK FOOD ne perçoit aucun paiement, n\u2019ajoute aucuns frais de livraison et '
                    'ne garantit aucun délai : les frais et le délai éventuels sont annoncés par '
                    'l\u2019établissement lui-même.',
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _nom,
                decoration: const InputDecoration(labelText: 'Votre nom', border: OutlineInputBorder()),
                validator: (valeur) => (valeur == null || valeur.trim().isEmpty) ? 'Nom requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _telephone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Votre téléphone', border: OutlineInputBorder()),
                validator: (valeur) => (valeur == null || valeur.trim().length < 7) ? 'Numéro requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _adresse,
                decoration: const InputDecoration(
                  labelText: 'Adresse (si livraison souhaitée)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Précisions (allergies, horaire souhaité…)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.all(14),
                  ),
                  onPressed: _envoyer,
                  icon: const Icon(Icons.chat),
                  label: const Text('Envoyer au restaurant via WhatsApp', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
