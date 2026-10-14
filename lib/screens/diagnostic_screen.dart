/// Diagnostic de couverture et qualité du catalogue.
///
/// Écran LECTURE SEULE, ouvert à tous, calculé sur le catalogue embarqué.
/// Le tableau de bord administrateur complet (droits, file de travail partagée,
/// modification des fiches) nécessite la base connectée et le rôle
/// « administrateur » : il est décrit dans docs/RAPPORT.md.
library;

import 'package:flutter/material.dart';

import '../data/catalogue_repository.dart';
import '../widgets/communs.dart';
import 'fiche_screen.dart';

class DiagnosticScreen extends StatelessWidget {
  const DiagnosticScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final depot = CatalogueRepository.instance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Couverture du recensement', style: TextStyle(color: Colors.white)),
        backgroundColor: couleurPrincipale,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: AnimatedBuilder(
        animation: depot,
        builder: (context, _) {
          final qualite = depot.qualite;
          // Périmètre diffusé : les fiches non publiées sont conservées mais leurs
          // données pratiques ne sont pas distribuées (voir la règle de publication).
          final distribuee = depot.qualiteDistribuee;
          final regions = depot.couvertureParRegion;
          final total = distribuee['fiches_total'] ?? 1;


          return ListView(
            padding: const EdgeInsets.all(14),
            children: [
              const BandeauInformation(
                couleur: Colors.blueGrey,
                message: 'Le recensement est PROGRESSIF et non exhaustif. Aucune source publique ne permet '
                    'd\u2019affirmer que tous les établissements du Sénégal sont recensés. '
                    'Les chiffres ci-dessous mesurent la couverture réelle, sans arrondi complaisant.',
              ),
              const TitreSection('Volume recensé', icone: Icons.inventory_2_outlined),
              _ligne('Fiches au total', '${qualite['fiches_total']}'),
              _ligne('Fiches publiées', '${qualite['fiches_publiees']}'),
              _ligne('Fiches non publiées (conservées, non diffusées)',
                  '${qualite['fiches_non_publiees']}'),
              _ligne('Régions couvertes', '${regions.length} / 14'),
              _ligne('Fiches vérifiées', '${qualite['niveau_verifie'] ?? 0}'),
              _ligne('Partiellement vérifiées', '${qualite['niveau_partiellement_verifie'] ?? 0}'),
              _ligne('À confirmer', '${qualite['niveau_a_confirmer'] ?? 0}'),
              _ligne('Fermeture à vérifier', '${qualite['niveau_fermeture_a_verifier'] ?? 0}'),
              const TitreSection('Complétude des informations diffusées', icone: Icons.fact_check_outlined),
              const BandeauInformation(
                couleur: Colors.blueGrey,
                icone: Icons.filter_alt_outlined,
                message: 'Ces taux portent uniquement sur les fiches publiées. L\u2019application ne distribue '
                    'aucune donnée pratique (adresse, contact, position, horaires, menu, image) des fiches '
                    'non publiées, qui restent conservées pour la traçabilité du recensement.',
              ),
              _ligneAvecPart('Adresse renseignée', distribuee['fiches_adresse'] ?? 0, total),
              _ligneAvecPart('Coordonnées GPS (indicatives ou confirmées)', distribuee['fiches_gps'] ?? 0, total),
              _ligneAvecPart('Position confirmée sur place', distribuee['fiches_gps_verifie'] ?? 0, total),
              _ligneAvecPart('Téléphone', distribuee['fiches_telephone'] ?? 0, total),
              _ligneAvecPart('WhatsApp', distribuee['fiches_whatsapp'] ?? 0, total),
              _ligneAvecPart('Horaires', distribuee['fiches_horaires'] ?? 0, total),
              _ligneAvecPart('Menus avec au moins un prix', distribuee['fiches_menus'] ?? 0, total),
              _ligneAvecPart('Photos authentiques', distribuee['fiches_photos_authentiques'] ?? 0, total),
              _ligneAvecPart('Illustrations génériques uniquement', distribuee['fiches_illustrations_seules'] ?? 0, total),
              _ligneAvecPart('Propriétaire confirmé par une source', distribuee['fiches_proprietaire_confirme'] ?? 0, total),
              const TitreSection('Répartition par région', icone: Icons.map_outlined),
              for (final entree in regions.entries) _ligne(entree.key, '${entree.value} fiche(s)'),
              if (regions.length < 14)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: BandeauInformation(
                    couleur: Colors.orange,
                    icone: Icons.pending_outlined,
                    message: '${14 - regions.length} région(s) ne comptent encore aucune fiche publiée. '
                        'La collecte se poursuit région par région (voir docs/RAPPORT_COUVERTURE.md).',
                  ),
                ),
              const TitreSection('File de travail (fiches les plus incomplètes)', icone: Icons.pending_actions),
              ...depot.fileDeTravail.take(15).map((entree) => ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 14,
                      backgroundColor: couleurPrincipale,
                      child: Text(
                        '${entree.value}',
                        style: const TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                    title: Text(entree.key.nom, style: const TextStyle(fontSize: 13.5)),
                    subtitle: Text(
                      '${entree.key.region ?? 'région manquante'} · ${entree.key.niveauLibelle}'
                      '${entree.key.estPublicationVisible ? '' : ' · non publiée : conservée, non diffusée'}',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    trailing: const Icon(Icons.chevron_right, size: 18),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => FicheScreen(etablissement: entree.key)),
                    ),
                  )),
              const TitreSection('Contributions enregistrées localement', icone: Icons.inbox_outlined),
              _ligne('Avis en attente', '${depot.avisLocaux.length}'),
              _ligne('Signalements / demandes', '${depot.demandesLocales.length}'),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: BandeauInformation(
                  couleur: depot.baseConnectee ? Colors.green : Colors.orange,
                  message: depot.baseConnectee
                      ? 'La base communautaire est connectée : les contributions sont transmises pour modération.'
                      : 'La base communautaire n\u2019est pas connectée dans cette version : les contributions '
                          'restent sur cet appareil et ne sont ni publiées ni transmises.',
                ),
              ),
              const SizedBox(height: 30),
            ],
          );
        },
      ),
    );
  }

  Widget _ligne(String libelle, String valeur) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Expanded(child: Text(libelle)),
            Text(valeur, style: const TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
      );

  Widget _ligneAvecPart(String libelle, int valeur, int total) {
    final part = total == 0 ? 0.0 : valeur / total;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(libelle)),
              Text('$valeur / $total (${(part * 100).round()} %)',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: part.toDouble(),
              minHeight: 6,
              backgroundColor: Colors.grey.shade300,
              valueColor: const AlwaysStoppedAnimation(couleurPrincipale),
            ),
          ),
        ],
      ),
    );
  }
}
