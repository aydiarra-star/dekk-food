import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/restaurant.dart';
import '../theme.dart';
import '../utils/cart_actions.dart';
import '../utils/external_actions.dart';
import '../utils/formatters.dart';
import '../widgets/dekk_ui.dart';
import 'cart_checkout_screens.dart';

class RestaurantDetailScreen extends StatelessWidget {
  const RestaurantDetailScreen({super.key, required this.restaurant});

  final Restaurant restaurant;

  Future<void> _openNavigation(BuildContext context) async {
    final uri = Uri.https(
      'www.google.com',
      '/maps/search/',
      <String, String>{
        'api': '1',
        'query': restaurant.address.navigationQuery,
      },
    );
    await openExternalUrl(
      context,
      uri,
      failureMessage: 'Impossible d’ouvrir l’itinéraire pour le moment.',
    );
  }

  Future<void> _addToCart(BuildContext context, MenuItem item) async {
    final added = await addMenuItemToCart(
      context,
      restaurant: restaurant,
      item: item,
    );
    if (!context.mounted || !added) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${item.name} a été ajouté au panier.'),
        action: SnackBarAction(
          label: 'Voir',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const CartScreen()),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = AppScope.of(context).cart;
    return Scaffold(
      appBar: AppBar(
        title: Text(restaurant.name),
        actions: <Widget>[
          FavoriteButton(
            restaurant: restaurant,
            color: Colors.white,
            tooltip: 'Gérer les favoris',
          ),
          CartAppBarButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CartScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            SizedBox(
              width: double.infinity,
              height: 235,
              child: Stack(
                fit: StackFit.expand,
                children: <Widget>[
                  FoodImage(
                    imageUrl: restaurant.imageUrl,
                    width: double.infinity,
                    height: 235,
                  ),
                  Positioned(
                    left: 14,
                    bottom: 14,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 280),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.66),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Text(
                        restaurant.cuisineLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 26),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    restaurant.name,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 7),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.star_rounded, color: Colors.amber, size: 20),
                      const SizedBox(width: 3),
                      Text(
                        '${restaurant.rating.score.toStringAsFixed(1)} '
                        '(${restaurant.rating.reviewCount} avis)',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(width: 11),
                      const Icon(Icons.payments_outlined, size: 18, color: DekkColors.orange),
                      const SizedBox(width: 3),
                      Flexible(
                        child: Text(
                          restaurant.priceRange,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Padding(
                        padding: EdgeInsets.only(top: 2),
                        child: Icon(
                          Icons.location_on_outlined,
                          color: DekkColors.orange,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          restaurant.address.fullLabel,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (restaurant.description.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 14),
                    Text(
                      restaurant.description,
                      style: const TextStyle(height: 1.45),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: <Widget>[
                      if (restaurant.contact.hasPhone)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: DekkColors.success,
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () => openExternalUrl(
                            context,
                            Uri.parse('tel:${restaurant.contact.phone}'),
                            failureMessage: 'Impossible de lancer l’appel.',
                          ),
                          icon: const Icon(Icons.phone_outlined, size: 18),
                          label: const Text('Appeler'),
                        ),
                      if (restaurant.contact.hasWhatsApp)
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF128C7E),
                            foregroundColor: Colors.white,
                          ),
                          onPressed: () {
                            final phone = normalizePhoneNumber(
                              restaurant.contact.whatsApp,
                            );
                            return openExternalUrl(
                              context,
                              Uri.https('wa.me', '/$phone'),
                              failureMessage: 'WhatsApp n’est pas disponible.',
                            );
                          },
                          icon: const Icon(Icons.chat_bubble_outline, size: 18),
                          label: const Text('WhatsApp'),
                        ),
                      OutlinedButton.icon(
                        onPressed: () => _openNavigation(context),
                        icon: const Icon(Icons.directions_outlined, size: 18),
                        label: const Text('Itinéraire'),
                      ),
                    ],
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 22),
                    child: Divider(),
                  ),
                  Row(
                    children: <Widget>[
                      const Icon(Icons.restaurant_menu_rounded, color: DekkColors.orange),
                      const SizedBox(width: 8),
                      Text(
                        'Menu & commande',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    'Touchez un plat pour ses détails, ou utilisez + pour l’ajouter rapidement.',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (restaurant.menu.isEmpty)
                    const _NoMenuMessage()
                  else
                    ...restaurant.menu.map(
                      (item) => _MenuItemCard(
                        item: item,
                        onOpen: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => DishDetailScreen(
                              restaurant: restaurant,
                              dish: item,
                            ),
                          ),
                        ),
                        onAdd: () => _addToCart(context, item),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: cart,
        builder: (context, _) {
          if (!cart.hasItems || !cart.belongsTo(restaurant)) {
            return const SizedBox.shrink();
          }
          return SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
                ],
              ),
              child: TotalButton(
                label: 'Voir le panier · ${cart.totalItems} article(s)',
                totalFcfa: cart.subtotalFcfa,
                backgroundColor: DekkColors.success,
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const CartScreen()),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NoMenuMessage extends StatelessWidget {
  const _NoMenuMessage();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: DekkColors.cream,
        borderRadius: BorderRadius.circular(14),
      ),
      child: const Text(
        'Le menu est en cours de mise à jour. Contactez directement le restaurant pour connaître les disponibilités.',
      ),
    );
  }
}

class _MenuItemCard extends StatelessWidget {
  const _MenuItemCard({
    required this.item,
    required this.onOpen,
    required this.onAdd,
  });

  final MenuItem item;
  final VoidCallback onOpen;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final unavailable = !item.isAvailable;
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: unavailable
            ? Theme.of(context).disabledColor.withOpacity(0.07)
            : Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: unavailable ? null : onOpen,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: Opacity(
                    opacity: unavailable ? 0.45 : 1,
                    child: FoodImage(
                      imageUrl: item.imageUrl,
                      width: 72,
                      height: 72,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        item.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          fontSize: 12,
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        formatFcfa(item.priceFcfa),
                        style: const TextStyle(
                          color: DekkColors.orange,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 4),
                unavailable
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 5),
                        child: Text(
                          'Indisponible',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.redAccent, fontSize: 11),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Ajouter au panier',
                        color: DekkColors.orange,
                        icon: const Icon(Icons.add_circle_rounded),
                        onPressed: onAdd,
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class DishDetailScreen extends StatefulWidget {
  const DishDetailScreen({
    super.key,
    required this.restaurant,
    required this.dish,
  });

  final Restaurant restaurant;
  final MenuItem dish;

  @override
  State<DishDetailScreen> createState() => _DishDetailScreenState();
}

class _DishDetailScreenState extends State<DishDetailScreen> {
  int _quantity = 1;

  Future<void> _addToCart() async {
    final added = await addMenuItemToCart(
      context,
      restaurant: widget.restaurant,
      item: widget.dish,
      quantity: _quantity,
    );
    if (!mounted || !added) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$_quantity × ${widget.dish.name} ajouté${_quantity > 1 ? 's' : ''} au panier.',
        ),
        action: SnackBarAction(
          label: 'Panier',
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const CartScreen()),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    final cart = AppScope.of(context).cart;
    final total = widget.dish.priceFcfa * _quantity;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.dish.name),
        actions: <Widget>[
          CartAppBarButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CartScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            FoodImage(
              imageUrl: widget.dish.imageUrl,
              width: double.infinity,
              height: 278,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          widget.dish.name,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        formatFcfa(widget.dish.priceFcfa),
                        style: const TextStyle(
                          color: DekkColors.orange,
                          fontSize: 18,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  Text(
                    'Chez ${widget.restaurant.name} · ${widget.restaurant.address.neighborhood}',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  if (!widget.dish.isAvailable) ...<Widget>[
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Ce plat est actuellement indisponible. Consultez les autres spécialités du restaurant.',
                        style: TextStyle(color: Colors.redAccent),
                      ),
                    ),
                  ],
                  const SizedBox(height: 21),
                  Text(
                    'Description',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 7),
                  Text(
                    widget.dish.description,
                    style: const TextStyle(height: 1.48),
                  ),
                  AnimatedBuilder(
                    animation: settings,
                    builder: (context, _) {
                      if (!settings.showHygieneNotes) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 22),
                        child: Container(
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            color: DekkColors.success.withOpacity(0.08),
                            border: Border.all(
                              color: DekkColors.success.withOpacity(0.25),
                            ),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: <Widget>[
                              const Row(
                                children: <Widget>[
                                  Icon(Icons.verified_outlined, color: DekkColors.success),
                                  SizedBox(width: 8),
                                  Text(
                                    'Garantie hygiène & fraîcheur',
                                    style: TextStyle(
                                      color: DekkColors.success,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                widget.dish.hygieneNote.isEmpty
                                    ? 'Ingrédients frais contrôlés et préparation respectant les bonnes pratiques d’hygiène DEKK FOOD.'
                                    : widget.dish.hygieneNote,
                                style: const TextStyle(height: 1.38, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 28),
                  Center(
                    child: Column(
                      children: <Widget>[
                        Text(
                          'Quantité',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                        const SizedBox(height: 5),
                        QuantityPicker(
                          quantity: _quantity,
                          onDecrease: _quantity > 1
                              ? () => setState(() => _quantity--)
                              : null,
                          onIncrease: () => setState(() => _quantity++),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            color: Theme.of(context).scaffoldBackgroundColor,
            boxShadow: const <BoxShadow>[
              BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
            ],
          ),
          child: AnimatedBuilder(
            animation: cart,
            builder: (context, _) => TotalButton(
              label: widget.dish.isAvailable
                  ? 'Ajouter au panier'
                  : 'Plat indisponible',
              totalFcfa: total,
              onPressed: widget.dish.isAvailable ? _addToCart : null,
            ),
          ),
        ),
      ),
    );
  }
}
