import 'package:dekk_food/data/restaurant_catalog.dart';
import 'package:dekk_food/models/order.dart';
import 'package:dekk_food/models/restaurant.dart';
import 'package:dekk_food/state/app_state.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Recherche du catalogue', () {
    test('ignore les accents et interroge les spécialités du menu', () {
      final query = normalizeSearchText('ceebu jen');
      final results = RestaurantCatalog.all
          .where((restaurant) => restaurant.matches(query))
          .toList(growable: false);

      expect(results.map((restaurant) => restaurant.name), contains('Chez Fatou'));
      expect(
        results
            .firstWhere((restaurant) => restaurant.name == 'Chez Fatou')
            .matchingSpecialty(query)
            ?.name,
        'Ceebu Jën (Riz au poisson)',
      );

      final localSpelling = normalizeSearchText('thiéb');
      expect(
        RestaurantCatalog.all
            .firstWhere((restaurant) => restaurant.name == 'Chez Fatou')
            .matches(localSpelling),
        isTrue,
      );
    });

    test('combine les mots d’une recherche plutôt que de chercher une phrase exacte', () {
      final query = normalizeSearchText('ngor gambas');
      final results = RestaurantCatalog.all
          .where((restaurant) => restaurant.matches(query))
          .toList(growable: false);

      expect(results.map((restaurant) => restaurant.name), contains('Seven Seven Dakar'));
    });
  });

  group('Panier', () {
    test('calcule avec des entiers FCFA et protège le restaurant associé', () {
      final firstRestaurant = RestaurantCatalog.all.first;
      final secondRestaurant = RestaurantCatalog.all[1];
      final cart = CartModel();
      final firstDish = firstRestaurant.menu.first;

      cart.addItem(
        restaurant: firstRestaurant,
        item: firstDish,
        quantity: 2,
      );

      expect(cart.totalItems, 2);
      expect(cart.subtotalFcfa, firstDish.priceFcfa * 2);
      expect(cart.belongsTo(firstRestaurant), isTrue);
      expect(
        () => cart.addItem(
          restaurant: secondRestaurant,
          item: secondRestaurant.menu.first,
        ),
        throwsA(isA<StateError>()),
      );

      cart.updateQuantity(firstDish.id, -2);
      expect(cart.isEmpty, isTrue);
      expect(cart.restaurant, isNull);
    });
  });

  test('une commande restaure son instantané depuis JSON', () {
    final order = FoodOrder(
      id: 'DF-20260917-123456',
      restaurantId: 'chez-fatou',
      restaurantName: 'Chez Fatou',
      restaurantPhone: '221338209238',
      items: const <CartLine>[
        CartLine(
          menuItemId: 'ceebu',
          name: 'Ceebu Jën',
          unitPriceFcfa: 3500,
          imageUrl: '',
          quantity: 2,
        ),
      ],
      subtotalFcfa: 7000,
      customerName: 'Awa Ndiaye',
      customerPhone: '+221 77 000 00 00',
      fulfillmentMode: FulfillmentMode.delivery,
      deliveryAddress: 'Point E, Dakar',
      note: 'Sans piment',
      preferredLanguage: 'Français',
      createdAt: DateTime.utc(2026, 9, 17, 12),
      status: OrderStatus.sentToRestaurant,
    );

    final restored = FoodOrder.fromJson(order.toJson());

    expect(restored.subtotalFcfa, 7000);
    expect(restored.items.single.lineTotalFcfa, 7000);
    expect(restored.fulfillmentMode, FulfillmentMode.delivery);
    expect(restored.status, OrderStatus.sentToRestaurant);
  });
}
