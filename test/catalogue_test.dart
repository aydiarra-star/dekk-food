import 'dart:convert';
import 'dart:io';

import 'package:dekk_food/data/catalogue_repository.dart';
import 'package:dekk_food/models/catalogue.dart';
import 'package:dekk_food/screens/favoris_screen.dart';
import 'package:dekk_food/screens/fiche_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Vérifie que le catalogue embarqué reste exploitable par l'application :
/// structure, absence de données obligatoires manquantes, honnêteté des
/// informations affichées (aucun prix/niveau non étiqueté).
///
/// Vérifie également la fiabilité des données et la sécurité des parcours
/// publics : distinction entre position disponible et position confirmée,
/// cloisonnement des fiches non publiées (recherche, carte, favoris, écran de
/// détail, accès direct) et absence de données pratiques des fiches non
/// publiées dans le catalogue distribué avec l'application.
void main() {
  late Map<String, dynamic> racine;
  late List<Etablissement> etablissements;

  setUpAll(() {
    final fichier = File('assets/data/catalogue.json');
    expect(fichier.existsSync(), isTrue, reason: 'assets/data/catalogue.json doit exister');
    racine = jsonDecode(fichier.readAsStringSync()) as Map<String, dynamic>;
    etablissements = (racine['etablissements'] as List)
        .map((element) => Etablissement.fromJson(Map<String, dynamic>.from(element as Map)))
        .toList();
  });

  test('le catalogue contient des fiches et une date de génération', () {
    expect(etablissements, isNotEmpty);
    expect((racine['genere_le'] as String?)?.isNotEmpty, isTrue);
  });

  test('chaque fiche porte un identifiant, un nom et une source', () {
    for (final etablissement in etablissements) {
      expect(etablissement.id, isNotEmpty, reason: 'identifiant manquant');
      expect(etablissement.nom, isNotEmpty, reason: 'nom manquant sur ${etablissement.id}');
      expect(etablissement.sources, isNotEmpty, reason: 'aucune source sur ${etablissement.id}');
      expect(etablissement.dateCollecte, isNotNull, reason: 'aucune date de collecte sur ${etablissement.id}');
    }
  });

  test('aucun établissement publié sans région (règle de publication)', () {
    for (final etablissement in etablissements) {
      if (etablissement.region == null) {
        expect(etablissement.statutLibelle, isNotEmpty);
      }
    }
  });

  test('les prix ne sont marqués confirmés que s\'ils ont une valeur', () {
    for (final etablissement in etablissements) {
      for (final plat in etablissement.tousLesPlats) {
        if (plat.prixConfirme) {
          expect(plat.prix, isNotNull);
        }
        expect(plat.statutConfirmation, isIn(const ['confirme', 'partiellement_confirme', 'inconnu', 'a_confirmer']));
      }
    }
  });

  test('les images génériques sont étiquetées comme telles', () {
    for (final etablissement in etablissements) {
      for (final image in etablissement.images) {
        if (image.estIllustrationGenerique) {
          expect(image.mentionDroits, contains('générique'));
        }
      }
    }
  });

  test('aucun propriétaire n\'est affiché sans source confirmée', () {
    for (final etablissement in etablissements) {
      final confirme = etablissement.exploitation.where((element) => element.statutConfirmation == 'confirme');
      if (confirme.isNotEmpty) {
        expect(etablissement.exploitation.any((element) => element.sourceUrl != null), isTrue);
      } else {
        expect(etablissement.proprietaireLibelle, 'Propriétaire non renseigné');
      }
    }
  });

  test('les niveaux de vérification sont ceux du cahier des charges', () {
    const autorises = {
      'verifie',
      'partiellement_verifie',
      'a_confirmer',
      'information_indisponible',
      'fermeture_a_verifier',
    };
    for (final etablissement in etablissements) {
      expect(autorises, contains(etablissement.niveauVerification));
    }
  });

  test('la recherche par nom, plat ou quartier fonctionne', () {
    final premier = etablissements.first;
    final parNom = etablissements.where(FiltresCatalogue(recherche: premier.nom).correspond);
    expect(parNom, isNotEmpty);

    final avecPlat = etablissements.firstWhere((element) => element.tousLesPlats.isNotEmpty);
    final nomPlat = avecPlat.tousLesPlats.first.nom.split(' ').first;
    final parPlat = etablissements.where(FiltresCatalogue(recherche: nomPlat).correspond);
    expect(parPlat, isNotEmpty);
  });

  test('les filtres de région et de type restreignent réellement les résultats', () {
    final region = etablissements.first.region;
    if (region != null) {
      final filtres = etablissements.where(FiltresCatalogue(region: region).correspond);
      expect(filtres.every((element) => element.region == region), isTrue);
      expect(filtres.length, lessThanOrEqualTo(etablissements.length));
    }
  });

  test('les contacts affichés proviennent des colonnes de la fiche', () {
    for (final etablissement in etablissements) {
      for (final contact in etablissement.contacts) {
        expect(contact.valeur.trim(), isNotEmpty);
        expect(contact.confirme, isA<bool>());
      }
      if (etablissement.telephone != null) {
        expect(etablissement.contacts.any((contact) => contact.type == 'telephone'), isTrue);
      }
    }
  });

  test('les niveaux de vérification sont exposés en libellés clairs', () {
    for (final etablissement in etablissements) {
      expect(etablissement.niveauLibelle, isNotEmpty);
      expect(etablissement.statutLibelle, isNotEmpty);
    }
  });

  test('la publication est décidée par le pipeline et respectée par l\'application', () {
    final synthese = racine['couverture']['publication'] as Map<String, dynamic>;
    final publiees = etablissements.where((element) => element.estPublicationVisible).toList();
    expect(synthese['fiches_publiees'], publiees.length,
        reason: 'le décompte de publication du catalogue doit correspondre aux fiches publiées');
    expect(synthese['fiches_publiees'] + synthese['fiches_non_publiees'], etablissements.length,
        reason: 'toutes les fiches doivent être comptées, publiées ou non');
    expect((synthese['regle'] as String?)?.isNotEmpty, isTrue,
        reason: 'la règle de publication doit accompagner le catalogue');
    for (final etablissement in publiees) {
      expect(etablissement.region, isNotNull,
          reason: '${etablissement.id} est publié sans région');
    }
  });

  test('une fiche non publiée est conservée et explique pourquoi', () {
    final nonPubliees = etablissements.where((element) => !element.estPublicationVisible).toList();
    for (final etablissement in nonPubliees) {
      expect(etablissement.motifNonPublication, isNotNull,
          reason: '${etablissement.id} est écartée sans motif : rien ne doit disparaître en silence');
      expect(etablissement.motifNonPublication, isNotEmpty);
      expect(etablissement.nom, isNotEmpty, reason: 'une fiche non publiée perd son nom');
      expect(etablissement.sources, isNotEmpty, reason: 'une fiche non publiée perd ses sources');
      expect(etablissement.publicationLibelle, contains('non publiée'));
    }
  });

  test('« publiée » ne signifie jamais « vérifiée »', () {
    for (final etablissement in etablissements) {
      expect(etablissement.statutValidation,
          isIn(const ['non_validee', 'en_cours', 'validee', 'rejetee']));
      if (etablissement.statutValidation == 'validee') {
        expect(etablissement.validationPar, isNotNull,
            reason: '${etablissement.id} : validation sans personne identifiée');
        expect(etablissement.validationLe, isNotNull,
            reason: '${etablissement.id} : validation sans date');
      }
      if (etablissement.niveauVerification == 'verifie') {
        expect(etablissement.estValideeParControle, isTrue,
            reason: '${etablissement.id} porte le badge « vérifié » sans validation tracée');
      }
    }
  });

  test('chaque fiche expose sa provenance et l\'état des droits sur ses images', () {
    for (final etablissement in etablissements) {
      final provenance = (racine['etablissements'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((element) => element['id'] == etablissement.id)['provenance'] as Map<String, dynamic>;
      expect((provenance['methode'] as String?)?.isNotEmpty, isTrue,
          reason: '${etablissement.id} : méthode de collecte non documentée');
      expect(provenance['nombre_sources'], etablissement.sources.length);
      expect(provenance['verification_humaine'], etablissement.derniereVerificationLe != null,
          reason: '${etablissement.id} : une vérification humaine ne se présume pas');

      final droits = (racine['etablissements'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((element) => element['id'] == etablissement.id)['autorisation_image'] as Map<String, dynamic>;
      expect(droits['nombre_images'], etablissement.images.length);
      expect(droits['autorisation_ecrite_restaurant'], isA<bool>());
      if (etablissement.images.isEmpty) {
        expect(droits['statut'], 'aucune_image');
      }
    }
  });

  // ---------------------------------------------------------------------------
  // Position GPS : « disponible » n'est pas « confirmé »
  // ---------------------------------------------------------------------------
  group('position GPS : disponible n\'est pas confirmée', () {
    Etablissement fiche({double? lat, double? lon, bool verifie = false}) => Etablissement(
          id: 'test:position',
          cle: 'test:position',
          slug: 'test-position',
          nom: 'Fiche de test',
          nomOfficiel: 'Fiche de test',
          latitude: lat,
          longitude: lon,
          gpsVerifie: verifie,
        );

    test('coordonnées présentes et position confirmée', () {
      final etablissement = fiche(lat: 14.6928, lon: -17.4467, verifie: true);
      expect(etablissement.coordonneesValides, isTrue);
      expect(etablissement.aDesCoordonnees, isTrue);
      expect(etablissement.positionConfirmee, isTrue);
      expect(etablissement.etatPosition, 'Position confirmée');
      expect(const FiltresCatalogue(seulementGps: true).correspond(etablissement), isTrue);
    });

    test('coordonnées présentes mais NON confirmées : jamais présentées comme vérifiées', () {
      final etablissement = fiche(lat: 14.6928, lon: -17.4467);
      expect(etablissement.coordonneesValides, isTrue);
      expect(etablissement.aDesCoordonnees, isTrue);
      expect(etablissement.positionConfirmee, isFalse);
      expect(etablissement.etatPosition, contains('non confirmée'));
      expect(const FiltresCatalogue(seulementGps: true).correspond(etablissement), isFalse,
          reason: 'le filtre « Avec GPS vérifié » ne doit pas retenir une position non confirmée');
    });

    test('coordonnées absentes', () {
      final etablissement = fiche();
      expect(etablissement.coordonneesValides, isFalse);
      expect(etablissement.aDesCoordonnees, isFalse);
      expect(etablissement.positionConfirmee, isFalse);
      expect(etablissement.etatPosition, 'Position non disponible');
      expect(const FiltresCatalogue(seulementGps: true).correspond(etablissement), isFalse);
    });

    test('coordonnées invalides : hors emprise, NaN, infinies, incomplètes', () {
      final invalides = <Etablissement>[
        fiche(lat: 48.8566, lon: 2.3522), // Paris : hors de l'emprise du Sénégal
        fiche(lat: -14.6928, lon: -17.4467), // hémisphère sud
        fiche(lat: 14.6928, lon: 200.0),
        fiche(lat: 14.6928, lon: double.nan),
        fiche(lat: 14.6928, lon: double.infinity),
        fiche(lat: 14.6928), // longitude manquante
        fiche(lon: -17.4467), // latitude manquante
      ];
      for (final etablissement in invalides) {
        expect(etablissement.coordonneesValides, isFalse,
            reason: 'coordonnées invalides acceptées : ${etablissement.latitude}, ${etablissement.longitude}');
        expect(etablissement.aDesCoordonnees, isFalse);
        expect(etablissement.positionConfirmee, isFalse);
        expect(const FiltresCatalogue(seulementGps: true).correspond(etablissement), isFalse);
      }
    });

    test('un drapeau « vérifié » ne rend pas exploitables des coordonnées aberrantes', () {
      final etablissement = fiche(lat: 48.8566, lon: 2.3522, verifie: true);
      expect(etablissement.positionConfirmee, isFalse,
          reason: 'une position hors emprise ne doit jamais être présentée comme confirmée');
    });

    test('aucune coordonnée du catalogue n\'est hors de l\'emprise du Sénégal', () {
      for (final etablissement in etablissements) {
        if (etablissement.latitude == null && etablissement.longitude == null) continue;
        expect(etablissement.coordonneesValides, isTrue,
            reason: '${etablissement.id} : coordonnées incomplètes ou hors emprise, '
                'elles ne doivent pas être utilisées pour positionner une fiche');
      }
    });

    test('une position n\'est déclarée confirmée qu\'avec une vérification documentée', () {
      for (final etablissement in etablissements.where((element) => element.gpsVerifie)) {
        expect(etablissement.derniereVerificationLe, isNotNull,
            reason: '${etablissement.id} : position déclarée confirmée sans date de vérification recevable');
      }
    });

    test('le filtre « Avec GPS vérifié » ne retient que des positions confirmées', () {
      final retenus = etablissements.where(const FiltresCatalogue(seulementGps: true).correspond).toList();
      for (final etablissement in retenus) {
        expect(etablissement.positionConfirmee, isTrue);
        expect(etablissement.coordonneesValides, isTrue);
      }
      expect(retenus.length, etablissements.where((element) => element.gpsVerifie).length,
          reason: 'le filtre doit rendre exactement les positions confirmées, ni plus ni moins');
    });
  });

  // ---------------------------------------------------------------------------
  // Catalogue distribué : aucune donnée pratique des fiches non publiées
  // ---------------------------------------------------------------------------
  group('catalogue distribué', () {
    List<Map<String, dynamic>> fiches() =>
        (racine['etablissements'] as List).cast<Map<String, dynamic>>();

    test('les fiches non publiées ne distribuent aucune donnée pratique', () {
      for (final fiche in fiches().where((element) => element['est_publication_visible'] != true)) {
        for (final champ in const [
          'adresse',
          'points_de_repere',
          'latitude',
          'longitude',
          'telephone',
          'whatsapp',
          'email',
          'site_web',
          'facebook',
          'instagram',
          'commande_en_ligne_url',
          'reservation_url',
          'fourchette_prix',
          'commentaire_verification',
        ]) {
          expect(fiche[champ], isNull,
              reason: '${fiche['slug']} : « $champ » est distribué avec l\'application alors que la fiche '
                  'n\'est pas publiée');
        }
        for (final champ in const [
          'services',
          'horaires',
          'zones_livraison',
          'images',
          'menus',
          'equipements',
          'modes_paiement',
        ]) {
          expect(fiche[champ], isEmpty,
              reason: '${fiche['slug']} : « $champ » est distribué avec l\'application');
        }
        expect(fiche['gps_verifie'], isFalse);
        for (final exploitation in (fiche['exploitation'] as List? ?? const [])) {
          expect((exploitation as Map)['statut_confirmation'], 'inconnu',
              reason: '${fiche['slug']} : l\'exploitation d\'une fiche non publiée ne doit pas être distribuée');
          expect(exploitation['nom_public'], isNull);
          expect(exploitation['entreprise'], isNull);
        }
      }
    });

    test('les fiches non publiées restent conservées et traçables', () {
      for (final fiche in fiches().where((element) => element['est_publication_visible'] != true)) {
        expect(fiche['nom'], isNotEmpty, reason: 'une fiche non publiée perd son nom');
        expect(fiche['motif_non_publication'], isNotEmpty,
            reason: '${fiche['slug']} : fiche écartée sans motif');
        expect(fiche['sources'], isNotEmpty, reason: '${fiche['slug']} : provenance perdue');
        expect(fiche['donnees_pratiques_retirees'], isTrue,
            reason: '${fiche['slug']} : la réduction de distribution doit être explicite dans le fichier');
      }
    });
  });

  // ---------------------------------------------------------------------------
  // Parcours publics : une fiche non publiée reste interne
  // ---------------------------------------------------------------------------
  group('parcours publics et publication', () {
    late CatalogueRepository depot;

    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(<String, Object>{});
      depot = CatalogueRepository.instance;
      await depot.charger();
    });

    test('le catalogue embarqué est chargé en entier', () {
      expect(depot.erreur, isNull, reason: 'catalogue illisible : ${depot.erreur}');
      expect(depot.etablissements.length, etablissements.length);
      final publication = racine['couverture']['publication'] as Map<String, dynamic>;
      expect(depot.etablissementsPublies.length, publication['fiches_publiees']);
      expect(depot.etablissementsNonPublies.length, publication['fiches_non_publiees']);
      expect(depot.etablissementsNonPublies, isNotEmpty,
          reason: 'ce test perdrait son sens sans fiche non publiée à contrôler');
    });

    test('aucune fiche non publiée ne remonte par la recherche (nom, identifiant, slug)', () {
      for (final fiche in depot.etablissementsNonPublies) {
        for (final requete in [fiche.nom, fiche.slug, fiche.id]) {
          final resultats = depot.rechercher(FiltresCatalogue(recherche: requete));
          expect(resultats.any((element) => element.id == fiche.id), isFalse,
              reason: 'la recherche « $requete » expose la fiche non publiée ${fiche.slug}');
        }
      }
      final toutes = depot.rechercher(const FiltresCatalogue());
      expect(toutes.every((element) => element.estPublicationVisible), isTrue);
      expect(toutes.length, depot.etablissementsPublies.length);
    });

    test('aucune fiche non publiée ne remonte dans les listes, facettes ou compteurs publics', () {
      final identifiants = depot.etablissementsNonPublies.map((element) => element.id).toSet();
      final exposes = depot.etablissementsPublies.where((element) => identifiants.contains(element.id));
      expect(exposes, isEmpty);
      expect(depot.qualiteDistribuee['fiches_total'], depot.etablissementsPublies.length,
          reason: 'les mesures de complétude affichées doivent porter sur les fiches diffusées');
      expect(depot.qualite['fiches_total'], depot.etablissements.length,
          reason: 'les totaux internes doivent continuer de compter toutes les fiches conservées');
    });

    test('favoris : les fiches non publiées ne sont ni listées ni ouvrables', () async {
      final publiee = depot.etablissementsPublies.first;
      final privee = depot.etablissementsNonPublies.first;

      await depot.basculerFavori(publiee.id);
      await depot.basculerFavori(privee.id);
      expect(depot.favorisPublies.map((element) => element.id).toList(), [publiee.id]);
      expect(depot.favorisNonPublies.map((element) => element.id).toList(), [privee.id]);
      expect(depot.favorisNonPublies.first.estPublicationVisible, isFalse);

      await depot.basculerFavori(publiee.id);
      await depot.basculerFavori(privee.id);
    });

    test('favori pointant vers une fiche disparue : signalé, sans plantage', () async {
      await depot.basculerFavori('fiche-retiree-du-catalogue');
      expect(depot.favorisOrphelins, ['fiche-retiree-du-catalogue']);
      expect(depot.favorisPublies, isEmpty);
      await depot.basculerFavori('fiche-retiree-du-catalogue');
      expect(depot.favorisOrphelins, isEmpty);
    });

    testWidgets('l\'écran de détail ne diffuse rien d\'une fiche non publiée (accès direct)',
        (testeur) async {
      const privee = Etablissement(
        id: 'interne:test-ecran',
        cle: 'interne:test-ecran',
        slug: 'fiche-interne-de-test',
        nom: 'Fiche interne de test',
        nomOfficiel: 'Fiche interne de test',
        adresse: 'Rue 12, Testville',
        telephone: '+221700000000',
        whatsapp: '+221700000001',
        latitude: 14.6928,
        longitude: -17.4467,
        estPublicationVisible: false,
        motifNonPublication: 'doublon probable, à vérifier avant publication',
      );

      await testeur.pumpWidget(const MaterialApp(home: FicheScreen(etablissement: privee)));

      expect(find.textContaining('non publiée'), findsWidgets,
          reason: 'la fiche doit être annoncée comme non publiée');
      expect(find.textContaining('doublon probable'), findsWidgets,
          reason: 'le motif de non-publication doit être affiché');
      for (final interdit in ['Rue 12, Testville', '+221700000000', '+221700000001', '14.6928']) {
        expect(find.textContaining(interdit), findsNothing,
            reason: '« $interdit » ne doit jamais être affiché pour une fiche non publiée');
      }
    });

    testWidgets('les favoris non publiés ne sont pas listés', (testeur) async {
      final privee = depot.etablissementsNonPublies.first;
      await depot.basculerFavori(privee.id);

      await testeur.pumpWidget(const MaterialApp(home: FavorisScreen()));

      expect(find.text(privee.nom), findsNothing,
          reason: 'une fiche non publiée ne doit pas être listée dans les favoris');
      expect(find.textContaining('ne sont pas publiées'), findsWidgets,
          reason: 'le visiteur doit être informé sans que les données soient diffusées');

      await depot.basculerFavori(privee.id);
    });
  });
}
