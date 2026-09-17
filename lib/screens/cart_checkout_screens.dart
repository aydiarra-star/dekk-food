import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/order.dart';
import '../models/restaurant.dart';
import '../theme.dart';
import '../utils/external_actions.dart';
import '../utils/formatters.dart';
import '../widgets/dekk_ui.dart';
import 'order_success_screen.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  Future<void> _confirmClear(BuildContext context) async {
    final cart = AppScope.of(context).cart;
    final clear = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Vider le panier ?'),
        content: const Text('Tous les plats sélectionnés seront retirés.'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: DekkColors.orange,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Vider'),
          ),
        ],
      ),
    );
    if (clear == true) cart.clear();
  }

  @override
  Widget build(BuildContext context) {
    final cart = AppScope.of(context).cart;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mon panier'),
        actions: <Widget>[
          AnimatedBuilder(
            animation: cart,
            builder: (context, _) {
              if (cart.isEmpty) return const SizedBox(width: 48);
              return IconButton(
                tooltip: 'Vider le panier',
                onPressed: () => _confirmClear(context),
                icon: const Icon(Icons.delete_outline_rounded),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: AnimatedBuilder(
        animation: cart,
        builder: (context, _) {
          if (cart.isEmpty) {
            return EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'Votre panier est vide',
              description: 'Ajoutez un plat depuis la fiche d’un restaurant pour commencer votre commande.',
              action: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: DekkColors.orange,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Découvrir les restaurants'),
              ),
            );
          }

          final restaurant = cart.restaurant!;
          return Column(
            children: <Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(16, 13, 16, 12),
                color: DekkColors.orange.withOpacity(0.09),
                child: Row(
                  children: <Widget>[
                    const Icon(Icons.storefront_outlined, color: DekkColors.orange),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            restaurant.name,
                            style: const TextStyle(fontWeight: FontWeight.w900),
                          ),
                          Text(
                            'Une commande est envoyée à un seul restaurant à la fois.',
                            style: TextStyle(
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 18),
                  itemCount: cart.items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 7),
                  itemBuilder: (context, index) {
                    final item = cart.items[index];
                    return Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Theme.of(context).dividerColor),
                      ),
                      child: Row(
                        children: <Widget>[
                          ClipRRect(
                            borderRadius: BorderRadius.circular(9),
                            child: FoodImage(
                              imageUrl: item.imageUrl,
                              width: 58,
                              height: 58,
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
                                  '${formatFcfa(item.unitPriceFcfa)} / plat',
                                  style: const TextStyle(
                                    color: DekkColors.orange,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Total : ${formatFcfa(item.lineTotalFcfa)}',
                                  style: TextStyle(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 4),
                          Column(
                            children: <Widget>[
                              QuantityPicker(
                                compact: true,
                                quantity: item.quantity,
                                onDecrease: () => cart.updateQuantity(
                                  item.menuItemId,
                                  -1,
                                ),
                                onIncrease: () => cart.updateQuantity(
                                  item.menuItemId,
                                  1,
                                ),
                              ),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                tooltip: 'Retirer ${item.name}',
                                color: Theme.of(context).colorScheme.onSurfaceVariant,
                                onPressed: () => cart.removeItem(item.menuItemId),
                                icon: const Icon(Icons.close_rounded, size: 18),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: cart,
        builder: (context, _) {
          if (cart.isEmpty) return const SizedBox.shrink();
          return SafeArea(
            top: false,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 13),
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                boxShadow: const <BoxShadow>[
                  BoxShadow(color: Colors.black12, blurRadius: 8, offset: Offset(0, -2)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        '${cart.totalItems} article${cart.totalItems > 1 ? 's' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Sous-total : ${formatFcfa(cart.subtotalFcfa)}',
                        style: const TextStyle(
                          color: DekkColors.orange,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 11),
                  TotalButton(
                    label: 'Continuer',
                    totalFcfa: cart.subtotalFcfa,
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const CheckoutScreen(),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _addressController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  late FulfillmentMode _fulfillmentMode;
  bool _initialized = false;
  bool _isSubmitting = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _fulfillmentMode = AppScope.of(context).settings.defaultFulfillment;
      _initialized = true;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final appState = AppScope.of(context);
    final cart = appState.cart;
    final restaurant = cart.restaurant;
    if (restaurant == null || cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Votre panier est vide.')),
      );
      return;
    }

    final restaurantPhone = normalizePhoneNumber(restaurant.contact.whatsApp);
    if (restaurantPhone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Ce restaurant ne possède pas de numéro WhatsApp configuré.'),
        ),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    final order = FoodOrder(
      id: createOrderId(DateTime.now()),
      restaurantId: restaurant.id,
      restaurantName: restaurant.name,
      restaurantPhone: restaurantPhone,
      items: List<CartLine>.from(cart.items),
      subtotalFcfa: cart.subtotalFcfa,
      customerName: _nameController.text.trim(),
      customerPhone: _phoneController.text.trim(),
      fulfillmentMode: _fulfillmentMode,
      deliveryAddress: _fulfillmentMode == FulfillmentMode.delivery
          ? _addressController.text.trim()
          : '',
      note: _noteController.text.trim(),
      preferredLanguage: appState.settings.orderLanguage.label,
      createdAt: DateTime.now(),
      status: OrderStatus.sentToRestaurant,
    );

    final whatsappUrl = Uri.https(
      'wa.me',
      '/$restaurantPhone',
      <String, String>{'text': order.whatsappMessage},
    );
    final opened = await openExternalUrl(
      context,
      whatsappUrl,
      failureMessage:
          'Impossible d’ouvrir WhatsApp. Votre panier a été conservé.',
    );
    if (!mounted || !opened) {
      if (mounted) setState(() => _isSubmitting = false);
      return;
    }

    appState.orders.add(order);
    cart.clear();
    if (!mounted) return;

    setState(() => _isSubmitting = false);
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute<void>(builder: (_) => OrderSuccessScreen(order: order)),
      (route) => route.isFirst,
    );
  }

  @override
  Widget build(BuildContext context) {
    final cart = AppScope.of(context).cart;
    return Scaffold(
      appBar: AppBar(title: const Text('Finaliser la commande')),
      body: AnimatedBuilder(
        animation: cart,
        builder: (context, _) {
          if (cart.isEmpty || cart.restaurant == null) {
            return EmptyState(
              icon: Icons.shopping_bag_outlined,
              title: 'Panier indisponible',
              description: 'Ajoutez au moins un plat avant de finaliser votre commande.',
              action: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: DekkColors.orange,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Retour au panier'),
              ),
            );
          }

          final restaurant = cart.restaurant!;
          return SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 130),
            child: Form(
              key: _formKey,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _CheckoutSummary(
                    restaurant: restaurant,
                    itemCount: cart.totalItems,
                    subtotalFcfa: cart.subtotalFcfa,
                  ),
                  const SizedBox(height: 23),
                  Text(
                    'Mode de réception',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 9),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: _ModeChoice(
                          icon: Icons.delivery_dining_outlined,
                          label: 'Livraison',
                          selected: _fulfillmentMode == FulfillmentMode.delivery,
                          onTap: () => setState(
                            () => _fulfillmentMode = FulfillmentMode.delivery,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _ModeChoice(
                          icon: Icons.storefront_outlined,
                          label: 'Retrait',
                          selected: _fulfillmentMode == FulfillmentMode.pickup,
                          onTap: () => setState(
                            () => _fulfillmentMode = FulfillmentMode.pickup,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (_fulfillmentMode == FulfillmentMode.pickup) ...<Widget>[
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: DekkColors.cream,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        'Retrait chez ${restaurant.name} · ${restaurant.address.fullLabel}',
                        style: const TextStyle(fontSize: 13, height: 1.35),
                      ),
                    ),
                  ],
                  const SizedBox(height: 23),
                  Text(
                    'Vos coordonnées',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 11),
                  TextFormField(
                    controller: _nameController,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Votre nom *',
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) {
                      if ((value ?? '').trim().length < 2) {
                        return 'Indiquez votre nom.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    textInputAction: _fulfillmentMode == FulfillmentMode.delivery
                        ? TextInputAction.next
                        : TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Téléphone sénégalais *',
                      hintText: '+221 77 000 00 00',
                      prefixIcon: Icon(Icons.phone_outlined),
                    ),
                    validator: (value) => isValidSenegalPhone(value ?? '')
                        ? null
                        : 'Saisissez un numéro sénégalais valide.',
                  ),
                  if (_fulfillmentMode == FulfillmentMode.delivery) ...<Widget>[
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: _addressController,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 2,
                      maxLines: 3,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Adresse de livraison *',
                        hintText: 'Quartier, rue, repère utile…',
                        alignLabelWithHint: true,
                        prefixIcon: Icon(Icons.location_on_outlined),
                      ),
                      validator: (value) {
                        if (_fulfillmentMode == FulfillmentMode.delivery &&
                            (value ?? '').trim().length < 5) {
                          return 'Ajoutez une adresse ou un repère précis.';
                        }
                        return null;
                      },
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _noteController,
                    textCapitalization: TextCapitalization.sentences,
                    minLines: 2,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Note pour le restaurant (facultatif)',
                      hintText: 'Ex. sans piment, appeler à l’arrivée…',
                      alignLabelWithHint: true,
                      prefixIcon: Icon(Icons.note_alt_outlined),
                    ),
                  ),
                  const SizedBox(height: 17),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      const Icon(Icons.lock_outline_rounded,
                          color: DekkColors.success, size: 18),
                      const SizedBox(width: 7),
                      Expanded(
                        child: Text(
                          'La commande est préparée puis transmise à ${restaurant.name} par WhatsApp pour confirmation.',
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 12,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: AnimatedBuilder(
        animation: cart,
        builder: (context, _) {
          if (cart.isEmpty) return const SizedBox.shrink();
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
                label: _isSubmitting
                    ? 'Ouverture de WhatsApp…'
                    : 'Confirmer sur WhatsApp',
                totalFcfa: cart.subtotalFcfa,
                icon: Icons.chat_outlined,
                backgroundColor: DekkColors.success,
                onPressed: _isSubmitting ? null : _submit,
              ),
            ),
          );
        },
      ),
    );
  }
}

class _CheckoutSummary extends StatelessWidget {
  const _CheckoutSummary({
    required this.restaurant,
    required this.itemCount,
    required this.subtotalFcfa,
  });

  final Restaurant restaurant;
  final int itemCount;
  final int subtotalFcfa;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: DekkColors.orange.withOpacity(0.09),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: DekkColors.orange.withOpacity(0.18)),
      ),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: FoodImage(
              imageUrl: restaurant.imageUrl,
              width: 49,
              height: 49,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  restaurant.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text('$itemCount article${itemCount > 1 ? 's' : ''}'),
              ],
            ),
          ),
          Text(
            formatFcfa(subtotalFcfa),
            style: const TextStyle(
              color: DekkColors.orange,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModeChoice extends StatelessWidget {
  const _ModeChoice({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? DekkColors.orange.withOpacity(0.11)
          : Theme.of(context).colorScheme.surface,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            border: Border.all(
              color: selected ? DekkColors.orange : Theme.of(context).dividerColor,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Icon(icon, color: selected ? DekkColors.orange : null, size: 20),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: selected ? DekkColors.orange : null,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
