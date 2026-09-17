import 'restaurant.dart';

int _readFcfa(dynamic value) {
  if (value is num) return value.round();
  final digitGroups = RegExp(r'\d+').allMatches(value?.toString() ?? '');
  return int.tryParse(digitGroups.map((match) => match.group(0)).join()) ?? 0;
}

/// Représente une ligne figée du panier / d'une commande. On conserve une
/// copie du libellé et du prix pour que l'historique reste juste si le menu est
/// modifié ultérieurement.
class CartLine {
  const CartLine({
    required this.menuItemId,
    required this.name,
    required this.unitPriceFcfa,
    required this.imageUrl,
    required this.quantity,
  });

  final String menuItemId;
  final String name;
  final int unitPriceFcfa;
  final String imageUrl;
  final int quantity;

  int get lineTotalFcfa => unitPriceFcfa * quantity;

  CartLine copyWith({int? quantity}) {
    return CartLine(
      menuItemId: menuItemId,
      name: name,
      unitPriceFcfa: unitPriceFcfa,
      imageUrl: imageUrl,
      quantity: quantity ?? this.quantity,
    );
  }

  factory CartLine.fromMenuItem(MenuItem item, {required int quantity}) {
    return CartLine(
      menuItemId: item.id,
      name: item.name,
      unitPriceFcfa: item.priceFcfa,
      imageUrl: item.imageUrl,
      quantity: quantity,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'menu_item_id': menuItemId,
        'name': name,
        'unit_price_fcfa': unitPriceFcfa,
        'image_url': imageUrl,
        'quantity': quantity,
      };

  factory CartLine.fromJson(Map<String, dynamic> json) {
    final quantity = _readFcfa(json['quantity']);
    final price = json['unit_price_fcfa'] ?? json['price_fcfa'] ?? json['price'];
    return CartLine(
      menuItemId: json['menu_item_id']?.toString() ?? json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? json['title']?.toString() ?? 'Plat',
      unitPriceFcfa: _readFcfa(price),
      imageUrl: json['image_url']?.toString() ?? json['image']?.toString() ?? '',
      quantity: quantity < 1 ? 1 : quantity,
    );
  }
}

enum FulfillmentMode { delivery, pickup }

extension FulfillmentModeLabel on FulfillmentMode {
  String get label => switch (this) {
        FulfillmentMode.delivery => 'Livraison',
        FulfillmentMode.pickup => 'Retrait sur place',
      };

  String get storageValue => name;

  static FulfillmentMode fromStorage(String? value) {
    final normalized = (value ?? '').toLowerCase();
    return normalized == FulfillmentMode.pickup.name ||
            normalized.contains('retrait')
        ? FulfillmentMode.pickup
        : FulfillmentMode.delivery;
  }
}

enum OrderStatus { awaitingConfirmation, sentToRestaurant }

extension OrderStatusLabel on OrderStatus {
  String get label => switch (this) {
        OrderStatus.awaitingConfirmation => 'En attente de confirmation',
        OrderStatus.sentToRestaurant => 'Envoyée au restaurant',
      };

  String get storageValue => name;

  static OrderStatus fromStorage(String? value) {
    final normalized = (value ?? '').toLowerCase();
    return normalized == OrderStatus.sentToRestaurant.name ||
            normalized.contains('envoy')
        ? OrderStatus.sentToRestaurant
        : OrderStatus.awaitingConfirmation;
  }
}

/// Instantané complet de la commande qui peut être affiché hors connexion et
/// transmis au restaurant par WhatsApp.
class FoodOrder {
  FoodOrder({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.restaurantPhone,
    required List<CartLine> items,
    required this.subtotalFcfa,
    required this.customerName,
    required this.customerPhone,
    required this.fulfillmentMode,
    required this.deliveryAddress,
    required this.note,
    required this.preferredLanguage,
    required this.createdAt,
    required this.status,
  }) : items = List<CartLine>.unmodifiable(items);

  final String id;
  final String restaurantId;
  final String restaurantName;
  final String restaurantPhone;
  final List<CartLine> items;
  final int subtotalFcfa;
  final String customerName;
  final String customerPhone;
  final FulfillmentMode fulfillmentMode;
  final String deliveryAddress;
  final String note;
  final String preferredLanguage;
  final DateTime createdAt;
  final OrderStatus status;

  String get whatsappMessage {
    final buffer = StringBuffer()
      ..writeln('Bonjour,')
      ..writeln('Nouvelle commande DEKK FOOD #$id')
      ..writeln('Restaurant : $restaurantName')
      ..writeln()
      ..writeln('Client :')
      ..writeln('Nom : $customerName')
      ..writeln('Téléphone : $customerPhone')
      ..writeln('Mode : ${fulfillmentMode.label}')
      ..writeln('Langue souhaitée : $preferredLanguage');

    if (fulfillmentMode == FulfillmentMode.delivery &&
        deliveryAddress.trim().isNotEmpty) {
      buffer.writeln('Adresse : $deliveryAddress');
    }
    if (note.trim().isNotEmpty) {
      buffer.writeln('Note : $note');
    }

    buffer
      ..writeln()
      ..writeln('Commande :');
    for (final item in items) {
      buffer.writeln(
        '- ${item.quantity} × ${item.name} (${item.unitPriceFcfa} FCFA)',
      );
    }
    buffer
      ..writeln()
      ..writeln('Sous-total : $subtotalFcfa FCFA')
      ..write('(Commandé via DEKK FOOD)');
    return buffer.toString();
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'restaurant_id': restaurantId,
        'restaurant_name': restaurantName,
        'restaurant_phone': restaurantPhone,
        'items': items.map((item) => item.toJson()).toList(growable: false),
        'subtotal_fcfa': subtotalFcfa,
        'customer_name': customerName,
        'customer_phone': customerPhone,
        'fulfillment_mode': fulfillmentMode.storageValue,
        'delivery_address': deliveryAddress,
        'note': note,
        'preferred_language': preferredLanguage,
        'created_at': createdAt.toIso8601String(),
        'status': status.storageValue,
      };

  factory FoodOrder.fromJson(Map<String, dynamic> json) {
    final rawItems = json['items'];
    final parsedItems = rawItems is List
        ? rawItems
            .whereType<Map>()
            .map((item) => CartLine.fromJson(Map<String, dynamic>.from(item)))
            .toList(growable: false)
        : const <CartLine>[];
    final rawSubtotal = json['subtotal_fcfa'] ?? json['subtotal'];

    return FoodOrder(
      id: json['id']?.toString() ??
          json['order_id']?.toString() ??
          json['orderId']?.toString() ??
          '',
      restaurantId: json['restaurant_id']?.toString() ??
          json['restaurantId']?.toString() ??
          '',
      restaurantName: json['restaurant_name']?.toString() ??
          json['restaurantName']?.toString() ??
          '',
      restaurantPhone: json['restaurant_phone']?.toString() ??
          json['restaurantPhone']?.toString() ??
          '',
      items: parsedItems,
      subtotalFcfa: _readFcfa(rawSubtotal),
      customerName: json['customer_name']?.toString() ??
          json['name']?.toString() ??
          '',
      customerPhone: json['customer_phone']?.toString() ??
          json['phone']?.toString() ??
          '',
      fulfillmentMode: FulfillmentModeLabel.fromStorage(
        json['fulfillment_mode']?.toString() ?? json['order_type']?.toString(),
      ),
      deliveryAddress:
          json['delivery_address']?.toString() ?? json['address']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      preferredLanguage: json['preferred_language']?.toString() ?? 'Français',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
      status: OrderStatusLabel.fromStorage(json['status']?.toString()),
    );
  }
}

String createOrderId(DateTime dateTime) {
  final date = '${dateTime.year}'
      '${dateTime.month.toString().padLeft(2, '0')}'
      '${dateTime.day.toString().padLeft(2, '0')}';
  final suffix = dateTime.microsecondsSinceEpoch.toString().substring(
        dateTime.microsecondsSinceEpoch.toString().length - 6,
      );
  return 'DF-$date-$suffix';
}
