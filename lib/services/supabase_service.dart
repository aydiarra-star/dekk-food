import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/restaurant.dart';

/// Adaptateur Supabase prêt à remplacer le catalogue local lorsque les clés et
/// les données de production sont configurées. Les widgets ne dépendent que de
/// [Restaurant] et [MenuItem], pas du format SQL.
class SupabaseService {
  SupabaseService({SupabaseClient? client})
      : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  /// Récupère des restaurants actifs avec leurs menus si nécessaire pour la
  /// recherche de spécialités. Les filtres zone/quartier sont appliqués côté
  /// serveur et les modèles restent immuables côté Flutter.
  Future<List<Restaurant>> getRestaurants({
    String? zone,
    String? neighborhoodQuery,
    bool includeMenu = true,
  }) async {
    dynamic query = _client
        .from('restaurants')
        .select(includeMenu ? '*, menu_items(*)' : '*')
        .eq('is_active', true);

    final normalizedZone = zone?.trim();
    if (normalizedZone != null &&
        normalizedZone.isNotEmpty &&
        normalizedZone != 'Tous') {
      query = query.eq('zone', normalizedZone);
    }

    final normalizedNeighborhood = neighborhoodQuery?.trim();
    if (normalizedNeighborhood != null && normalizedNeighborhood.isNotEmpty) {
      query = query.ilike('neighborhood', '%$normalizedNeighborhood%');
    }

    final response = await query.order('name');
    return List<Restaurant>.unmodifiable(
      (response as List)
          .whereType<Map>()
          .map((row) => Restaurant.fromJson(Map<String, dynamic>.from(row))),
    );
  }

  Future<List<MenuItem>> getMenuItems(String restaurantId) async {
    final response = await _client
        .from('menu_items')
        .select()
        .eq('restaurant_id', restaurantId)
        .eq('is_available', true)
        .order('display_order')
        .order('title');

    return List<MenuItem>.unmodifiable(
      (response as List)
          .whereType<Map>()
          .map((row) => MenuItem.fromJson(Map<String, dynamic>.from(row))),
    );
  }
}
