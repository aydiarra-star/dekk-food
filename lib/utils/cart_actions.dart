import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/restaurant.dart';
import '../theme.dart';

/// Ajoute un plat en garantissant qu'un même panier ne mélange jamais les
/// restaurants. Le choix de vider le panier reste toujours explicite.
Future<bool> addMenuItemToCart(
  BuildContext context, {
  required Restaurant restaurant,
  required MenuItem item,
  int quantity = 1,
}) async {
  final cart = AppScope.of(context).cart;

  if (cart.hasItems && !cart.belongsTo(restaurant)) {
    final shouldReplace = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Changer de restaurant ?'),
        content: Text(
          'Votre panier contient déjà des articles de '
          '${cart.restaurant?.name}. Voulez-vous le vider pour commander '
          'chez ${restaurant.name} ?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Conserver mon panier'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: DekkColors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Vider et continuer'),
          ),
        ],
      ),
    );

    if (shouldReplace != true) return false;
    cart.clear();
  }

  cart.addItem(restaurant: restaurant, item: item, quantity: quantity);
  return true;
}
