import 'package:flutter/material.dart';

import '../models/restaurant.dart';
import '../theme.dart';
import '../widgets/dekk_ui.dart';
import 'cart_checkout_screens.dart';
import 'restaurant_detail_screen.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key, required this.restaurants});

  final List<Restaurant> restaurants;

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  static const List<String> _preferredZones = <String>[
    'Dakar',
    'Rufisque',
    'Diamniadio / AIBD',
    'Petite Côte',
  ];

  final TextEditingController _searchController = TextEditingController();
  late final List<String> _zones;
  late List<Restaurant> _visibleRestaurants;
  String _selectedZone = 'Tous';
  String _normalizedQuery = '';

  @override
  void initState() {
    super.initState();
    _zones = _buildZones();
    _visibleRestaurants = List<Restaurant>.from(widget.restaurants);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<String> _buildZones() {
    final availableZones = widget.restaurants
        .map((restaurant) => restaurant.address.zone)
        .where((zone) => zone.isNotEmpty)
        .toSet();
    final extraZones = availableZones
        .where((zone) => !_preferredZones.contains(zone))
        .toList()
      ..sort();

    return <String>[
      'Tous',
      ..._preferredZones.where(availableZones.contains),
      ...extraZones,
    ];
  }

  void _applyFilters() {
    final filtered = widget.restaurants.where((restaurant) {
      return restaurant.isInZone(_selectedZone) &&
          restaurant.matches(_normalizedQuery);
    }).toList(growable: false);

    setState(() => _visibleRestaurants = filtered);
  }

  void _onSearchChanged(String value) {
    _normalizedQuery = normalizeSearchText(value);
    _applyFilters();
  }

  void _clearSearch() {
    _searchController.clear();
    _onSearchChanged('');
  }

  @override
  Widget build(BuildContext context) {
    final resultLabel = _visibleRestaurants.length > 1
        ? '${_visibleRestaurants.length} restaurants'
        : '${_visibleRestaurants.length} restaurant';

    return Scaffold(
      appBar: AppBar(
        title: const Text('DEKK FOOD - Sénégal'),
        actions: <Widget>[
          CartAppBarButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const CartScreen()),
            ),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 14, 12, 8),
            child: TextField(
              controller: _searchController,
              onChanged: _onSearchChanged,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                hintText: 'Ville, quartier, restaurant ou spécialité…',
                prefixIcon: const Icon(Icons.search_rounded, color: DekkColors.orange),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Effacer la recherche',
                        onPressed: _clearSearch,
                        icon: const Icon(Icons.close_rounded),
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 43,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: _zones.length,
              separatorBuilder: (_, __) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final zone = _zones[index];
                final isSelected = zone == _selectedZone;
                return ChoiceChip(
                  label: Text(zone),
                  selected: isSelected,
                  selectedColor: DekkColors.orange,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : null,
                    fontWeight: FontWeight.w700,
                  ),
                  side: BorderSide(
                    color: isSelected
                        ? DekkColors.orange
                        : Theme.of(context).dividerColor,
                  ),
                  onSelected: (_) {
                    if (zone == _selectedZone) return;
                    _selectedZone = zone;
                    _applyFilters();
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 11, 16, 3),
            child: Row(
              children: <Widget>[
                Text(
                  resultLabel,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (_normalizedQuery.isNotEmpty) ...<Widget>[
                  const SizedBox(width: 6),
                  const Icon(Icons.restaurant_menu, size: 15, color: DekkColors.orange),
                  const SizedBox(width: 3),
                  Text(
                    'restaurants et spécialités',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: DekkColors.orange,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ],
              ],
            ),
          ),
          Expanded(
            child: _visibleRestaurants.isEmpty
                ? EmptyState(
                    icon: Icons.search_off_rounded,
                    title: 'Aucun restaurant trouvé',
                    description:
                        'Essayez un autre quartier, une autre ville ou le nom d’un plat.',
                    action: OutlinedButton.icon(
                      onPressed: () {
                        _selectedZone = 'Tous';
                        _clearSearch();
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Réinitialiser les filtres'),
                    ),
                  )
                : ListView.builder(
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.only(top: 3, bottom: 14),
                    itemCount: _visibleRestaurants.length,
                    itemBuilder: (context, index) {
                      final restaurant = _visibleRestaurants[index];
                      return RestaurantCard(
                        key: ValueKey<String>(restaurant.id),
                        restaurant: restaurant,
                        matchingSpecialty:
                            restaurant.matchingSpecialty(_normalizedQuery),
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => RestaurantDetailScreen(
                              restaurant: restaurant,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
