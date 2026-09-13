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
    return Restaurant(
      id: json['id'],
      name: json['name'],
      cuisineType: json['cuisine_type'],
      neighborhood: json['neighborhood'],
      address: json['address'],
      phone: json['phone'],
      whatsapp: json['whatsapp'],
      latitude: json['latitude'] != null ? (json['latitude'] as num).toDouble() : null,
      longitude: json['longitude'] != null ? (json['longitude'] as num).toDouble() : null,
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
      id: json['id'],
      restaurantId: json['restaurant_id'],
      title: json['title'],
      description: json['description'],
      price: (json['price'] as num).toDouble(),
      category: json['category'],
    );
  }
}
