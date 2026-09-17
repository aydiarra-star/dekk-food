import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/order.dart';
import '../theme.dart';
import '../utils/formatters.dart';

class OrderSuccessScreen extends StatelessWidget {
  const OrderSuccessScreen({super.key, required this.order});

  final FoodOrder order;

  void _returnToTab(BuildContext context, int tabIndex) {
    AppScope.of(context).navigation.select(tabIndex);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Commande envoyée')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(26),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Container(
                  width: 92,
                  height: 92,
                  decoration: BoxDecoration(
                    color: DekkColors.success.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  alignment: Alignment.center,
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: DekkColors.success,
                    size: 62,
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Commande prête à être confirmée !',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height:9),
                Text(
                  'La commande #${order.id} a été ouverte dans WhatsApp pour ${order.restaurantName}.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 23),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(color: Theme.of(context).dividerColor),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Column(
                    children: <Widget>[
                      _SuccessInfoRow(label: 'Restaurant', value: order.restaurantName),
                      const SizedBox(height: 9),
                      _SuccessInfoRow(
                        label: 'Mode',
                        value: order.fulfillmentMode.label,
                      ),
                      const SizedBox(height: 9),
                      _SuccessInfoRow(
                        label: 'Montant',
                        value: formatFcfa(order.subtotalFcfa),
                        valueColor: DekkColors.orange,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: DekkColors.orange,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _returnToTab(context, 1),
                    icon: const Icon(Icons.receipt_long_outlined),
                    label: const Text('Voir mes commandes'),
                  ),
                ),
                const SizedBox(height: 9),
                TextButton(
                  onPressed: () => _returnToTab(context, 0),
                  child: const Text('Retour à la découverte'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SuccessInfoRow extends StatelessWidget {
  const _SuccessInfoRow({
    required this.label,
    required this.value,
    this.valueColor,
  });

  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Text(
          label,
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              color: valueColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}
