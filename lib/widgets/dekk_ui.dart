import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/restaurant.dart';
import '../theme.dart';
import '../utils/formatters.dart';

class FoodImage extends StatelessWidget {
  const FoodImage({
    super.key,
    required this.imageUrl,
    required this.width,
    required this.height,
    this.fit = BoxFit.cover,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    Widget fallback() => Container(
          width: width,
          height: height,
          color: DekkColors.orange.withOpacity(0.12),
          alignment: Alignment.center,
          child: const Icon(
            Icons.restaurant,
            color: DekkColors.orange,
            size: 30,
          ),
        );

    if (imageUrl.trim().isEmpty) return fallback();

    return Image.network(
      imageUrl,
      width: width,
      height: height,
      fit: fit,
      filterQuality: FilterQuality.medium,
      errorBuilder: (_, __, ___) => fallback(),
      loadingBuilder: (context, child, loadingProgress) {
        if (loadingProgress == null) return child;
        return Container(
          width: width,
          height: height,
          color: DekkColors.orange.withOpacity(0.06),
          alignment: Alignment.center,
          child: const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        );
      },
    );
  }
}

class CartAppBarButton extends StatelessWidget {
  const CartAppBarButton({super.key, required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cart = AppScope.of(context).cart;
    return AnimatedBuilder(
      animation: cart,
      builder: (context, _) {
        if (cart.totalItems == 0) return const SizedBox(width: 48);
        return Semantics(
          button: true,
          label: '${cart.totalItems} article(s) dans le panier',
          child: SizedBox(
            width: 52,
            height: 48,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                IconButton(
                  tooltip: 'Ouvrir le panier',
                  icon: const Icon(Icons.shopping_bag_outlined),
                  onPressed: onPressed,
                ),
                Positioned(
                  right: 5,
                  top: 5,
                  child: Container(
                    constraints: const BoxConstraints(minWidth: 17, minHeight: 17),
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    decoration: const BoxDecoration(
                      color: Color(0xFFFFE082),
                      shape: BoxShape.circle,
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      '${cart.totalItems}',
                      style: const TextStyle(
                        color: Colors.black87,
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class FavoriteButton extends StatelessWidget {
  const FavoriteButton({
    super.key,
    required this.restaurant,
    this.color,
    this.tooltip,
  });

  final Restaurant restaurant;
  final Color? color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final favorites = AppScope.of(context).favorites;
    return AnimatedBuilder(
      animation: favorites,
      builder: (context, _) {
        final isFavorite = favorites.contains(restaurant.id);
        return IconButton(
          tooltip: tooltip ?? (isFavorite ? 'Retirer des favoris' : 'Ajouter aux favoris'),
          color: color ?? DekkColors.orange,
          onPressed: () => favorites.toggle(restaurant.id),
          icon: Icon(isFavorite ? Icons.favorite : Icons.favorite_border),
        );
      },
    );
  }
}

class RestaurantCard extends StatelessWidget {
  const RestaurantCard({
    super.key,
    required this.restaurant,
    required this.onTap,
    this.matchingSpecialty,
  });

  final Restaurant restaurant;
  final VoidCallback onTap;
  final MenuItem? matchingSpecialty;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? const Color(0xFF28211E)
            : DekkColors.cardGrey,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: <Widget>[
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FoodImage(
                    imageUrl: restaurant.imageUrl,
                    width: 82,
                    height: 88,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        restaurant.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '📍 ${restaurant.address.shortLabel}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        restaurant.cuisineLabel,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Row(
                        children: <Widget>[
                          const Icon(Icons.star_rounded, color: Colors.amber, size: 17),
                          const SizedBox(width: 2),
                          Text(
                            '${restaurant.rating.score.toStringAsFixed(1)} '
                            '(${restaurant.rating.reviewCount} avis)',
                            style: textTheme.labelSmall?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      if (matchingSpecialty != null) ...<Widget>[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 7,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: DekkColors.orange.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            'Spécialité : ${matchingSpecialty!.name}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: DekkColors.orange,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 2),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    FavoriteButton(restaurant: restaurant),
                    const Icon(
                      Icons.arrow_forward_ios_rounded,
                      color: DekkColors.orange,
                      size: 15,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class QuantityPicker extends StatelessWidget {
  const QuantityPicker({
    super.key,
    required this.quantity,
    required this.onDecrease,
    required this.onIncrease,
    this.compact = false,
  });

  final int quantity;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 21.0 : 27.0;
    final buttonSize = compact ? 34.0 : 42.0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        IconButton(
          constraints: BoxConstraints.tightFor(width: buttonSize, height: buttonSize),
          padding: EdgeInsets.zero,
          tooltip: 'Diminuer la quantité',
          icon: Icon(
            Icons.remove_circle_outline_rounded,
            color: onDecrease == null ? Colors.grey : DekkColors.orange,
            size: iconSize,
          ),
          onPressed: onDecrease,
        ),
        SizedBox(
          width: compact ? 22 : 30,
          child: Text(
            '$quantity',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: compact ? 15 : 20,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        IconButton(
          constraints: BoxConstraints.tightFor(width: buttonSize, height: buttonSize),
          padding: EdgeInsets.zero,
          tooltip: 'Augmenter la quantité',
          icon: Icon(
            Icons.add_circle_outline_rounded,
            color: onIncrease == null ? Colors.grey : DekkColors.orange,
            size: iconSize,
          ),
          onPressed: onIncrease,
        ),
      ],
    );
  }
}

class TotalButton extends StatelessWidget {
  const TotalButton({
    super.key,
    required this.label,
    required this.totalFcfa,
    required this.onPressed,
    this.icon = Icons.shopping_bag_outlined,
    this.backgroundColor = DekkColors.orange,
  });

  final String label;
  final int totalFcfa;
  final VoidCallback? onPressed;
  final IconData icon;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: backgroundColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 18),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        ),
        onPressed: onPressed,
        icon: Icon(icon),
        label: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: <Widget>[
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              formatFcfa(totalFcfa),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.action,
  });

  final IconData icon;
  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: 82,
              height: 82,
              decoration: BoxDecoration(
                color: DekkColors.orange.withOpacity(0.10),
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Icon(icon, size: 42, color: DekkColors.orange),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.35,
                  ),
            ),
            if (action != null) ...<Widget>[const SizedBox(height: 18), action!],
          ],
        ),
      ),
    );
  }
}
