import 'dart:convert';
import 'dart:io';

import 'package:dekk_food/models/catalogue.dart';
import 'package:flutter_test/flutter_test.dart';

/// Vérifie que le catalogue embarqué reste exploitable par l'application :
/// structure, absence de données obligatoires manquantes, honnêteté des
/// informations affichées (aucun prix/niveau non étiqueté).
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
}
