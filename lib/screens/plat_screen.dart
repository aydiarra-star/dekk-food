/// Détail d'un plat et ajout au panier.
///
/// Le bloc « Garantie Hygiène & Propreté » de la version 2.1.0 a été RETIRÉ :
/// il affirmait des contrôles (normes HACCP, désinfection) qui n'avaient jamais
/// été réalisés. Il est remplacé par des informations factuelles sur la source
/// du plat et ses allergènes déclarés.
library;

import 'package:flutter/material.dart';

import '../models/catalogue.dart';
import '../state/panier.dart';
import '../widgets/communs.dart';

class PlatScreen extends StatefulWidget {
  final Etablissement etablissement;
  final Plat plat;

  const PlatScreen({super.key, required this.etablissement, required this.plat});

  @override
  State<PlatScreen> createState() => _PlatScreenState();
}

class _PlatScreenState extends State<PlatScreen> {
  int _quantite = 1;

  void _ajouterAuPanier() {
    final nomEtablissement = widget.etablissement.nom;
    final telephone = widget.etablissement.telephone;

    if (cartManager.restaurantName != null && cartManager.restaurantName != nomEtablissement) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Changer d\u2019établissement ?'),
          content: Text(
            'Votre panier contient des articles de ${cartManager.restaurantName}. '
            'Voulez-vous le vider pour commander chez $nomEtablissement ?',
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: couleurPrincipale, foregroundColor: Colors.white),
              onPressed: () {
                cartManager.clear();
                _ajouter(nomEtablissement, telephone);
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              child: const Text('Vider et continuer'),
            ),
          ],
        ),
      );
      return;
    }

    _ajouter(nomEtablissement, telephone);
    Navigator.pop(context);
  }

  void _ajouter(String nomEtablissement, String? telephone) {
    cartManager.addItem(
      nomEtablissement,
      telephone,
      {
        'name': widget.plat.nom,
        'price': widget.plat.prix == null
            ? 'Prix à confirmer'
            : formaterPrix(widget.plat.prix, widget.plat.devise),
        'price_num': widget.plat.prix,
        'prix_confirme': widget.plat.prixConfirme,
        'image': widget.plat.image?.url,
      },
      quantity: _quantite,
      idEtablissement: widget.etablissement.id,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$_quantite × ${widget.plat.nom} ajouté au panier')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final plat = widget.plat;

    return Scaffold(
      appBar: AppBar(
        title: Text(plat.nom, style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis),
        backgroundColor: couleurPrincipale,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ImageFiche(image: plat.image, hauteur: 230),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(plat.nom, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
                      ),
                      Text(
                        plat.prix == null ? 'Prix à confirmer' : formaterPrix(plat.prix, plat.devise),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: couleurPrincipale),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${plat.libelleCategorie} · ${widget.etablissement.nom} (${widget.etablissement.localisation})',
                    style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                  ),
                  if (plat.description != null) ...[
                    const SizedBox(height: 14),
                    const Text('Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                    const SizedBox(height: 4),
                    Text(plat.description!, style: const TextStyle(height: 1.4)),
                  ],
                  if (plat.taillePortion != null || plat.options != null || plat.variantes != null) ...[
                    const TitreSection('Portion, options et variantes'),
                    if (plat.taillePortion != null)
                      LigneInfo(icone: Icons.straighten, libelle: 'Portion', valeur: plat.taillePortion!),
                    if (plat.options != null)
                      LigneInfo(icone: Icons.tune, libelle: 'Options', valeur: plat.options!),
                    if (plat.variantes != null)
                      LigneInfo(icone: Icons.swap_horiz, libelle: 'Variantes', valeur: plat.variantes!),
                  ],
                  if (plat.allergenes.isNotEmpty || plat.regimes.isNotEmpty) ...[
                    const TitreSection('Allergènes et régimes déclarés'),
                    if (plat.allergenes.isNotEmpty)
                      LigneInfo(
                        icone: Icons.warning_amber_outlined,
                        libelle: 'Allergènes déclarés par l\u2019établissement',
                        valeur: plat.allergenes.join(', '),
                      ),
                    if (plat.regimes.isNotEmpty)
                      LigneInfo(
                        icone: Icons.eco_outlined,
                        libelle: 'Régimes déclarés',
                        valeur: plat.regimes.join(', '),
                      ),
                  ],
                  const TitreSection('Traçabilité de l\u2019information', icone: Icons.source_outlined),
                  BandeauInformation(
                    couleur: plat.prixConfirme ? Colors.green : Colors.orange,
                    icone: plat.prixConfirme ? Icons.verified : Icons.help_outline,
                    message: plat.prixConfirme
                        ? 'Prix confirmé par une source enregistrée.'
                        : 'Prix et disponibilité NON confirmés : DEKK FOOD n\u2019affiche aucune garantie '
                            'd\u2019hygiène ni de prix qu\u2019elle n\u2019a pas vérifiés. Demandez confirmation à '
                            'l\u2019établissement avant de commander.',
                  ),
                  const SizedBox(height: 6),
                  LigneInfo(
                    icone: Icons.event_available_outlined,
                    libelle: 'Disponibilité',
                    valeur: switch (plat.disponibilite) {
                      'permanent' => 'Toute l\u2019année',
                      'saisonnier' => 'Saisonnier',
                      'menu_du_jour' => 'Menu du jour',
                      'indisponible' => 'Indisponible',
                      _ => 'À confirmer',
                    },
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('Quantité : ', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 26, color: couleurPrincipale),
                        onPressed: () {
                          if (_quantite > 1) setState(() => _quantite--);
                        },
                      ),
                      Text('$_quantite', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 26, color: couleurPrincipale),
                        onPressed: () => setState(() => _quantite++),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(12),
        color: Colors.white,
        child: ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: couleurPrincipale,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.all(14),
          ),
          onPressed: _ajouterAuPanier,
          child: Text(
            plat.prix == null
                ? 'Ajouter au panier (prix à confirmer)'
                : 'Ajouter au panier · ${formaterPrix(plat.prix! * _quantite, plat.devise)}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
