/// Panier et historique de commandes.
///
/// Ce code est repris de la version 2.1.0 de DEKK FOOD : le comportement
/// (panier mono-restaurant, confirmation avant changement d'établissement,
/// historique en mémoire) est conservé à l'identique.
library;

import 'package:flutter/foundation.dart';

class CartModel extends ChangeNotifier {
  static final CartModel _instance = CartModel._internal();
  factory CartModel() => _instance;
  CartModel._internal();

  String? restaurantName;
  String? restaurantPhone;
  String? etablissementId;
  final List<Map<String, dynamic>> items = [];

  int get totalItems {
    int count = 0;
    for (final item in items) {
      count += (item['quantity'] as int);
    }
    return count;
  }

  int get subtotal {
    int sum = 0;
    for (final item in items) {
      sum += _prixEnNombre(item['price']) * (item['quantity'] as int);
    }
    return sum;
  }

  /// Certains prix sont « à confirmer » : ils ne sont alors pas additionnés.
  bool get contientPrixAConfirmer =>
      items.any((item) => item['prix_confirme'] != true);

  static int _prixEnNombre(dynamic prix) {
    if (prix is num) return prix.round();
    final chiffres = RegExp(r'[0-9]+').allMatches(prix?.toString() ?? '').map((m) => m.group(0)).join();
    return chiffres.isEmpty ? 0 : int.parse(chiffres);
  }

  void addItem(
    String resName,
    String? resPhone,
    Map<String, dynamic> dish, {
    int quantity = 1,
    String? idEtablissement,
  }) {
    if (restaurantName != null && restaurantName != resName) {
      return;
    }
    restaurantName = resName;
    restaurantPhone = resPhone;
    etablissementId = idEtablissement ?? etablissementId;

    final index = items.indexWhere((i) => i['name'] == dish['name']);
    if (index >= 0) {
      items[index]['quantity'] = (items[index]['quantity'] as int) + quantity;
    } else {
      items.add({
        'name': dish['name'],
        'price': dish['price'],
        'price_num': dish['price_num'],
        'prix_confirme': dish['prix_confirme'],
        'image': dish['image'],
        'quantity': quantity,
      });
    }
    notifyListeners();
  }

  void updateQuantity(int index, int delta) {
    items[index]['quantity'] = (items[index]['quantity'] as int) + delta;
    if (items[index]['quantity'] <= 0) {
      items.removeAt(index);
    }
    if (items.isEmpty) {
      restaurantName = null;
      restaurantPhone = null;
      etablissementId = null;
    }
    notifyListeners();
  }

  void clear() {
    restaurantName = null;
    restaurantPhone = null;
    etablissementId = null;
    items.clear();
    notifyListeners();
  }
}

final cartManager = CartModel();

class OrderHistoryModel extends ChangeNotifier {
  static final OrderHistoryModel _instance = OrderHistoryModel._internal();
  factory OrderHistoryModel() => _instance;
  OrderHistoryModel._internal();

  final List<Map<String, dynamic>> orders = [];

  void addOrder(Map<String, dynamic> order) {
    orders.insert(0, order);
    notifyListeners();
  }
}

final orderHistoryManager = OrderHistoryModel();

/// Modes de commande distingués par le cahier des charges.
enum ModeCommande {
  contactDirect,
  telephone,
  whatsapp,
  siteRestaurant,
  dekkFood,
  livraisonRestaurant,
  livraisonPartenaire,
  retraitSurPlace,
}

extension ModeCommandeLibelle on ModeCommande {
  String get libelle => const {
        ModeCommande.contactDirect: 'Contact direct avec l\u2019établissement',
        ModeCommande.telephone: 'Commande par téléphone',
        ModeCommande.whatsapp: 'Commande par WhatsApp',
        ModeCommande.siteRestaurant: 'Commande sur le site du restaurant',
        ModeCommande.dekkFood: 'Commande intégrée DEKK FOOD',
        ModeCommande.livraisonRestaurant: 'Livraison assurée par le restaurant',
        ModeCommande.livraisonPartenaire: 'Livraison assurée par un partenaire',
        ModeCommande.retraitSurPlace: 'Retrait sur place',
      }[this] ??
      name;

  bool get disponibleActuellement =>
      this == ModeCommande.contactDirect ||
      this == ModeCommande.telephone ||
      this == ModeCommande.whatsapp ||
      this == ModeCommande.retraitSurPlace;
}
