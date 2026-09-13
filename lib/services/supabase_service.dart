import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/restaurant.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // Récupérer la liste des restaurants (avec filtre optionnel par quartier)
  Future<List<Restaurant>> getRestaurants({String? neighborhoodQuery}) async {
    var query = _client.from('restaurants').select().eq('is_active', true);

    if (neighborhoodQuery != null && neighborhoodQuery.isNotEmpty) {
      query = query.ilike('neighborhood', '%$neighborhoodQuery%');
    }

    final response = await query;
    return (response as List).map((json) => Restaurant.fromJson(json)).toList();
  }

  // Récupérer le menu d'un restaurant
  Future<List<MenuItem>> getMenuItems(String restaurantId) async {
    final response = await _client
        .from('menu_items')
        .select()
        .eq('restaurant_id', restaurantId)
        .eq('is_available', true);

    return (response as List).map((json) => MenuItem.fromJson(json)).toList();
  }
}
