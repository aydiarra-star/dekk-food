/// Accès au catalogue national.
///
/// 1. Le catalogue est embarqué dans l'application (`assets/data/catalogue.json`)
///    : l'application fonctionne donc sans réseau, y compris sur connexion lente.
/// 2. Si Supabase est configuré au moment de la compilation
///    (`--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`),
///    les mêmes données sont lues depuis la base et les contributions
///    (avis, signalements, revendications) y sont enregistrées.
///    Sans configuration, ces contributions sont conservées LOCALEMENT et
///    clairement présentées comme telles : on ne prétend jamais qu'elles ont
///    été transmises.
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import '../models/catalogue.dart';

class ConfigurationSupabase {
  static const String url = String.fromEnvironment('SUPABASE_URL');
  static const String cleAnon = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// La base n'est utilisée que si les deux paramètres sont fournis.
  static bool get estConfiguree => url.isNotEmpty && cleAnon.isNotEmpty;
}

class CatalogueRepository extends ChangeNotifier {
  CatalogueRepository._interne();

  static final CatalogueRepository instance = CatalogueRepository._interne();

  final List<Etablissement> _etablissements = [];
  final Set<String> _favoris = {};
  final List<Avis> _avisLocaux = [];
  final List<Demande> _demandesLocales = [];
  String _genereLe = '';
  List<String> _limites = const [];
  bool _charge = false;
  String? _erreur;

  List<Etablissement> get etablissements => List.unmodifiable(_etablissements);
  Set<String> get favoris => Set.unmodifiable(_favoris);
  List<Avis> get avisLocaux => List.unmodifiable(_avisLocaux);
  List<Demande> get demandesLocales => List.unmodifiable(_demandesLocales);
  String get genereLe => _genereLe;
  bool get charge => _charge;
  String? get erreur => _erreur;
  bool get baseConnectee => ConfigurationSupabase.estConfiguree;

  // ------------------------------------------------------------------ chargement
  Future<void> charger() async {
    if (_charge) return;
    try {
      final brut = await rootBundle.loadString('assets/data/catalogue.json');
      final donnees = jsonDecode(brut) as Map<String, dynamic>;
      final liste = (donnees['etablissements'] as List? ?? const [])
          .map((element) => Etablissement.fromJson(Map<String, dynamic>.from(element as Map)))
          .toList();
      _etablissements
        ..clear()
        ..addAll(liste);
      _genereLe = (donnees['genere_le'] ?? '') as String;
      final couverture = donnees['couverture'] as Map<String, dynamic>?;
      _limites = [
        'Le recensement est incomplet par nature : aucune source publique ne garantit l\u2019exhaustivité.',
        if (couverture != null) 'Régions couvertes à ce jour : ${(couverture['regions_couvertes'] as List? ?? []).length} / 14.',
      ];
      await _chargerStockageLocal();
      _charge = true;
      _erreur = null;
    } catch (exception) {
      _erreur = 'Catalogue indisponible : $exception';
      _charge = true;
    }
    notifyListeners();
  }

  Future<void> _chargerStockageLocal() async {
    final prefs = await SharedPreferences.getInstance();
    _favoris
      ..clear()
      ..addAll(prefs.getStringList('favoris') ?? const []);
    _avisLocaux
      ..clear()
      ..addAll(_lireListe(prefs, 'avis_locaux').map((element) => _avisDepuisJson(element)).whereType<Avis>());
    _demandesLocales
      ..clear()
      ..addAll(_lireListe(prefs, 'demandes_locales').map((element) => Demande.fromJson(element)));
  }

  List<Map<String, dynamic>> _lireListe(SharedPreferences prefs, String cle) {
    final brut = prefs.getStringList(cle) ?? const [];
    return brut
        .map((element) {
          try {
            return Map<String, dynamic>.from(jsonDecode(element) as Map);
          } catch (_) {
            return null;
          }
        })
        .whereType<Map<String, dynamic>>()
        .toList();
  }

  Avis? _avisDepuisJson(Map<String, dynamic> json) {
    final note = (json['note'] as num?)?.toInt();
    if (note == null) return null;
    return Avis(
      etablissementId: (json['etablissement_id'] ?? json['restaurant_id'] ?? '') as String,
      auteur: json['auteur'] as String?,
      note: note,
      commentaire: json['commentaire'] as String?,
      deposeLe: DateTime.tryParse((json['depose_le'] ?? '') as String) ?? DateTime.now(),
      statut: (json['statut'] ?? 'en_attente') as String,
    );
  }

  // ------------------------------------------------------------------- recherche
  List<Etablissement> rechercher(FiltresCatalogue filtres) {
    final resultats = _etablissements.where(filtres.correspond).toList();
    resultats.sort((a, b) => a.nom.toLowerCase().compareTo(b.nom.toLowerCase()));
    return resultats;
  }

  Etablissement? parSlug(String slug) {
    for (final etablissement in _etablissements) {
      if (etablissement.slug == slug || etablissement.id == slug) return etablissement;
    }
    return null;
  }

  List<String> get regions =>
      (_etablissements.map((element) => element.region).whereType<String>().toSet().toList())..sort();

  List<String> get typesEtablissement {
    final entrees = <String, String>{};
    for (final etablissement in _etablissements) {
      final code = etablissement.typeEtablissement;
      if (code != null) entrees[code] = etablissement.typeLibelle;
    }
    final codes = entrees.keys.toList()..sort();
    return codes;
  }

  String libelleType(String code) =>
      _etablissements.firstWhere((element) => element.typeEtablissement == code,
          orElse: () => const Etablissement(id: '', cle: '', slug: '', nom: '', nomOfficiel: '')).typeLibelle;

  List<String> get categories {
    final entrees = <String, String>{};
    for (final etablissement in _etablissements) {
      for (var index = 0; index < etablissement.categories.length; index++) {
        entrees[etablissement.categories[index]] =
            index < etablissement.categoriesLibelles.length
                ? etablissement.categoriesLibelles[index]
                : etablissement.categories[index];
      }
    }
    final codes = entrees.keys.toList()..sort();
    return codes;
  }

  String libelleCategorie(String code) {
    for (final etablissement in _etablissements) {
      final index = etablissement.categories.indexOf(code);
      if (index >= 0 && index < etablissement.categoriesLibelles.length) {
        return etablissement.categoriesLibelles[index];
      }
    }
    return code;
  }

  /// Établissements les plus proches d'une position (rayon en kilomètres).
  List<Etablissement> prochesDe(double latitude, double longitude, {double rayonKm = 5}) {
    final resultats = <MapEntry<Etablissement, double>>[];
    for (final etablissement in _etablissements) {
      if (!etablissement.aDesCoordonnees) continue;
      final distance = distanceKm(
        latitude,
        longitude,
        etablissement.latitude!,
        etablissement.longitude!,
      );
      if (distance <= rayonKm) resultats.add(MapEntry(etablissement, distance));
    }
    resultats.sort((a, b) => a.value.compareTo(b.value));
    return resultats.map((entree) => entree.key).toList();
  }

  static double distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const rayonTerre = 6371.0;
    final dLat = _radians(lat2 - lat1);
    final dLon = _radians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(_radians(lat1)) * math.cos(_radians(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return 2 * rayonTerre * math.asin(math.sqrt(a));
  }

  static double _radians(double degres) => degres * math.pi / 180;

  // --------------------------------------------------------------------- favoris
  bool estFavori(String id) => _favoris.contains(id);

  Future<void> basculerFavori(String id) async {
    if (_favoris.contains(id)) {
      _favoris.remove(id);
    } else {
      _favoris.add(id);
    }
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList('favoris', _favoris.toList());
  }

  List<Etablissement> get favorisEtablissements =>
      _etablissements.where((element) => _favoris.contains(element.id) || _favoris.contains(element.slug)).toList();

  // ------------------------------------------------------- contributions visiteurs
  /// Enregistre un avis. Sans base connectée, l'avis reste local et « en attente
  /// de modération » : il n'est jamais publié automatiquement.
  Future<void> deposerAvis(Avis avis) async {
    _avisLocaux.insert(0, avis);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final existants = prefs.getStringList('avis_locaux') ?? <String>[];
    existants.insert(
      0,
      jsonEncode({
        'etablissement_id': avis.etablissementId,
        'auteur': avis.auteur,
        'note': avis.note,
        'commentaire': avis.commentaire,
        'depose_le': avis.deposeLe.toIso8601String(),
        'statut': avis.statut,
      }),
    );
    await prefs.setStringList('avis_locaux', existants);
  }

  Future<void> enregistrerDemande(Demande demande) async {
    _demandesLocales.insert(0, demande);
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    final existants = prefs.getStringList('demandes_locales') ?? <String>[];
    existants.insert(0, jsonEncode(demande.toJson()));
    await prefs.setStringList('demandes_locales', existants);
  }

  // ------------------------------------------------------------------ statistiques
  Map<String, int> get couvertureParRegion {
    final compteur = <String, int>{};
    for (final etablissement in _etablissements) {
      final region = etablissement.region ?? 'Région non renseignée';
      compteur[region] = (compteur[region] ?? 0) + 1;
    }
    final entrees = compteur.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return {for (final entree in entrees) entree.key: entree.value};
  }

  Map<String, int> get qualite {
    int avecAdresse = 0;
    int avecGps = 0;
    int gpsVerifie = 0;
    int avecTelephone = 0;
    int avecWhatsapp = 0;
    int avecHoraires = 0;
    int avecMenus = 0;
    int plats = 0;
    int photosAuthentiques = 0;
    int illustrationsSeules = 0;
    int proprietaireConfirme = 0;
    for (final etablissement in _etablissements) {
      if (etablissement.adresse != null) avecAdresse++;
      if (etablissement.aDesCoordonnees) avecGps++;
      if (etablissement.gpsVerifie) gpsVerifie++;
      if (etablissement.telephone != null) avecTelephone++;
      if (etablissement.whatsapp != null) avecWhatsapp++;
      if (etablissement.horaires.isNotEmpty) avecHoraires++;
      plats += etablissement.tousLesPlats.length;
      if (etablissement.tousLesPlats.any((plat) => plat.prix != null)) avecMenus++;
      if (etablissement.images.any((image) => !image.estIllustrationGenerique)) {
        photosAuthentiques++;
      } else if (etablissement.images.any((image) => image.estIllustrationGenerique)) {
        illustrationsSeules++;
      }
      if (etablissement.exploitation.any((element) => element.statutConfirmation == 'confirme')) {
        proprietaireConfirme++;
      }
    }
    final parNiveau = <String, int>{};
    for (final etablissement in _etablissements) {
      parNiveau[etablissement.niveauVerification] = (parNiveau[etablissement.niveauVerification] ?? 0) + 1;
    }
    return {
      'fiches_total': _etablissements.length,
      'fiches_adresse': avecAdresse,
      'fiches_gps': avecGps,
      'fiches_gps_verifie': gpsVerifie,
      'fiches_telephone': avecTelephone,
      'fiches_whatsapp': avecWhatsapp,
      'fiches_horaires': avecHoraires,
      'fiches_menus': avecMenus,
      'plats_total': plats,
      'fiches_photos_authentiques': photosAuthentiques,
      'fiches_illustrations_seules': illustrationsSeules,
      'fiches_proprietaire_confirme': proprietaireConfirme,
      ...parNiveau.map((cle, valeur) => MapEntry('niveau_$cle', valeur)),
    };
  }

  /// File de travail : les fiches les plus incomplètes d'abord.
  List<MapEntry<Etablissement, int>> get fileDeTravail {
    final entrees = _etablissements.map((etablissement) {
      var priorite = 0;
      if (etablissement.region == null) priorite += 3;
      if (etablissement.commune == null && etablissement.villeLibre == null) priorite += 2;
      if (etablissement.adresse == null) priorite += 2;
      if (!etablissement.aDesCoordonnees) priorite += 2;
      if (etablissement.contacts.isEmpty) priorite += 2;
      if (etablissement.horaires.isEmpty) priorite += 1;
      if (etablissement.tousLesPlats.isEmpty) priorite += 2;
      if (!etablissement.images.any((image) => !image.estIllustrationGenerique)) priorite += 1;
      if (etablissement.derniereVerificationLe == null) priorite += 2;
      return MapEntry(etablissement, priorite);
    }).toList();
    entrees.sort((a, b) => b.value.compareTo(a.value));
    return entrees;
  }

  List<String> get limites => _limites;
}
