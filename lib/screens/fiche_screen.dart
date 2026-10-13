/// Fiche détaillée d'un établissement.
///
/// La fiche affiche TOUJOURS : le niveau de vérification, la date de collecte,
/// la provenance des informations et la mention « Propriétaire non renseigné »
/// lorsqu'aucune source publique fiable n'est disponible.
library;

import 'package:flutter/material.dart';

import '../data/catalogue_repository.dart';
import '../models/catalogue.dart';
import '../widgets/communs.dart';
import 'contributions_screen.dart';
import 'plat_screen.dart';

class FicheScreen extends StatelessWidget {
  final Etablissement etablissement;

  const FicheScreen({super.key, required this.etablissement});

  @override
  Widget build(BuildContext context) {
    final depot = CatalogueRepository.instance;

    return AnimatedBuilder(
      animation: depot,
      builder: (context, _) {
        final favori = depot.estFavori(etablissement.id);
        final plats = etablissement.tousLesPlats;

        return Scaffold(
          appBar: AppBar(
            title: Text(
              etablissement.nom,
              style: const TextStyle(color: Colors.white),
              overflow: TextOverflow.ellipsis,
            ),
            backgroundColor: couleurPrincipale,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              IconButton(
                tooltip: favori ? 'Retirer des favoris' : 'Ajouter aux favoris',
                icon: Icon(favori ? Icons.favorite : Icons.favorite_border, color: Colors.white),
                onPressed: () => depot.basculerFavori(etablissement.id),
              ),
            ],
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
                      ImageFiche(
                        image: etablissement.images.isEmpty ? null : etablissement.images.first,
                        hauteur: 210,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        etablissement.nom,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${etablissement.typeLibelle} · ${etablissement.localisation}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          BadgeVerification(niveau: etablissement.niveauVerification),
                          Chip(
                            visualDensity: VisualDensity.compact,
                            label: Text(
                              etablissement.statutLibelle,
                              style: const TextStyle(fontSize: 11),
                            ),
                          ),
                          if (etablissement.categoriesLibelles.isNotEmpty)
                            Chip(
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                etablissement.categoriesLibelles.join(' · '),
                                style: const TextStyle(fontSize: 11),
                              ),
                            ),
                        ],
                      ),
                      if (!etablissement.estVerifie) ...[
                        const SizedBox(height: 10),
                        BandeauInformation(
                          couleur: Colors.orange,
                          icone: Icons.fact_check_outlined,
                          message: _messageVerification(etablissement),
                        ),
                      ],
                      const SizedBox(height: 12),
                      if (etablissement.descriptionCourte != null)
                        Text(etablissement.descriptionCourte!, style: const TextStyle(height: 1.4)),
                      const SizedBox(height: 14),
                      BoutonsContact(etablissement: etablissement),

                      const TitreSection('Informations pratiques', icone: Icons.place_outlined),
                      LigneInfo(
                        icone: Icons.location_on_outlined,
                        libelle: 'Adresse',
                        valeur: etablissement.adresse ?? 'Adresse non renseignée',
                        precision: [
                          etablissement.quartier,
                          etablissement.commune,
                          etablissement.departement,
                          etablissement.region,
                        ].whereType<String>().join(' · '),
                      ),
                      if (etablissement.pointsDeRepere != null)
                        LigneInfo(
                          icone: Icons.signpost_outlined,
                          libelle: 'Points de repère',
                          valeur: etablissement.pointsDeRepere!,
                        ),
                      LigneInfo(
                        icone: Icons.my_location,
                        libelle: 'Coordonnées GPS',
                        valeur: etablissement.aDesCoordonnees
                            ? '${etablissement.latitude}, ${etablissement.longitude}'
                            : 'Non vérifiées',
                        precision: etablissement.gpsVerifie
                            ? 'Position confirmée'
                            : 'Position non confirmée : utilisez « Localiser » pour une recherche textuelle',
                      ),
                      if (etablissement.zonesLivraison.isNotEmpty)
                        LigneInfo(
                          icone: Icons.delivery_dining_outlined,
                          libelle: 'Zones de livraison',
                          valeur: etablissement.zonesLivraison
                              .map((zone) => (zone['libelle_zone'] ?? zone['commune'] ?? '').toString())
                              .where((element) => element.isNotEmpty)
                              .join(', '),
                          precision: 'Frais et délais affichés uniquement s\u2019ils sont confirmés',
                        ),

                      if (etablissement.horaires.isNotEmpty) ...[
                        const TitreSection('Horaires', icone: Icons.schedule_outlined),
                        ...etablissement.horaires.map((horaire) => LigneInfo(
                              icone: Icons.access_time,
                              libelle: _jour(horaire.jour),
                              valeur: horaire.ferme
                                  ? 'Fermé'
                                  : '${horaire.ouverture ?? '?'} – ${horaire.fermeture ?? '?'}',
                              precision: horaire.confirme ? 'Confirmé' : 'À confirmer',
                            )),
                      ] else
                        const TitreSection('Horaires', icone: Icons.schedule_outlined),
                      if (etablissement.horaires.isEmpty)
                        const BandeauInformation(
                          message: 'Horaires non communiqués : aucun affichage « ouvert maintenant » '
                              'n\u2019est proposé pour cet établissement afin de ne pas induire en erreur. '
                              'Contactez l\u2019établissement pour connaître ses horaires.',
                          icone: Icons.schedule_outlined,
                        ),

                      const TitreSection('Menus & plats', icone: Icons.restaurant_menu),
                      if (plats.isEmpty)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const BandeauInformation(
                              message: 'Menu à confirmer auprès du restaurant. '
                                  'DEKK FOOD ne publie aucun plat ni prix qui ne soit fourni par l\u2019établissement.',
                              icone: Icons.menu_book_outlined,
                            ),
                            const SizedBox(height: 8),
                            BoutonsContact(etablissement: etablissement, empiles: true),
                          ],
                        )
                      else ...[
                        for (final menu in etablissement.menus)
                          if (menu.plats.isNotEmpty) ...[
                            Padding(
                              padding: const EdgeInsets.only(top: 6, bottom: 2),
                              child: Row(
                                children: [
                                  Text(
                                    '${menu.libelleType} · ${menu.nom}',
                                    style: const TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(width: 8),
                                  Chip(
                                    visualDensity: VisualDensity.compact,
                                    label: Text(
                                      menu.confirme ? 'Confirmé' : 'À confirmer',
                                      style: const TextStyle(fontSize: 10),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            for (final plat in menu.plats)
                              CartePlat(plat: plat, etablissement: etablissement),
                            if (!menu.confirme && menu.sourceUrl == null)
                              const Padding(
                                padding: EdgeInsets.only(top: 4),
                                child: Text(
                                  'Source du menu non publiée : tarifs à vérifier auprès de l\u2019établissement.',
                                  style: TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                              ),
                          ],
                      ],

                      if (etablissement.images.length > 1) ...[
                        const TitreSection('Galerie', icone: Icons.photo_library_outlined),
                        SizedBox(
                          height: 120,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: etablissement.images.length,
                            separatorBuilder: (context, index) => const SizedBox(width: 8),
                            itemBuilder: (context, index) => SizedBox(
                              width: 160,
                              child: ImageFiche(
                                image: etablissement.images[index],
                                hauteur: 120,
                                largeur: 160,
                              ),
                            ),
                          ),
                        ),
                      ],

                      const TitreSection('Concept & services', icone: Icons.lightbulb_outline),
                      if (etablissement.descriptionLongue != null)
                        Text(etablissement.descriptionLongue!, style: const TextStyle(height: 1.4)),
                      if (etablissement.ambiance != null)
                        LigneInfo(
                          icone: Icons.chair_outlined,
                          libelle: 'Ambiance',
                          valeur: etablissement.ambiance!,
                        ),
                      LigneInfo(
                        icone: Icons.payments_outlined,
                        libelle: 'Fourchette de prix',
                        valeur: etablissement.fourchettePrixAffichee ?? 'Non renseignée',
                        precision:
                            etablissement.fourchettePrixAffichee != null ? 'À confirmer auprès de l\u2019établissement' : null,
                      ),
                      LigneInfo(
                        icone: Icons.credit_card_outlined,
                        libelle: 'Moyens de paiement',
                        valeur: etablissement.modesPaiement.isEmpty
                            ? 'Non communiqués'
                            : etablissement.modesPaiement.join(', '),
                      ),
                      LigneInfo(
                        icone: Icons.accessible_outlined,
                        libelle: 'Accessibilité',
                        valeur: etablissement.accessibilite ?? 'Non documentée',
                      ),
                      LigneInfo(
                        icone: Icons.room_service_outlined,
                        libelle: 'Services déclarés',
                        valeur: etablissement.contacts.isEmpty
                            ? 'Aucun service confirmé à ce jour'
                            : 'Moyens de contact : ${etablissement.contacts.map((c) => c.type).toSet().join(', ')}',
                        precision: 'Un service n\u2019est affiché comme disponible qu\u2019après confirmation',
                      ),

                      const TitreSection('Propriété & gestion', icone: Icons.business_outlined),
                      LigneInfo(
                        icone: Icons.person_outline,
                        libelle: 'Propriétaire / exploitant',
                        valeur: etablissement.proprietaireLibelle,
                        precision: etablissement.exploitation
                                .any((element) => element.statutConfirmation != 'inconnu')
                            ? 'Information issue d\u2019une source publique'
                            : 'Aucune source publique fiable : la fiche peut être complétée par l\u2019établissement',
                      ),

                      const TitreSection('Sources & vérification', icone: Icons.verified_outlined),
                      LigneInfo(
                        icone: Icons.event_outlined,
                        libelle: 'Dernière vérification',
                        valeur: etablissement.derniereVerificationLe ??
                            'Aucune vérification humaine effectuée à ce jour',
                      ),
                      if (etablissement.commentaireVerification != null)
                        BandeauInformation(
                          couleur: Colors.blueGrey,
                          icone: Icons.flag_outlined,
                          message: etablissement.commentaireVerification!,
                        ),
                      for (final source in etablissement.sources)
                        LigneInfo(
                          icone: Icons.source_outlined,
                          libelle: 'Source : ${source.code}',
                          valeur: source.url ?? 'Source interne (sans URL publique)',
                          precision: [
                            if (source.dateCollecte != null) 'collecté le ${source.dateCollecte}',
                            if (source.donnees != null) source.donnees!,
                            if (source.niveauConfiance != null) 'confiance ${source.niveauConfiance}',
                          ].join(' · '),
                        ),

                      const TitreSection('Contribuer', icone: Icons.edit_outlined),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ContributionsScreen(
                                  etablissement: etablissement,
                                  mode: ModeContribution.deposerAvis,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.star_outline, size: 18),
                            label: const Text('Donner mon avis'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ContributionsScreen(
                                  etablissement: etablissement,
                                  mode: ModeContribution.signalerErreur,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.report_gmailerrorred_outlined, size: 18),
                            label: const Text('Signaler une erreur'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ContributionsScreen(
                                  etablissement: etablissement,
                                  mode: ModeContribution.demanderMiseAJour,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.update_outlined, size: 18),
                            label: const Text('Demander une mise à jour'),
                          ),
                          OutlinedButton.icon(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => ContributionsScreen(
                                  etablissement: etablissement,
                                  mode: ModeContribution.revendiquer,
                                ),
                              ),
                            ),
                            icon: const Icon(Icons.verified_user_outlined, size: 18),
                            label: const Text('Revendiquer cette fiche'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static String _messageVerification(Etablissement etablissement) {
    final date = etablissement.dateCollecte ?? 'date inconnue';
    return 'Cette fiche n\u2019est pas certifiée : les informations ont été collectées le $date '
        'et n\u2019ont pas encore été confirmées par l\u2019établissement. '
        'Contactez-le avant de vous déplacer.';
  }

  static String _jour(int jour) => const {
        0: 'Dimanche',
        1: 'Lundi',
        2: 'Mardi',
        3: 'Mercredi',
        4: 'Jeudi',
        5: 'Vendredi',
        6: 'Samedi',
      }[jour] ??
      'Jour $jour';
}

/// Carte d'un plat dans la fiche.
class CartePlat extends StatelessWidget {
  final Plat plat;
  final Etablissement etablissement;

  const CartePlat({super.key, required this.plat, required this.etablissement});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 5),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PlatScreen(etablissement: etablissement, plat: plat),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              SizedBox(
                width: 64,
                height: 64,
                child: ImageFiche(image: plat.image, hauteur: 64, largeur: 64, rayon: BorderRadius.circular(8)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(plat.nom, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5)),
                    Text(
                      plat.libelleCategorie,
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    if (plat.description != null)
                      Text(
                        plat.description!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    const SizedBox(height: 2),
                    Text(
                      plat.prix == null
                          ? 'Prix à confirmer auprès de l\u2019établissement'
                          : (plat.prixConfirme
                              ? formaterPrix(plat.prix, plat.devise)
                              : '${formaterPrix(plat.prix, plat.devise)} (à confirmer)'),
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 12.5,
                        color: plat.prixConfirme ? couleurPrincipale : Colors.grey.shade700,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios, size: 14, color: couleurPrincipale),
            ],
          ),
        ),
      ),
    );
  }
}
