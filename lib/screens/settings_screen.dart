import 'package:flutter/material.dart';

import '../app_scope.dart';
import '../models/order.dart';
import '../state/app_state.dart';
import '../theme.dart';
import '../widgets/dekk_ui.dart';
import 'cart_checkout_screens.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _chooseFulfillmentMode(BuildContext context) async {
    final settings = AppScope.of(context).settings;
    final selected = await showModalBottomSheet<FulfillmentMode>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Mode de réception par défaut',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text('Préremplit le formulaire de commande.'),
              ),
              ...FulfillmentMode.values.map(
                (mode) => RadioListTile<FulfillmentMode>(
                  contentPadding: EdgeInsets.zero,
                  value: mode,
                  groupValue: settings.defaultFulfillment,
                  title: Text(mode.label),
                  onChanged: (value) => Navigator.of(sheetContext).pop(value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) settings.setDefaultFulfillment(selected);
  }

  Future<void> _chooseLanguage(BuildContext context) async {
    final settings = AppScope.of(context).settings;
    final selected = await showModalBottomSheet<OrderLanguage>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Langue souhaitée pour la commande',
                  style: TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text('Elle est ajoutée au message envoyé au restaurant.'),
              ),
              ...OrderLanguage.values.map(
                (language) => RadioListTile<OrderLanguage>(
                  contentPadding: EdgeInsets.zero,
                  value: language,
                  groupValue: settings.orderLanguage,
                  title: Text(language.label),
                  onChanged: (value) => Navigator.of(sheetContext).pop(value),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (selected != null) settings.setOrderLanguage(selected);
  }

  Future<void> _confirmEraseData(BuildContext context) async {
    final shouldErase = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Effacer les données locales ?'),
        content: const Text(
          'Le panier, les favoris et l’historique des commandes enregistrés sur cet appareil seront supprimés.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );
    if (shouldErase != true || !context.mounted) return;

    AppScope.of(context).clearCustomerData();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Les données locales ont été effacées.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final settings = AppScope.of(context).settings;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
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
        animation: settings,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.fromLTRB(12, 16, 12, 28),
          children: <Widget>[
            const _SettingsSectionTitle('Préférences de commande'),
            Card(
              margin: const EdgeInsets.only(top: 6),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: <Widget>[
                  ListTile(
                    leading: const Icon(Icons.language_rounded, color: DekkColors.orange),
                    title: const Text('Langue de la commande'),
                    subtitle: Text(settings.orderLanguage.label),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _chooseLanguage(context),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.delivery_dining_outlined,
                      color: DekkColors.orange,
                    ),
                    title: const Text('Réception par défaut'),
                    subtitle: Text(settings.defaultFulfillment.label),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => _chooseFulfillmentMode(context),
                  ),
                  const Divider(height: 1),
                  SwitchListTile(
                    secondary: const Icon(
                      Icons.verified_outlined,
                      color: DekkColors.orange,
                    ),
                    title: const Text('Garanties d’hygiène'),
                    subtitle: const Text('Afficher les informations de fraîcheur sur les plats.'),
                    value: settings.showHygieneNotes,
                    activeColor: DekkColors.orange,
                    onChanged: settings.setShowHygieneNotes,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const _SettingsSectionTitle('Données et application'),
            Card(
              margin: const EdgeInsets.only(top: 6),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: <Widget>[
                  const ListTile(
                    leading: Icon(Icons.route_outlined, color: DekkColors.orange),
                    title: Text('Zones couvertes'),
                    subtitle: Text('Dakar · Rufisque · Diamniadio / AIBD · Petite Côte'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.delete_outline_rounded,
                      color: Colors.redAccent,
                    ),
                    title: const Text('Effacer les données locales'),
                    subtitle: const Text('Panier, favoris et historique sur cet appareil'),
                    onTap: () => _confirmEraseData(context),
                  ),
                  const Divider(height: 1),
                  const ListTile(
                    leading: Icon(Icons.info_outline_rounded, color: DekkColors.orange),
                    title: Text('DEKK FOOD - Sénégal'),
                    subtitle: Text('Version 3.0.0 · Guide & commande locale'),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(8, 16, 8, 0),
              child: Text(
                'Les favoris, préférences et commandes sont enregistrés localement sur cet appareil.',
                style: TextStyle(color: Colors.grey, fontSize: 12, height: 1.35),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsSectionTitle extends StatelessWidget {
  const _SettingsSectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 5),
      child: Text(
        text.toUpperCase(),
        style: const TextStyle(
          color: DekkColors.orange,
          fontSize: 12,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.7,
        ),
      ),
    );
  }
}
