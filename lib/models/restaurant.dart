class Restaurant {
  final String id;
  final String name;
  final String cuisineType;
  final String neighborhood;
  final String? address;
  final String? phone;
  final String? whatsapp;
  final double? latitude;
  final double? longitude;

  Restaurant({
    required this.id,
    required this.name,
    required this.cuisineType,
    required this.neighborhood,
    this.address,
    this.phone,
    this.whatsapp,
    this.latitude,
    this.longitude,
  });

  factory Restaurant.fromJson(Map<String, dynamic> json) {
    final cuisines = json['cuisine_types'] ?? json['cuisine_type'];
    final cuisineType = cuisines is List
        ? cuisines.map((value) => value.toString()).join(', ')
        : (cuisines?.toString() ?? '');

    return Restaurant(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      cuisineType: cuisineType,
      neighborhood: (json['neighborhood'] ?? json['city'] ?? '').toString(),
      address: json['address']?.toString(),
      phone: json['phone']?.toString(),
      whatsapp: json['whatsapp']?.toString(),
      latitude: json['latitude'] != null
          ? (json['latitude'] as num).toDouble()
          : null,
      longitude: json['longitude'] != null
          ? (json['longitude'] as num).toDouble()
          : null,
    );
  }
}

class MenuItem {
  final String id;
  final String restaurantId;
  final String title;
  final String? description;
  final double price;
  final String? category;

  MenuItem({
    required this.id,
    required this.restaurantId,
    required this.title,
    this.description,
    required this.price,
    this.category,
  });

  factory MenuItem.fromJson(Map<String, dynamic> json) {
    return MenuItem(
      id: json['id']?.toString() ?? '',
      restaurantId: json['restaurant_id']?.toString() ?? '',
      title: (json['name'] ?? json['title'] ?? '').toString(),
      description: json['description']?.toString(),
      price: (json['price'] as num).toDouble(),
      category: json['category']?.toString(),
    );
  }
}
