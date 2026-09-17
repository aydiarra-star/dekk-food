import 'package:flutter/material.dart';

import 'app_scope.dart';
import 'models/restaurant.dart';
import 'screens/favorites_screen.dart';
import 'screens/orders_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/discovery_screen.dart';

/// Navigation persistante : les onglets restent montés dans un [IndexedStack]
/// pour conserver une recherche, des filtres et une position de défilement lors
/// du passage vers les favoris ou les commandes.
class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key, required this.restaurants});

  final List<Restaurant> restaurants;

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();
    _screens = <Widget>[
      DiscoveryScreen(restaurants: widget.restaurants),
      OrdersScreen(onDiscover: () => _selectTab(0)),
      FavoritesScreen(
        restaurants: widget.restaurants,
        onDiscover: () => _selectTab(0),
      ),
      const SettingsScreen(),
    ];
  }

  void _selectTab(int index) => AppScope.of(context).navigation.select(index);

  @override
  Widget build(BuildContext context) {
    final navigation = AppScope.of(context).navigation;
    return AnimatedBuilder(
      animation: navigation,
      builder: (context, _) => Scaffold(
        body: IndexedStack(
          index: navigation.currentIndex,
          children: _screens,
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: navigation.currentIndex,
          onDestinationSelected: _selectTab,
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.explore_outlined),
              selectedIcon: Icon(Icons.explore_rounded),
              label: 'Découvrir',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded),
              label: 'Commandes',
            ),
            NavigationDestination(
              icon: Icon(Icons.favorite_border_rounded),
              selectedIcon: Icon(Icons.favorite_rounded),
              label: 'Favoris',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded),
              label: 'Paramètres',
            ),
          ],
        ),
      ),
    );
  }
}
