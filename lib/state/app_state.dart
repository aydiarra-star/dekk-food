import 'dart:async';
import 'dart:collection';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../models/order.dart';
import '../models/restaurant.dart';
import '../services/local_storage_service.dart';

/// Un seul panier à la fois garantit que la commande WhatsApp est envoyée au
/// bon restaurant. L'écran qui ajoute un plat d'une autre adresse demande
/// explicitement l'accord du client avant de remplacer le panier.
class CartModel extends ChangeNotifier {
  Restaurant? _restaurant;
  final List<CartLine> _items = <CartLine>[];

  Restaurant? get restaurant => _restaurant;
  UnmodifiableListView<CartLine> get items => UnmodifiableListView(_items);
  bool get isEmpty => _items.isEmpty;
  bool get hasItems => _items.isNotEmpty;

  int get totalItems =>
      _items.fold<int>(0, (total, item) => total + item.quantity);
  int get subtotalFcfa =>
      _items.fold<int>(0, (total, item) => total + item.lineTotalFcfa);

  bool belongsTo(Restaurant restaurant) => _restaurant?.id == restaurant.id;

  void addItem({
    required Restaurant restaurant,
    required MenuItem item,
    int quantity = 1,
  }) {
    if (quantity < 1) return;
    if (item.restaurantId != restaurant.id) {
      throw ArgumentError('Ce plat ne correspond pas au restaurant sélectionné.');
    }
    if (_restaurant != null && !belongsTo(restaurant)) {
      throw StateError('Le panier est déjà associé à un autre restaurant.');
    }

    _restaurant ??= restaurant;
    final index = _items.indexWhere((line) => line.menuItemId == item.id);
    if (index == -1) {
      _items.add(CartLine.fromMenuItem(item, quantity: quantity));
    } else {
      _items[index] = _items[index].copyWith(
        quantity: _items[index].quantity + quantity,
      );
    }
    notifyListeners();
  }

  void updateQuantity(String menuItemId, int delta) {
    final index = _items.indexWhere((line) => line.menuItemId == menuItemId);
    if (index == -1 || delta == 0) return;

    final newQuantity = _items[index].quantity + delta;
    if (newQuantity <= 0) {
      _items.removeAt(index);
    } else {
      _items[index] = _items[index].copyWith(quantity: newQuantity);
    }

    if (_items.isEmpty) _restaurant = null;
    notifyListeners();
  }

  void removeItem(String menuItemId) {
    final index = _items.indexWhere((line) => line.menuItemId == menuItemId);
    if (index == -1) return;
    _items.removeAt(index);
    if (_items.isEmpty) _restaurant = null;
    notifyListeners();
  }

  void clear() {
    if (_restaurant == null && _items.isEmpty) return;
    _restaurant = null;
    _items.clear();
    notifyListeners();
  }
}

class FavoritesModel extends ChangeNotifier {
  FavoritesModel(this._storage)
      : _favoriteIds = _storage.readStringList(_storageKey).toSet();

  static const String _storageKey = 'dekk_food.favorite_restaurants.v1';

  final LocalStorageService _storage;
  final Set<String> _favoriteIds;

  UnmodifiableSetView<String> get ids => UnmodifiableSetView(_favoriteIds);
  bool contains(String restaurantId) => _favoriteIds.contains(restaurantId);

  void toggle(String restaurantId) {
    if (!_favoriteIds.add(restaurantId)) {
      _favoriteIds.remove(restaurantId);
    }
    _save();
    notifyListeners();
  }

  void clear() {
    if (_favoriteIds.isEmpty) return;
    _favoriteIds.clear();
    _save();
    notifyListeners();
  }

  void _save() {
    unawaited(_storage.writeStringList(_storageKey, _favoriteIds));
  }
}

class OrderHistoryModel extends ChangeNotifier {
  OrderHistoryModel(this._storage) : _orders = _restore(_storage);

  static const String _storageKey = 'dekk_food.orders.v1';

  final LocalStorageService _storage;
  final List<FoodOrder> _orders;

  UnmodifiableListView<FoodOrder> get orders => UnmodifiableListView(_orders);

  void add(FoodOrder order) {
    _orders.insert(0, order);
    _save();
    notifyListeners();
  }

  void clear() {
    if (_orders.isEmpty) return;
    _orders.clear();
    unawaited(_storage.remove(_storageKey));
    notifyListeners();
  }

  void _save() {
    final encoded = jsonEncode(
      _orders.map((order) => order.toJson()).toList(growable: false),
    );
    unawaited(_storage.writeString(_storageKey, encoded));
  }

  static List<FoodOrder> _restore(LocalStorageService storage) {
    final encoded = storage.readString(_storageKey);
    if (encoded == null || encoded.isEmpty) return <FoodOrder>[];

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! List) return <FoodOrder>[];
      return decoded
          .whereType<Map>()
          .map((entry) => FoodOrder.fromJson(Map<String, dynamic>.from(entry)))
          .where((order) => order.id.isNotEmpty)
          .toList(growable: true);
    } catch (_) {
      return <FoodOrder>[];
    }
  }
}

enum OrderLanguage { french, wolof, english }

extension OrderLanguageLabel on OrderLanguage {
  String get label => switch (this) {
        OrderLanguage.french => 'Français',
        OrderLanguage.wolof => 'Wolof',
        OrderLanguage.english => 'English',
      };

  static OrderLanguage fromStorage(String? value) =>
      OrderLanguage.values.firstWhere(
        (language) => language.name == value,
        orElse: () => OrderLanguage.french,
      );
}

/// Préférences qui ont un effet visible dans l'application et dans le message
/// transmis au restaurant. Elles sont conservées localement sur l'appareil.
class AppSettingsModel extends ChangeNotifier {
  AppSettingsModel(this._storage)
      : _showHygieneNotes = _storage.readBool(
          _showHygieneNotesKey,
          fallback: true,
        ),
        _defaultFulfillment = FulfillmentModeLabel.fromStorage(
          _storage.readString(_defaultFulfillmentKey),
        ),
        _orderLanguage = OrderLanguageLabel.fromStorage(
          _storage.readString(_orderLanguageKey),
        );

  static const String _showHygieneNotesKey =
      'dekk_food.show_hygiene_notes.v1';
  static const String _defaultFulfillmentKey =
      'dekk_food.default_fulfillment.v1';
  static const String _orderLanguageKey = 'dekk_food.order_language.v1';

  final LocalStorageService _storage;
  bool _showHygieneNotes;
  FulfillmentMode _defaultFulfillment;
  OrderLanguage _orderLanguage;

  bool get showHygieneNotes => _showHygieneNotes;
  FulfillmentMode get defaultFulfillment => _defaultFulfillment;
  OrderLanguage get orderLanguage => _orderLanguage;

  void setShowHygieneNotes(bool value) {
    if (_showHygieneNotes == value) return;
    _showHygieneNotes = value;
    unawaited(_storage.writeBool(_showHygieneNotesKey, value));
    notifyListeners();
  }

  void setDefaultFulfillment(FulfillmentMode value) {
    if (_defaultFulfillment == value) return;
    _defaultFulfillment = value;
    unawaited(_storage.writeString(_defaultFulfillmentKey, value.name));
    notifyListeners();
  }

  void setOrderLanguage(OrderLanguage value) {
    if (_orderLanguage == value) return;
    _orderLanguage = value;
    unawaited(_storage.writeString(_orderLanguageKey, value.name));
    notifyListeners();
  }
}

/// Garde l'onglet actif au niveau de l'application. Cela permet notamment à
/// l'écran de confirmation d'ouvrir directement le suivi des commandes sans
/// reconstruire le catalogue ni perdre la recherche en cours.
class NavigationModel extends ChangeNotifier {
  int _currentIndex = 0;

  int get currentIndex => _currentIndex;

  void select(int index) {
    if (index == _currentIndex || index < 0 || index > 3) return;
    _currentIndex = index;
    notifyListeners();
  }
}

/// Les dépendances de session sont regroupées derrière [AppScope] plutôt que
/// dans des singletons globaux. Cela rend les écrans testables et évite que les
/// données soient recréées à chaque changement d'onglet.
class AppState {
  AppState(LocalStorageService storage)
      : cart = CartModel(),
        favorites = FavoritesModel(storage),
        orders = OrderHistoryModel(storage),
        settings = AppSettingsModel(storage),
        navigation = NavigationModel();

  final CartModel cart;
  final FavoritesModel favorites;
  final OrderHistoryModel orders;
  final AppSettingsModel settings;
  final NavigationModel navigation;

  void clearCustomerData() {
    cart.clear();
    favorites.clear();
    orders.clear();
  }

  void dispose() {
    cart.dispose();
    favorites.dispose();
    orders.dispose();
    settings.dispose();
    navigation.dispose();
  }
}
