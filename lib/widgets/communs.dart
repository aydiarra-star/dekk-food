/// Widgets partagés : badges de vérification, images honnêtes, boutons de contact.
library;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/catalogue.dart';

const Color couleurPrincipale = Colors.deepOrange;

/// Badge du niveau de vérification d'une fiche.
///
/// Il est affiché PARTOUT où la fiche apparaît : l'utilisateur ne doit jamais
/// confondre « information trouvée en ligne » et « information confirmée ».
class BadgeVerification extends StatelessWidget {
  final String niveau;
  final bool compact;

  const BadgeVerification({super.key, required this.niveau, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final (libelle, couleur, icone) = switch (niveau) {
      'verifie' => ('Vérifié', Colors.green.shade700, Icons.verified),
      'partiellement_verifie' => ('Partiellement vérifié', Colors.orange.shade800, Icons.help_center),
      'a_confirmer' => ('À confirmer', Colors.blueGrey.shade600, Icons.help_outline),
      'information_indisponible' => ('Information indisponible', Colors.grey.shade600, Icons.block),
      'fermeture_a_verifier' => ('Fermeture à vérifier', Colors.red.shade700, Icons.report_problem),
      _ => ('Statut inconnu', Colors.grey, Icons.help_outline),
    };

    return Container(
      padding: EdgeInsets.symmetric(horizontal: compact ? 6 : 8, vertical: compact ? 2 : 4),
      decoration: BoxDecoration(
        color: couleur.withAlpha((0.12 * 255).round()),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: couleur.withAlpha((0.4 * 255).round())),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: compact ? 12 : 14, color: couleur),
          const SizedBox(width: 4),
          Text(
            libelle,
            style: TextStyle(color: couleur, fontSize: compact ? 10 : 11.5, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

/// Image d'établissement ou de plat.
///
/// Règles appliquées (cahier des charges §6) :
/// - une photo authentique est affichée telle quelle avec sa mention de droits ;
/// - une illustration de banque d'images est TOUJOURS signalée comme telle ;
/// - en l'absence d'image, un visuel de remplacement élégant est affiché, sans
///   jamais laisser croire qu'il représente l'établissement.
class ImageFiche extends StatelessWidget {
  final ImageEtablissement? image;
  final double hauteur;
  final double largeur;
  final BorderRadius? rayon;

  const ImageFiche({
    super.key,
    required this.image,
    this.hauteur = 180,
    this.largeur = double.infinity,
    this.rayon,
  });

  @override
  Widget build(BuildContext context) {
    final rayonEffectif = rayon ?? BorderRadius.circular(14);
    if (image == null || image!.url.isEmpty) {
      return ClipRRect(
        borderRadius: rayonEffectif,
        child: Container(
          height: hauteur,
          width: largeur,
          color: const Color(0xFFE5E7EB),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.restaurant_menu, size: hauteur / 4, color: Colors.grey.shade500),
              const SizedBox(height: 6),
              Text(
                'Aucune photo vérifiée disponible',
                style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              ),
            ],
          ),
        ),
      );
    }

    return ClipRRect(
      borderRadius: rayonEffectif,
      child: Stack(
        children: [
          Image.network(
            image!.url,
            height: hauteur,
            width: largeur,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stack) => Container(
              height: hauteur,
              width: largeur,
              color: const Color(0xFFE5E7EB),
              child: Icon(Icons.broken_image_outlined, color: Colors.grey.shade500),
            ),
            loadingBuilder: (context, child, progression) {
              if (progression == null) return child;
              return Container(
                height: hauteur,
                width: largeur,
                color: const Color(0xFFE5E7EB),
                child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              );
            },
          ),
          if (image!.mentionDroits != null)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                color: Colors.black.withAlpha((0.55 * 255).round()),
                child: Text(
                  image!.mentionDroits!,
                  style: const TextStyle(color: Colors.white, fontSize: 10),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Bandeau d'information honnête : indique ce qui n'est pas confirmé.
class BandeauInformation extends StatelessWidget {
  final String message;
  final IconData icone;
  final Color couleur;

  const BandeauInformation({
    super.key,
    required this.message,
    this.icone = Icons.info_outline,
    this.couleur = Colors.blueGrey,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: couleur.withAlpha((0.08 * 255).round()),
        border: Border.all(color: couleur.withAlpha((0.3 * 255).round())),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 18, color: couleur),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(fontSize: 12.5, color: Colors.grey.shade800, height: 1.35)),
          ),
        ],
      ),
    );
  }
}

/// Boutons d'action : appel, WhatsApp, itinéraire, site web, réservation.
class BoutonsContact extends StatelessWidget {
  final Etablissement etablissement;
  final bool empiles;

  const BoutonsContact({super.key, required this.etablissement, this.empiles = false});

  Future<void> _ouvrir(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    if (!await canLaunchUrl(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Lien indisponible sur cet appareil.')),
        );
      }
      return;
    }
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final boutons = <Widget>[];

    if (etablissement.telephone != null) {
      boutons.add(ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
        onPressed: () => _ouvrir(context, 'tel:${etablissement.telephone}'),
        icon: const Icon(Icons.phone, size: 18),
        label: const Text('Appeler'),
      ));
    }

    if (etablissement.whatsapp != null) {
      boutons.add(ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
        onPressed: () => _ouvrir(
          context,
          'https://wa.me/${etablissement.whatsapp!.replaceAll(RegExp(r'[^0-9]'), '')}',
        ),
        icon: const Icon(Icons.chat, size: 18),
        label: const Text('WhatsApp'),
      ));
    }

    if (etablissement.aDesCoordonnees) {
      final requete = Uri.encodeComponent('${etablissement.latitude},${etablissement.longitude}');
      boutons.add(ElevatedButton.icon(
        style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white),
        onPressed: () => _ouvrir(context, 'https://www.google.com/maps/search/?api=1&query=$requete'),
        icon: const Icon(Icons.directions, size: 18),
        label: const Text('Itinéraire'),
      ));
    } else if (etablissement.adresse != null || etablissement.nom.isNotEmpty) {
      // Sans GPS vérifié, on propose une recherche textuelle sur la carte.
      final requete = Uri.encodeComponent(
        [etablissement.nom, etablissement.adresse ?? etablissement.localisation].join(', '),
      );
      boutons.add(OutlinedButton.icon(
        onPressed: () => _ouvrir(context, 'https://www.google.com/maps/search/?api=1&query=$requete'),
        icon: const Icon(Icons.directions, size: 18),
        label: const Text('Localiser'),
      ));
    }

    if (etablissement.siteWeb != null) {
      boutons.add(OutlinedButton.icon(
        onPressed: () => _ouvrir(context, etablissement.siteWeb!),
        icon: const Icon(Icons.language, size: 18),
        label: const Text('Site web'),
      ));
    }

    if (etablissement.reservationUrl != null) {
      boutons.add(OutlinedButton.icon(
        onPressed: () => _ouvrir(context, etablissement.reservationUrl!),
        icon: const Icon(Icons.event_available, size: 18),
        label: const Text('Réserver'),
      ));
    }

    if (etablissement.commandeEnLigneUrl != null) {
      boutons.add(OutlinedButton.icon(
        onPressed: () => _ouvrir(context, etablissement.commandeEnLigneUrl!),
        icon: const Icon(Icons.shopping_bag_outlined, size: 18),
        label: const Text('Commander sur son site'),
      ));
    }

    if (boutons.isEmpty) {
      return const BandeauInformation(
        message: 'Aucun contact professionnel n\u2019est encore renseigné pour cet établissement. '
            'Vous le connaissez ? Utilisez « Proposer une mise à jour » sur la fiche.',
        icone: Icons.contact_phone_outlined,
      );
    }

    if (empiles) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final bouton in boutons)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: SizedBox(width: double.infinity, child: bouton),
            ),
        ],
      );
    }

    return Wrap(spacing: 8, runSpacing: 8, children: boutons);
  }
}

/// Ligne d'information avec libellé (utilisée dans les sections de la fiche).
class LigneInfo extends StatelessWidget {
  final IconData icone;
  final String libelle;
  final String valeur;
  final String? precision;

  const LigneInfo({
    super.key,
    required this.icone,
    required this.libelle,
    required this.valeur,
    this.precision,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icone, size: 18, color: couleurPrincipale),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(libelle, style: TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
                Text(valeur, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
                if (precision != null)
                  Text(precision!, style: TextStyle(fontSize: 11, color: Colors.grey.shade600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Titre de section.
class TitreSection extends StatelessWidget {
  final String titre;
  final IconData? icone;

  const TitreSection(this.titre, {super.key, this.icone});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Row(
        children: [
          if (icone != null) ...[
            Icon(icone, size: 18, color: couleurPrincipale),
            const SizedBox(width: 8),
          ],
          Text(titre, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }
}

/// Formatage des montants en francs CFA.
String formaterPrix(double? montant, String devise) {
  if (montant == null) return 'Prix à confirmer';
  final entier = montant.round();
  final chiffres = entier.toString();
  final buffer = StringBuffer();
  for (var index = 0; index < chiffres.length; index++) {
    if (index > 0 && (chiffres.length - index) % 3 == 0) buffer.write(' ');
    buffer.write(chiffres[index]);
  }
  return '${buffer.toString()} $devise';
}
