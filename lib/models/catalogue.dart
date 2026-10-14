/// Modèles du catalogue national DEKK FOOD.
///
/// Ces modèles correspondent exactement à `assets/data/catalogue.json`, généré
/// depuis `data/seed/*.json` par `tools/catalogue` (source unique de vérité).
/// Chaque information porte sa source et son niveau de vérification : rien n'est
/// inventé côté application.
library;

class SourceInfo {
  final String code;
  final String? url;
  final String? dateCollecte;
  final String? donnees;
  final String? niveauConfiance;

  const SourceInfo({
    required this.code,
    this.url,
    this.dateCollecte,
    this.donnees,
    this.niveauConfiance,
  });

  factory SourceInfo.fromJson(Map<String, dynamic> json) => SourceInfo(
        code: (json['source'] ?? json['code'] ?? 'inconnue') as String,
        url: json['url'] as String?,
        dateCollecte: json['date_collecte'] as String?,
        donnees: json['donnees'] as String?,
        niveauConfiance: json['niveau_confiance'] as String?,
      );
}

class ContactInfo {
  final String type;
  final String valeur;
  final bool confirme;
  final String? source;

  const ContactInfo({
    required this.type,
    required this.valeur,
    this.confirme = false,
    this.source,
  });

  factory ContactInfo.fromJson(Map<String, dynamic> json) => ContactInfo(
        type: (json['type'] ?? 'autre') as String,
        valeur: (json['valeur'] ?? '') as String,
        confirme: json['confirme'] == true,
        source: json['source'] as String?,
      );
}

/// Service déclaré par l'établissement (terrasse, retrait, réservation…).
class ServiceEtablissement {
  final String code;
  final String libelle;
  final bool confirme;

  const ServiceEtablissement({required this.code, required this.libelle, this.confirme = false});

  factory ServiceEtablissement.fromJson(Map<String, dynamic> json) => ServiceEtablissement(
        code: (json['code'] ?? '') as String,
        libelle: (json['libelle'] ?? json['code'] ?? '') as String,
        confirme: json['confirme'] == true,
      );
}

class HoraireJour {
  final int jour;
  final String service;
  final String? ouverture;
  final String? fermeture;
  final bool ferme;
  final bool confirme;

  const HoraireJour({
    required this.jour,
    this.service = 'continu',
    this.ouverture,
    this.fermeture,
    this.ferme = false,
    this.confirme = false,
  });

  factory HoraireJour.fromJson(Map<String, dynamic> json) => HoraireJour(
        jour: (json['jour'] as num?)?.toInt() ?? 0,
        service: (json['service'] ?? 'continu') as String,
        ouverture: json['ouverture'] as String?,
        fermeture: json['fermeture'] as String?,
        ferme: json['ferme'] == true,
        confirme: json['confirme'] == true,
      );
}

class ImageEtablissement {
  final String url;
  final String typeMedia;
  final String? legende;
  final bool estPrincipale;
  final bool estIllustrationGenerique;
  final bool correspondanceVerifiee;
  final String? auteur;
  final String? licence;

  const ImageEtablissement({
    required this.url,
    this.typeMedia = 'photo_autre',
    this.legende,
    this.estPrincipale = false,
    this.estIllustrationGenerique = false,
    this.correspondanceVerifiee = false,
    this.auteur,
    this.licence,
  });

  factory ImageEtablissement.fromJson(Map<String, dynamic> json) => ImageEtablissement(
        url: (json['url'] ?? '') as String,
        typeMedia: (json['type_media'] ?? 'photo_autre') as String,
        legende: json['legende'] as String?,
        estPrincipale: json['est_principale'] == true,
        estIllustrationGenerique: json['est_illustration_generique'] == true,
        correspondanceVerifiee: json['correspondance_verifiee'] == true,
        auteur: json['auteur'] as String?,
        licence: json['licence'] as String?,
      );

  /// Mention obligatoire affichée sous toute image non authentique.
  String? get mentionDroits {
    if (estIllustrationGenerique) {
      final licenceTexte = licence == null ? '' : ' · $licence';
      return 'Illustration générique — ne représente pas l\u2019établissement$licenceTexte';
    }
    if (!correspondanceVerifiee) {
      return 'Photo non certifiée comme correspondant à l\u2019établissement';
    }
    if (licence != null || auteur != null) {
      return [auteur, licence].whereType<String>().join(' · ');
    }
    return null;
  }
}

class Plat {
  final String nom;
  final String? description;
  final String categorie;
  final double? prix;
  final String devise;
  final String? taillePortion;
  final String? options;
  final String? variantes;
  final String disponibilite;
  final String statutConfirmation;
  final List<String> allergenes;
  final List<String> regimes;
  final ImageEtablissement? image;

  const Plat({
    required this.nom,
    this.description,
    this.categorie = 'plat_principal',
    this.prix,
    this.devise = 'XOF',
    this.taillePortion,
    this.options,
    this.variantes,
    this.disponibilite = 'a_confirmer',
    this.statutConfirmation = 'a_confirmer',
    this.allergenes = const [],
    this.regimes = const [],
    this.image,
  });

  factory Plat.fromJson(Map<String, dynamic> json) => Plat(
        nom: (json['nom'] ?? '') as String,
        description: json['description'] as String?,
        categorie: (json['categorie'] ?? 'plat_principal') as String,
        prix: (json['prix'] as num?)?.toDouble(),
        devise: (json['devise'] ?? 'XOF') as String,
        taillePortion: json['taille_portion'] as String?,
        options: json['options'] as String?,
        variantes: json['variantes'] as String?,
        disponibilite: (json['disponibilite'] ?? 'a_confirmer') as String,
        statutConfirmation: (json['statut_confirmation'] ?? 'a_confirmer') as String,
        allergenes: (json['allergenes'] as List?)?.cast<String>() ?? const [],
        regimes: (json['regimes'] as List?)?.cast<String>() ?? const [],
        image: json['image'] == null
            ? null
            : ImageEtablissement.fromJson(Map<String, dynamic>.from(json['image'] as Map)),
      );

  bool get prixConfirme => prix != null && statutConfirmation == 'confirme';

  String get libelleCategorie => const {
        'entree': 'Entrée',
        'plat_principal': 'Plat principal',
        'accompagnement': 'Accompagnement',
        'dessert': 'Dessert',
        'boisson': 'Boisson',
        'formule': 'Formule',
        'menu_enfant': 'Menu enfant',
        'specialite': 'Spécialité',
        'petit_dejeuner': 'Petit-déjeuner',
      }[categorie] ??
      categorie;
}

class MenuCarte {
  final String nom;
  final String type;
  final String statut;
  final String? sourceUrl;
  final String? dateCollecte;
  final String? dateDebut;
  final String? dateFin;
  final List<Plat> plats;

  const MenuCarte({
    required this.nom,
    this.type = 'carte',
    this.statut = 'a_confirmer',
    this.sourceUrl,
    this.dateCollecte,
    this.dateDebut,
    this.dateFin,
    this.plats = const [],
  });

  factory MenuCarte.fromJson(Map<String, dynamic> json) => MenuCarte(
        nom: (json['nom'] ?? 'Carte') as String,
        type: (json['type'] ?? 'carte') as String,
        statut: (json['statut'] ?? 'a_confirmer') as String,
        sourceUrl: json['source_url'] as String?,
        dateCollecte: json['date_collecte'] as String?,
        dateDebut: json['date_debut'] as String?,
        dateFin: json['date_fin'] as String?,
        plats: (json['plats'] as List? ?? const [])
            .map((item) => Plat.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
      );

  bool get confirme => statut == 'confirme';

  String get libelleType => const {
        'carte': 'Carte',
        'menu_midi': 'Menu du midi',
        'plat_du_jour': 'Plat du jour',
        'menu_fete': 'Menu de fête',
        'menu_enfant': 'Menu enfant',
        'boissons': 'Boissons',
        'promotion': 'Promotion',
        'formule': 'Formule',
        'traiteur': 'Offre traiteur',
      }[type] ??
      type;
}

class Exploitation {
  final String role;
  final String libelle;
  final String statutConfirmation;
  final String? sourceUrl;
  final String? dateVerification;

  const Exploitation({
    this.role = 'exploitant',
    this.libelle = 'Propriétaire non renseigné',
    this.statutConfirmation = 'inconnu',
    this.sourceUrl,
    this.dateVerification,
  });

  factory Exploitation.fromJson(Map<String, dynamic> json) => Exploitation(
        role: (json['role'] ?? 'exploitant') as String,
        libelle: (json['libelle'] ?? 'Propriétaire non renseigné') as String,
        statutConfirmation: (json['statut_confirmation'] ?? 'inconnu') as String,
        sourceUrl: json['source_url'] as String?,
        dateVerification: json['date_verification'] as String?,
      );
}

class Etablissement {
  final String id;
  final String cle;
  final String slug;
  final String nom;
  final String nomOfficiel;
  final String? nomCommercial;
  final String? typeEtablissement;
  final String typeLibelle;
  final List<String> categories;
  final List<String> categoriesLibelles;
  final String? cuisineType;
  final String? descriptionCourte;
  final String? descriptionLongue;
  final String statut;
  final String niveauVerification;
  final String? region;
  final String? departement;
  final String? commune;
  final String? quartier;
  final String? quartierLibre;
  final String? villeLibre;
  final String? adresse;
  final String? pointsDeRepere;
  final double? latitude;
  final double? longitude;
  final bool gpsVerifie;
  final String? telephone;
  final bool telephoneConfirme;
  final String? whatsapp;
  final bool whatsappConfirme;
  final String? email;
  final String? siteWeb;
  final String? facebook;
  final String? instagram;
  final String? commandeEnLigneUrl;
  final String? reservationUrl;
  final double? prixMin;
  final double? prixMax;
  final String devise;
  final String? prixLibelle;
  final String? ambiance;
  final List<String> modesPaiement;
  final String? accessibilite;
  final List<String> equipements;
  final List<ContactInfo> contacts;
  final List<ServiceEtablissement> services;
  final List<HoraireJour> horaires;
  final List<Map<String, dynamic>> zonesLivraison;
  final List<ImageEtablissement> images;
  final String? imagePrincipaleUrl;
  final bool? imagePrincipaleEstGenerique;
  final List<MenuCarte> menus;
  final List<Exploitation> exploitation;
  final List<SourceInfo> sources;
  final String? dateCollecte;
  final String? derniereVerificationLe;
  final String? commentaireVerification;

  /// La fiche est-elle publiée ? Décision calculée par le pipeline selon une règle
  /// explicite ; une fiche non publiée est CONSERVÉE et porte son motif.
  final bool estPublicationVisible;
  final String? motifNonPublication;
  final String? reglePublication;

  /// « Publiée » ne veut pas dire « vérifiée » : la validation est un acte humain tracé.
  final String statutValidation;
  final String? validationPar;
  final String? validationLe;
  final double? noteMoyenne;
  final int nombreAvis;
  final bool commandeIntegreeDisponible;

  /// Vrai lorsque la fiche a été validée par une personne identifiée.
  bool get estValideeParControle =>
      statutValidation == 'validee' && validationPar != null && validationLe != null;

  /// Libellé honnête de l'état de publication, affiché à l'utilisateur.
  String get publicationLibelle => estPublicationVisible
      ? (derniereVerificationLe != null
          ? 'Fiche publiée, vérifiée le $derniereVerificationLe'
          : 'Fiche publiée — données non encore vérifiées sur place')
      : 'Fiche non publiée : ${motifNonPublication ?? 'motif non renseigné'}';

  const Etablissement({
    required this.id,
    required this.cle,
    required this.slug,
    required this.nom,
    required this.nomOfficiel,
    this.nomCommercial,
    this.typeEtablissement,
    this.typeLibelle = 'Établissement',
    this.categories = const [],
    this.categoriesLibelles = const [],
    this.cuisineType,
    this.descriptionCourte,
    this.descriptionLongue,
    this.statut = 'a_verifier',
    this.niveauVerification = 'a_confirmer',
    this.region,
    this.departement,
    this.commune,
    this.quartier,
    this.quartierLibre,
    this.villeLibre,
    this.adresse,
    this.pointsDeRepere,
    this.latitude,
    this.longitude,
    this.gpsVerifie = false,
    this.telephone,
    this.telephoneConfirme = false,
    this.whatsapp,
    this.whatsappConfirme = false,
    this.email,
    this.siteWeb,
    this.facebook,
    this.instagram,
    this.commandeEnLigneUrl,
    this.reservationUrl,
    this.prixMin,
    this.prixMax,
    this.devise = 'XOF',
    this.prixLibelle,
    this.ambiance,
    this.modesPaiement = const [],
    this.accessibilite,
    this.equipements = const [],
    this.contacts = const [],
    this.services = const [],
    this.horaires = const [],
    this.zonesLivraison = const [],
    this.images = const [],
    this.imagePrincipaleUrl,
    this.imagePrincipaleEstGenerique,
    this.menus = const [],
    this.exploitation = const [],
    this.sources = const [],
    this.dateCollecte,
    this.derniereVerificationLe,
    this.commentaireVerification,
    this.estPublicationVisible = false,
    this.motifNonPublication,
    this.reglePublication,
    this.statutValidation = 'non_validee',
    this.validationPar,
    this.validationLe,
    this.noteMoyenne,
    this.nombreAvis = 0,
    this.commandeIntegreeDisponible = false,
  });

  factory Etablissement.fromJson(Map<String, dynamic> json) => Etablissement(
        id: (json['id'] ?? '') as String,
        cle: (json['cle'] ?? '') as String,
        slug: (json['slug'] ?? '') as String,
        nom: (json['nom'] ?? '') as String,
        nomOfficiel: (json['nom_officiel'] ?? json['nom'] ?? '') as String,
        nomCommercial: json['nom_commercial'] as String?,
        typeEtablissement: json['type_etablissement'] as String?,
        typeLibelle: (json['type_libelle'] ?? 'Établissement') as String,
        categories: (json['categories'] as List?)?.cast<String>() ?? const [],
        categoriesLibelles: (json['categories_libelles'] as List?)?.cast<String>() ?? const [],
        cuisineType: json['cuisine_type'] as String?,
        descriptionCourte: json['description_courte'] as String?,
        descriptionLongue: json['description_longue'] as String?,
        statut: (json['statut'] ?? 'a_verifier') as String,
        niveauVerification: (json['niveau_verification'] ?? 'a_confirmer') as String,
        region: json['region'] as String?,
        departement: json['departement'] as String?,
        commune: json['commune'] as String?,
        quartier: json['quartier'] as String?,
        quartierLibre: json['quartier_libre'] as String?,
        villeLibre: json['ville_libre'] as String?,
        adresse: json['adresse'] as String?,
        pointsDeRepere: json['points_de_repere'] as String?,
        latitude: (json['latitude'] as num?)?.toDouble(),
        longitude: (json['longitude'] as num?)?.toDouble(),
        gpsVerifie: json['gps_verifie'] == true,
        telephone: json['telephone'] as String?,
        telephoneConfirme: json['telephone_confirme'] == true,
        whatsapp: json['whatsapp'] as String?,
        whatsappConfirme: json['whatsapp_confirme'] == true,
        email: json['email'] as String?,
        siteWeb: json['site_web'] as String?,
        facebook: json['facebook'] as String?,
        instagram: json['instagram'] as String?,
        commandeEnLigneUrl: json['commande_en_ligne_url'] as String?,
        reservationUrl: json['reservation_url'] as String?,
        prixMin: (json['fourchette_prix']?['min'] as num?)?.toDouble(),
        prixMax: (json['fourchette_prix']?['max'] as num?)?.toDouble(),
        devise: (json['fourchette_prix']?['devise'] ?? 'XOF') as String,
        prixLibelle: json['fourchette_prix']?['libelle'] as String?,
        ambiance: json['ambiance'] as String?,
        modesPaiement: (json['modes_paiement'] as List?)?.cast<String>() ?? const [],
        accessibilite: json['accessibilite'] as String?,
        equipements: (json['equipements'] as List?)?.cast<String>() ?? const [],
        contacts: _contactsDepuisJson(json),
        services: (json['services'] as List? ?? const [])
            .map((item) => ServiceEtablissement.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
        horaires: (json['horaires'] as List? ?? const [])
            .map((item) => HoraireJour.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
        zonesLivraison: (json['zones_livraison'] as List? ?? const [])
            .map((item) => Map<String, dynamic>.from(item as Map))
            .toList(),
        images: (json['images'] as List? ?? const [])
            .map((item) => ImageEtablissement.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
        imagePrincipaleUrl: json['image_principale_url'] as String?,
        imagePrincipaleEstGenerique: json['image_principale_est_generique'] as bool?,
        menus: (json['menus'] as List? ?? const [])
            .map((item) => MenuCarte.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
        exploitation: (json['exploitation'] as List? ?? const [])
            .map((item) => Exploitation.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
        sources: (json['sources'] as List? ?? const [])
            .map((item) => SourceInfo.fromJson(Map<String, dynamic>.from(item as Map)))
            .toList(),
        dateCollecte: json['date_collecte'] as String?,
        derniereVerificationLe: json['derniere_verification_le'] as String?,
        commentaireVerification: json['commentaire_verification'] as String?,
        estPublicationVisible: (json['est_publication_visible'] ?? false) as bool,
        motifNonPublication: json['motif_non_publication'] as String?,
        reglePublication: json['regle_publication'] as String?,
        statutValidation: (json['statut_validation'] ?? 'non_validee') as String,
        validationPar: json['validation_par'] as String?,
        validationLe: json['validation_le'] as String?,
        noteMoyenne: (json['note_moyenne'] as num?)?.toDouble(),
        nombreAvis: (json['nombre_avis'] as num?)?.toInt() ?? 0,
        commandeIntegreeDisponible: json['commande_integree_disponible'] == true,
      );

  /// Construit la liste des moyens de contact à partir des colonnes de la fiche.
  /// Aucun contact n'est affiché s'il n'existe pas côté données.
  static List<ContactInfo> _contactsDepuisJson(Map<String, dynamic> json) {
    final entrees = <ContactInfo>[];
    void ajouter(String type, dynamic valeur, bool confirme) {
      if (valeur is String && valeur.trim().isNotEmpty) {
        entrees.add(ContactInfo(type: type, valeur: valeur.trim(), confirme: confirme));
      }
    }

    ajouter('telephone', json['telephone'], json['telephone_confirme'] == true);
    ajouter('whatsapp', json['whatsapp'], json['whatsapp_confirme'] == true);
    ajouter('email', json['email'], json['email_confirme'] == true);
    ajouter('site_web', json['site_web'], json['site_web_confirme'] == true);
    ajouter('facebook', json['facebook'], json['facebook_confirme'] == true);
    ajouter('instagram', json['instagram'], json['instagram_confirme'] == true);
    ajouter('commande_en_ligne', json['commande_en_ligne_url'], json['commande_en_ligne_confirmee'] == true);
    ajouter('reservation', json['reservation_url'], json['reservation_confirmee'] == true);
    return entrees;
  }

  // ------------------------------------------------------------------ libellés
  String get localisation {
    final morceaux = [quartierLibre ?? quartier, commune, region]
        .where((element) => element != null && element.isNotEmpty)
        .toList();
    return morceaux.isEmpty ? 'Localisation non renseignée' : morceaux.join(' · ');
  }

  /// Un service (terrasse, livraison, réservation…) est-il renseigné ?
  bool aLeService(String code) {
    if (services.any((service) => service.code == code)) return true;
    return contacts.any((contact) => contact.type == code);
  }

  /// Nombre de services confirmés par une source.
  int get servicesConfirmes => services.where((service) => service.confirme).length;

  String get statutLibelle => const {
        'ouvert': 'Ouvert',
        'ferme_temporairement': 'Fermé temporairement',
        'ferme_definitivement': 'Définitivement fermé',
        'a_verifier': 'Statut à vérifier',
      }[statut] ??
      statut;

  String get niveauLibelle => const {
        'verifie': 'Fiche vérifiée',
        'partiellement_verifie': 'Partiellement vérifiée',
        'a_confirmer': 'À confirmer',
        'information_indisponible': 'Information indisponible',
        'fermeture_a_verifier': 'Fermeture à vérifier',
      }[niveauVerification] ??
      niveauVerification;

  bool get estVerifie => niveauVerification == 'verifie';
  bool get estPartiellementVerifie => niveauVerification == 'partiellement_verifie';

  bool get aDesHorairesFiables => horaires.any((horaire) => horaire.confirme);

  bool get aDesCoordonnees => latitude != null && longitude != null;

  List<Plat> get tousLesPlats =>
      menus.expand((menu) => menu.plats).toList(growable: false);

  /// La livraison n'est jamais annoncée comme acquise : elle n'apparaît que si
  /// un service de livraison a été explicitement enregistré pour l'établissement.
  bool get proposeLivraison =>
      aLeService('livraison_restaurant') || aLeService('livraison_partenaire');

  /// Fourchette de prix : affichée uniquement si elle provient d'une source.
  String? get fourchettePrixAffichee => prixLibelle;

  String get proprietaireLibelle {
    final entree = exploitation.firstWhere(
      (element) => element.statutConfirmation != 'inconnu',
      orElse: () => const Exploitation(),
    );
    return entree.libelle.isEmpty ? 'Propriétaire non renseigné' : entree.libelle;
  }
}

/// Filtres de recherche appliqués au catalogue.
class FiltresCatalogue {
  final String recherche;
  final String? region;
  final String? categorie;
  final String? typeEtablissement;
  final double? prixMax;
  final String? service;
  final bool seulementGps;
  final bool seulementMenus;
  final bool seulementVerifies;

  const FiltresCatalogue({
    this.recherche = '',
    this.region,
    this.categorie,
    this.typeEtablissement,
    this.prixMax,
    this.service,
    this.seulementGps = false,
    this.seulementMenus = false,
    this.seulementVerifies = false,
  });

  FiltresCatalogue copierAvec({
    String? recherche,
    String? region,
    String? categorie,
    String? typeEtablissement,
    double? prixMax,
    String? service,
    bool? seulementGps,
    bool? seulementMenus,
    bool? seulementVerifies,
    bool reinitialiserRegion = false,
    bool reinitialiserCategorie = false,
    bool reinitialiserType = false,
    bool reinitialiserPrix = false,
    bool reinitialiserService = false,
  }) {
    return FiltresCatalogue(
      recherche: recherche ?? this.recherche,
      region: reinitialiserRegion ? null : (region ?? this.region),
      categorie: reinitialiserCategorie ? null : (categorie ?? this.categorie),
      typeEtablissement: reinitialiserType ? null : (typeEtablissement ?? this.typeEtablissement),
      prixMax: reinitialiserPrix ? null : (prixMax ?? this.prixMax),
      service: reinitialiserService ? null : (service ?? this.service),
      seulementGps: seulementGps ?? this.seulementGps,
      seulementMenus: seulementMenus ?? this.seulementMenus,
      seulementVerifies: seulementVerifies ?? this.seulementVerifies,
    );
  }

  bool get estActif =>
      recherche.trim().isNotEmpty ||
      region != null ||
      categorie != null ||
      typeEtablissement != null ||
      prixMax != null ||
      service != null ||
      seulementGps ||
      seulementMenus ||
      seulementVerifies;

  /// Applique les filtres à une fiche.
  bool correspond(Etablissement etablissement) {
    final requete = _normaliser(recherche);
    if (requete.isNotEmpty) {
      final corpus = [
        etablissement.nom,
        etablissement.nomOfficiel,
        etablissement.quartier ?? '',
        etablissement.commune ?? '',
        etablissement.region ?? '',
        etablissement.cuisineType ?? '',
        etablissement.categoriesLibelles.join(' '),
        etablissement.descriptionCourte ?? '',
        etablissement.tousLesPlats.map((plat) => plat.nom).join(' '),
      ].map(_normaliser).join(' ');
      if (!corpus.contains(requete)) return false;
    }
    if (region != null && etablissement.region != region) return false;
    if (typeEtablissement != null && etablissement.typeEtablissement != typeEtablissement) return false;
    if (categorie != null && !etablissement.categories.contains(categorie)) return false;
    if (service != null && !etablissement.aLeService(service!)) return false;
    if (prixMax != null) {
      final prix = etablissement.prixMin ?? etablissement.prixMax;
      if (prix != null && prix > prixMax!) return false;
    }
    if (seulementGps && !etablissement.aDesCoordonnees) return false;
    if (seulementMenus && etablissement.tousLesPlats.isEmpty) return false;
    if (seulementVerifies && !etablissement.estVerifie) return false;
    return true;
  }

  static String _normaliser(String valeur) => valeur
      .toLowerCase()
      .replaceAll(RegExp('[àáâãäå]'), 'a')
      .replaceAll(RegExp('[éèêë]'), 'e')
      .replaceAll(RegExp('[íìîï]'), 'i')
      .replaceAll(RegExp('[óòôõö]'), 'o')
      .replaceAll(RegExp('[úùûü]'), 'u')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'[^a-z0-9 ]+'), ' ');
}

/// Avis déposé par un visiteur (modéré avant publication).
class Avis {
  final String etablissementId;
  final String? auteur;
  final int note;
  final String? commentaire;
  final DateTime deposeLe;
  final String statut;

  const Avis({
    required this.etablissementId,
    required this.note,
    this.auteur,
    this.commentaire,
    required this.deposeLe,
    this.statut = 'en_attente',
  });

  Map<String, dynamic> toJson() => {
        'restaurant_id': etablissementId,
        'auteur_nom': auteur,
        'note': note,
        'commentaire': commentaire,
        'depose_le': deposeLe.toIso8601String(),
        'statut': statut,
      };
}

/// Demande de correction / signalement / suggestion d'un établissement absent.
class Demande {
  final String type; // signalement | correction | suggestion | revendication
  final String? etablissementId;
  final String message;
  final String? contact;
  final DateTime creeLe;

  const Demande({
    required this.type,
    required this.message,
    this.etablissementId,
    this.contact,
    required this.creeLe,
  });

  Map<String, dynamic> toJson() => {
        'type': type,
        'restaurant_id': etablissementId,
        'message': message,
        'contact': contact,
        'cree_le': creeLe.toIso8601String(),
      };

  factory Demande.fromJson(Map<String, dynamic> json) => Demande(
        type: (json['type'] ?? 'signalement') as String,
        etablissementId: json['restaurant_id'] as String?,
        message: (json['message'] ?? '') as String,
        contact: json['contact'] as String?,
        creeLe: DateTime.tryParse((json['cree_le'] ?? '') as String) ?? DateTime.now(),
      );
}
