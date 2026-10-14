import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/restaurant.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // Schéma historique observé : restaurants.id est integer et ne comporte
  // pas de colonne is_active. La publication publique dépend des policies RLS.
  Future<List<Restaurant>> getRestaurants({String? neighborhoodQuery}) async {
    var query = _client.from('restaurants').select();

    if (neighborhoodQuery != null && neighborhoodQuery.isNotEmpty) {
      query = query.ilike('neighborhood', '%$neighborhoodQuery%');
    }

    final response = await query;
    return (response as List)
        .map((json) => Restaurant.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }

  // Schéma historique : restaurant_menus (id integer, restaurant_id integer,
  // name, price, category, is_available). Pas de table menu_items.
  Future<List<MenuItem>> getMenuItems(String restaurantId) async {
    final numericRestaurantId = int.tryParse(restaurantId);
    if (numericRestaurantId == null) {
      return [];
    }

    final response = await _client
        .from('restaurant_menus')
        .select()
        .eq('restaurant_id', numericRestaurantId)
        .eq('is_available', true);

    return (response as List)
        .map((json) => MenuItem.fromJson(Map<String, dynamic>.from(json)))
        .toList();
  }
}
