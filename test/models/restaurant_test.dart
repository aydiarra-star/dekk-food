import 'package:flutter_test/flutter_test.dart';
import 'package:dekk_food/models/restaurant.dart';

void main() {
  group('Restaurant.fromJson — schéma historique', () {
    test('convertit les IDs entiers et les coordonnées numériques', () {
      final restaurant = Restaurant.fromJson({
        'id': 12,
        'name': 'Chez Awa',
        'cuisine_types': ['senegalaise', 'africaine'],
        'neighborhood': null,
        'city': 'Bakel',
        'latitude': 14.9,
        'longitude': -12.4,
        'phone': null,
      });

      expect(restaurant.id, '12');
      expect(restaurant.name, 'Chez Awa');
      expect(restaurant.cuisineType, 'senegalaise, africaine');
      expect(restaurant.neighborhood, 'Bakel');
      expect(restaurant.latitude, 14.9);
      expect(restaurant.longitude, -12.4);
    });
  });

  group('MenuItem.fromJson — restaurant_menus', () {
    test('lit name et convertit les IDs et le prix entiers', () {
      final menu = MenuItem.fromJson({
        'id': 7,
        'restaurant_id': 12,
        'name': 'Thieboudienne',
        'description': 'Poisson et riz',
        'price': 2500,
        'category': 'Plat',
        'is_available': true,
      });

      expect(menu.id, '7');
      expect(menu.restaurantId, '12');
      expect(menu.title, 'Thieboudienne');
      expect(menu.description, 'Poisson et riz');
      expect(menu.price, 2500.0);
      expect(menu.category, 'Plat');
    });

    test('garde la compatibilité avec les clés historiques alternatives', () {
      final menu = MenuItem.fromJson({
        'id': 'uuid-menu',
        'restaurant_id': 'uuid-restaurant',
        'title': 'Menu existant',
        'price': 10.5,
      });

      expect(menu.id, 'uuid-menu');
      expect(menu.restaurantId, 'uuid-restaurant');
      expect(menu.title, 'Menu existant');
      expect(menu.price, 10.5);
    });
  });
}
