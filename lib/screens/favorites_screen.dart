import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/restaurant.dart';
import '../theme.dart';
import '../widgets/dekk_ui.dart';
import 'cart_checkout_screens.dart';
import 'restaurant_detail_screen.dart';

class FavoritesScreen extends StatelessWidget {
  const FavoritesScreen({
    super.key,
    required this.restaurants,
    required this.onDiscover,
  });

  final List<Restaurant> restaurants;
  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    final favorites = AppScope.of(context).favorites;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes favoris'),
        actions: <Widget>[
          CartAppBarButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CartScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: AnimatedBuilder(
        animation: favorites,
        builder: (context, _) {
          final selectedRestaurants = restaurants
              .where((restaurant) => favorites.contains(restaurant.id))
              .toList(growable: false);
          if (selectedRestaurants.isEmpty) {
            return EmptyState(
              icon: Icons.favorite_border_rounded,
              title: 'Vos bonnes adresses apparaîtront ici',
              description:
                  'Touchez le cœur sur une fiche ou une carte de restaurant pour la conserver.',
              action: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: DekkColors.orange,
                  foregroundColor: Colors.white,
                ),
                onPressed: onDiscover,
                icon: const Icon(Icons.explore_outlined),
                label: const Text('Explorer le guide'),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 14),
            itemCount: selectedRestaurants.length,
            itemBuilder: (context, index) {
              final restaurant = selectedRestaurants[index];
              return RestaurantCard(
                restaurant: restaurant,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => RestaurantDetailScreen(restaurant: restaurant),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
