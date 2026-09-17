import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/order.dart';
import '../theme.dart';
import '../utils/external_actions.dart';
import '../utils/formatters.dart';
import '../widgets/dekk_ui.dart';
import 'cart_checkout_screens.dart';

class OrdersScreen extends StatelessWidget {
  const OrdersScreen({super.key, required this.onDiscover});

  final VoidCallback onDiscover;

  @override
  Widget build(BuildContext context) {
    final orders = AppScope.of(context).orders;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes commandes'),
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
        animation: orders,
        builder: (context, _) {
          if (orders.orders.isEmpty) {
            return EmptyState(
              icon: Icons.receipt_long_outlined,
              title: 'Pas encore de commande',
              description:
                  'Vos commandes envoyées sur WhatsApp apparaîtront ici pour un suivi simple.',
              action: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: DekkColors.orange,
                  foregroundColor: Colors.white,
                ),
                onPressed: onDiscover,
                icon: const Icon(Icons.explore_outlined),
                label: const Text('Découvrir les restaurants'),
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 18),
            itemCount: orders.orders.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final order = orders.orders[index];
              return _OrderCard(order: order);
            },
          );
        },
      ),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order});

  final FoodOrder order;

  @override
  Widget build(BuildContext context) {
    final isSent = order.status == OrderStatus.sentToRestaurant;
    final statusColor = isSent ? DekkColors.success : DekkColors.orange;
    return Material(
      color: Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(15),
      child: InkWell(
        borderRadius: BorderRadius.circular(15),
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => OrderDetailsScreen(order: order),
          ),
        ),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      order.restaurantName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right_rounded, color: DekkColors.orange),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '#${order.id} · ${formatOrderDate(order.createdAt)}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 11),
              Row(
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: statusColor.withOpacity(0.11),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      order.status.label,
                      style: TextStyle(
                        color: statusColor,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Text(
                    formatFcfa(order.subtotalFcfa),
                    style: const TextStyle(
                      color: DekkColors.orange,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OrderDetailsScreen extends StatelessWidget {
  const OrderDetailsScreen({super.key, required this.order});

  final FoodOrder order;

  Future<void> _contactRestaurant(BuildContext context) async {
    if (order.restaurantPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Aucun contact WhatsApp n’est disponible.')),
      );
      return;
    }

    final message = 'Bonjour, je souhaite suivre ma commande DEKK FOOD #${order.id}.';
    await openExternalUrl(
      context,
      Uri.https(
        'wa.me',
        '/${normalizePhoneNumber(order.restaurantPhone)}',
        <String, String>{'text': message},
      ),
      failureMessage: 'Impossible d’ouvrir WhatsApp.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Détail de commande')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 26),
        children: <Widget>[
          Text(
            order.restaurantName,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 5),
          Text(
            '#${order.id} · ${formatOrderDate(order.createdAt)}',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          _StatusBanner(status: order.status),
          const SizedBox(height: 23),
          Text(
            'Votre sélection',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 9),
          ...order.items.map(
            (item) => Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(13),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: Row(
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: FoodImage(
                      imageUrl: item.imageUrl,
                      width: 48,
                      height: 48,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '${item.quantity} × ${item.name}',
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Text(
                    formatFcfa(item.lineTotalFcfa),
                    style: const TextStyle(
                      color: DekkColors.orange,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 5),
          Row(
            children: <Widget>[
              const Text('Sous-total', style: TextStyle(fontWeight: FontWeight.w800)),
              const Spacer(),
              Text(
                formatFcfa(order.subtotalFcfa),
                style: const TextStyle(
                  color: DekkColors.orange,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(),
          ),
          Text(
            'Réception',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 8),
          _DetailsRow(label: 'Mode', value: order.fulfillmentMode.label),
          if (order.fulfillmentMode == FulfillmentMode.delivery)
            _DetailsRow(
              label: 'Adresse',
              value: order.deliveryAddress.isEmpty
                  ? 'À confirmer avec le restaurant'
                  : order.deliveryAddress,
            ),
          _DetailsRow(label: 'Client', value: order.customerName),
          _DetailsRow(label: 'Téléphone', value: order.customerPhone),
          if (order.note.isNotEmpty) _DetailsRow(label: 'Note', value: order.note),
          const SizedBox(height: 23),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF128C7E),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () => _contactRestaurant(context),
            icon: const Icon(Icons.chat_bubble_outline),
            label: const Text('Contacter le restaurant'),
          ),
        ],
      ),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status});

  final OrderStatus status;

  @override
  Widget build(BuildContext context) {
    final isSent = status == OrderStatus.sentToRestaurant;
    final color = isSent ? DekkColors.success : DekkColors.orange;
    final message = isSent
        ? 'Commande transmise. Le restaurant vous confirmera la disponibilité et le délai.'
        : 'La commande attend encore sa confirmation par le restaurant.';
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        border: Border.all(color: color.withOpacity(0.22)),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(
            isSent ? Icons.check_circle_outline : Icons.schedule_outlined,
            color: color,
          ),
          const SizedBox(width: 9),
          Expanded(
            child: Text(message, style: const TextStyle(height: 1.35)),
          ),
        ],
      ),
    );
  }
}

class _DetailsRow extends StatelessWidget {
  const _DetailsRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 86,
            child: Text(
              label,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}
