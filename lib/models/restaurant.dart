/// Normalise une chaîne avant la recherche afin que « thieb », « thiéb » et
/// « THIÉB » produisent le même résultat. Aucun package n'est nécessaire pour
/// cette recherche locale, qui reste donc instantanée même hors connexion.
String normalizeSearchText(String value) {
  const replacements = <String, String>{
    'à': 'a',
    'á': 'a',
    'â': 'a',
    'ã': 'a',
    'ä': 'a',
    'å': 'a',
    'æ': 'ae',
    'ç': 'c',
    'è': 'e',
    'é': 'e',
    'ê': 'e',
    'ë': 'e',
    'ì': 'i',
    'í': 'i',
    'î': 'i',
    'ï': 'i',
    'ñ': 'n',
    'ò': 'o',
    'ó': 'o',
    'ô': 'o',
    'õ': 'o',
    'ö': 'o',
    'œ': 'oe',
    'ù': 'u',
    'ú': 'u',
    'û': 'u',
    'ü': 'u',
    'ý': 'y',
    'ÿ': 'y',
  };

  final normalized = StringBuffer();
  for (final character in value.toLowerCase().split('')) {
    normalized.write(replacements[character] ?? character);
  }

  return normalized
      .toString()
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

String _slugify(String value) {
  final slug = normalizeSearchText(value).replaceAll(' ', '-');
  return slug.isEmpty ? 'restaurant-inconnu' : slug;
}

String _readString(dynamic value, {String fallback = ''}) {
  if (value == null) return fallback;
  final result = value.toString().trim();
  return result.isEmpty ? fallback : result;
}

double _readDouble(dynamic value, {double fallback = 0}) {
  if (value is num) return value.toDouble();
  return double.tryParse(_readString(value)) ?? fallback;
}

int _readInt(dynamic value, {int fallback = 0}) {
  if (value is num) return value.round();
  return int.tryParse(_readString(value)) ?? fallback;
}

int _parseFcfa(dynamic value) {
  if (value is num) return value.round();
  final groups = RegExp(r'\d+').allMatches(_readString(value));
  final digits = groups.map((match) => match.group(0)).join();
  return int.tryParse(digits) ?? 0;
}

String _formatCompactFcfa(int value) {
  final digits = value.toString();
  final groups = <String>[];
  for (var end = digits.length; end > 0; end -= 3) {
    final start = end - 3 < 0 ? 0 : end - 3;
    groups.insert(0, digits.substring(start, end));
  }
  return groups.join(' ');
}

String _priceRangeFromBounds(dynamic minimum, dynamic maximum) {
  final min = _readInt(minimum);
  final max = _readInt(maximum);
  if (min > 0 && max > 0) {
    return '${_formatCompactFcfa(min)} – ${_formatCompactFcfa(max)} FCFA';
  }
  if (min > 0) return 'À partir de ${_formatCompactFcfa(min)} FCFA';
  if (max > 0) return 'Jusqu’à ${_formatCompactFcfa(max)} FCFA';
  return 'Prix à consulter';
}

List<String> _readCuisineTypes(dynamic value) {
  if (value is List) {
    return value
        .map((entry) => _readString(entry))
        .where((entry) => entry.isNotEmpty)
        .toList(growable: false);
  }

  return _readString(value)
      .split(RegExp(r'\s*(?:&|/|,|·)\s*'))
      .map((entry) => entry.trim())
      .where((entry) => entry.isNotEmpty)
      .toList(growable: false);
}

bool _matchesTokens(String index, String normalizedQuery) {
  if (normalizedQuery.isEmpty) return true;
  return normalizedQuery
      .split(' ')
      .where((token) => token.isNotEmpty)
      .every(index.contains);
}

/// Synonymes courants de spécialités sénégalaises. Ils sont indexés avec le
/// libellé du plat afin que l'orthographe habituelle d'un client trouve le
/// menu, même si le restaurant utilise un autre nom sur sa carte.
String _menuAliases(String name) {
  final normalizedName = normalizeSearchText(name);
  const aliases = <String, List<String>>{
    'ceebu jen': <String>[
      'thieb',
      'thiep',
      'thieboudienne',
      'thiéboudienne',
      'riz au poisson',
    ],
    'poulet yassa': <String>['yassa', 'poulet aux oignons'],
    'mafe': <String>['mafé', 'sauce arachide'],
  };

  return aliases.entries
      .where((entry) => normalizedName.contains(entry.key))
      .expand((entry) => entry.value)
      .join(' ');
}

/// Adresse structurée, partagée entre les cartes, les fiches et le parcours de
/// retrait. Les coordonnées restent optionnelles tant qu'elles ne sont pas
/// renseignées par le restaurant.
class RestaurantAddress {
  const RestaurantAddress({
    required this.city,
    required this.zone,
    required this.neighborhood,
    required this.street,
    required this.mapQuery,
    this.latitude,
    this.longitude,
  });

  final String city;
  final String zone;
  final String neighborhood;
  final String street;
  final String mapQuery;
  final double? latitude;
  final double? longitude;

  String get shortLabel {
    final parts = <String>[neighborhood, zone].where((part) => part.isNotEmpty);
    return parts.join(' · ');
  }

  String get fullLabel {
    final parts = <String>[street, neighborhood, city]
        .where((part) => part.isNotEmpty)
        .toList(growable: false);
    return parts.join(', ');
  }

  String get navigationQuery {
    if (mapQuery.isNotEmpty) return mapQuery;
    return fullLabel;
  }
}

/// Notes et volume d'avis sont regroupés afin d'éviter les champs `dynamic`
/// dispersés dans les widgets.
class RestaurantRating {
  const RestaurantRating({required this.score, required this.reviewCount});

  final double score;
  final int reviewCount;
}

class RestaurantContact {
  const RestaurantContact({required this.phone, required this.whatsApp});

  final String phone;
  final String whatsApp;

  bool get hasPhone => phone.isNotEmpty;
  bool get hasWhatsApp => whatsApp.isNotEmpty;
}

/// Un plat du menu. Les prix sont conservés en FCFA sous forme d'entier afin de
/// ne plus recalculer un montant depuis une chaîne formatée dans le panier.
class MenuItem {
  MenuItem({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.description,
    required this.priceFcfa,
    required this.imageUrl,
    required this.isAvailable,
    required this.hygieneNote,
    this.category,
  }) : _searchIndex = normalizeSearchText(
          <String>[name, description, category ?? '', _menuAliases(name)].join(' '),
        );

  final String id;
  final String restaurantId;
  final String name;
  final String description;
  final int priceFcfa;
  final String imageUrl;
  final bool isAvailable;
  final String hygieneNote;
  final String? category;
  final String _searchIndex;

  String get searchIndex => _searchIndex;

  bool matches(String normalizedQuery) =>
      _matchesTokens(_searchIndex, normalizedQuery);

  factory MenuItem.fromCatalogJson(
    Map<String, dynamic> json, {
    required String restaurantId,
  }) {
    final name = _readString(json['name'] ?? json['title'], fallback: 'Plat');
    return MenuItem(
      id: _readString(
        json['id'],
        fallback: '$restaurantId-${_slugify(name)}',
      ),
      restaurantId: restaurantId,
      name: name,
      description: _readString(json['desc'] ?? json['description']),
      priceFcfa: _parseFcfa(json['price'] ?? json['price_fcfa']),
      imageUrl: _readString(json['image'] ?? json['image_url']),
      isAvailable: json['available'] ?? json['is_available'] ?? true,
      hygieneNote: _readString(json['hygiene'] ?? json['hygiene_note']),
      category: _readString(json['category']).isEmpty
          ? null
          : _readString(json['category']),
    );
  }

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem.fromCatalogJson(
      json,
      restaurantId: _readString(json['restaurant_id']),
    );
  }
}

/// Modèle de domaine unique pour le catalogue local et Supabase.
///
/// Les anciennes clés de démonstration (`cuisine`, `reviews`, `menu`) sont
/// acceptées dans [fromCatalogJson]. Les clés SQL (`cuisine_types`,
/// `review_count`, `menu_items`) le sont aussi dans [fromJson]. Ainsi, les
/// écrans ne dépendent plus du format de la source de données.
class Restaurant {
  Restaurant({
    required this.id,
    required this.name,
    required this.address,
    required List<String> cuisineTypes,
    required this.rating,
    required this.priceRange,
    required this.contact,
    required this.imageUrl,
    required this.description,
    required List<MenuItem> menu,
    required this.isActive,
  }) : cuisineTypes = List<String>.unmodifiable(cuisineTypes),
        menu = List<MenuItem>.unmodifiable(menu),
        _searchIndex = normalizeSearchText(
          <String>[
            name,
            address.city,
            address.zone,
            address.neighborhood,
            address.street,
            cuisineTypes.join(' '),
            ...menu.map((item) => item.searchIndex),
          ].join(' '),
        );

  final String id;
  final String name;
  final RestaurantAddress address;
  final List<String> cuisineTypes;
  final RestaurantRating rating;
  final String priceRange;
  final RestaurantContact contact;
  final String imageUrl;
  final String description;
  final List<MenuItem> menu;
  final bool isActive;
  final String _searchIndex;

  String get cuisineLabel => cuisineTypes.join(' · ');

  bool isInZone(String zone) => zone == 'Tous' || address.zone == zone;

  /// Recherche sur le restaurant *et* sur les spécialités de son menu.
  bool matches(String normalizedQuery) =>
      _matchesTokens(_searchIndex, normalizedQuery);

  /// Sert à expliquer pourquoi une adresse apparaît dans les résultats.
  MenuItem? matchingSpecialty(String normalizedQuery) {
    if (normalizedQuery.isEmpty) return null;
    for (final item in menu) {
      if (item.matches(normalizedQuery)) return item;
    }
    return null;
  }

  factory Restaurant.fromCatalogJson(Map<String, dynamic> json) {
    final name = _readString(json['name'], fallback: 'Restaurant');
    final id = _readString(json['id'], fallback: _slugify(name));
    final menuValue = json['menu'] ?? json['menu_items'];
    final rawMenu = menuValue is List ? menuValue : const <dynamic>[];
    final cuisineTypes = _readCuisineTypes(
      json['cuisine_types'] ?? json['cuisine_type'] ?? json['cuisine'],
    );
    final rawScore = _readDouble(json['rating']);
    final explicitPriceRange = _readString(json['price_range'] ?? json['price']);

    return Restaurant(
      id: id,
      name: name,
      address: RestaurantAddress(
        city: _readString(json['city'] ?? json['zone'], fallback: 'Sénégal'),
        zone: _readString(json['zone'] ?? json['city'], fallback: 'Sénégal'),
        neighborhood: _readString(json['neighborhood']),
        street: _readString(json['address']),
        mapQuery: _readString(json['gpsQuery'] ?? json['gps_query']),
        latitude: json['latitude'] == null
            ? null
            : _readDouble(json['latitude']),
        longitude: json['longitude'] == null
            ? null
            : _readDouble(json['longitude']),
      ),
      cuisineTypes: cuisineTypes.isEmpty
          ? const <String>['Cuisine variée']
          : List<String>.unmodifiable(cuisineTypes),
      rating: RestaurantRating(
        score: rawScore.clamp(0, 5).toDouble(),
        reviewCount: _readInt(json['review_count'] ?? json['reviews']),
      ),
      priceRange: explicitPriceRange.isNotEmpty
          ? explicitPriceRange
          : _priceRangeFromBounds(
              json['price_min_fcfa'],
              json['price_max_fcfa'],
            ),
      contact: RestaurantContact(
        phone: _readString(json['phone']),
        whatsApp: _readString(json['whatsapp'] ?? json['whats_app']),
      ),
      imageUrl: _readString(json['image_url'] ?? json['image']),
      description: _readString(json['description']),
      menu: rawMenu
          .whereType<Map>()
          .map(
            (item) => MenuItem.fromCatalogJson(
              Map<String, dynamic>.from(item),
              restaurantId: id,
            ),
          )
          .toList(growable: false),
      isActive: json['is_active'] ?? true,
    );
  }

  factory Restaurant.fromJson(Map<String, dynamic> json) =>
      Restaurant.fromCatalogJson(json);
}
