import 'package:superapp_user/core/network/api_response.dart';
import 'package:superapp_user/modules/food/data/models/food_model.dart';
import 'package:superapp_user/modules/food/data/models/restaurant_menu_category.dart';
import 'package:superapp_user/modules/food/data/contracts/restaurant_repository.dart';

/// Business domain service for restaurant menu processing, category extraction, and filtering.
class RestaurantService {
  final RestaurantRepository _repository;

  RestaurantService(this._repository);

  Future<ApiResponse<List<FoodModel>>> getMenu(String restaurantId) {
    return _repository.getRestaurantMenu(restaurantId);
  }

  /// Fixed display order for menu categories, mirrored between
  /// [extractCategories], [filterMenu] and [groupByCategory] so that chip
  /// order, filter results, and section order always stay in sync.
  static const List<MapEntry<String, String>> _categoryOrder = [
    MapEntry('all', 'All'),
    MapEntry('recommended', 'Recommended'),
    MapEntry('breakfast', 'Breakfast'),
    MapEntry('burger', 'Burgers'),
    MapEntry('pizza', 'Pizza'),
    MapEntry('biryani', 'Biryani'),
    MapEntry('sandwiches', 'Sandwiches & Subs'),
    MapEntry('sides', 'Sides & Snacks'),
    MapEntry('beverages', 'Beverages'),
    MapEntry('desserts', 'Desserts'),
    MapEntry('combos', 'Combos & Thali'),
    MapEntry('main_course', 'Main Course'),
  ];

  /// Resolves every category an item belongs to (an item may appear under
  /// more than one, e.g. a popular pizza is both "Recommended" and "Pizza").
  Set<String> _categoryIdsFor(FoodModel item) {
    final ids = <String>{};
    if (item.isPopular) ids.add('recommended');

    final name = item.name.toLowerCase();
    if (name.contains('pizza')) ids.add('pizza');
    if (name.contains('burger')) ids.add('burger');
    if (name.contains('biryani') || name.contains('rice')) ids.add('biryani');
    if (name.contains('dosa') ||
        name.contains('paratha') ||
        name.contains('khichdi') ||
        name.contains('idli') ||
        name.contains('upma')) {
      ids.add('breakfast');
    }
    if (name.contains('sandwich') || name.contains('sub')) {
      ids.add('sandwiches');
    }
    if (name.contains('fries') ||
        name.contains('bucket') ||
        name.contains('nugget') ||
        name.contains('wings')) {
      ids.add('sides');
    }
    if (name.contains('frappuccino') ||
        name.contains('shake') ||
        name.contains('coffee') ||
        name.contains('drink') ||
        name.contains('juice') ||
        name.contains('soda')) {
      ids.add('beverages');
    }
    if (name.contains('muffin') ||
        name.contains('cake') ||
        name.contains('brownie') ||
        name.contains('ice cream') ||
        name.contains('dessert')) {
      ids.add('desserts');
    }
    if (name.contains('roti') || name.contains('thali') || name.contains('combo')) {
      ids.add('combos');
    }

    if (ids.isEmpty) ids.add('main_course');
    return ids;
  }

  /// Dynamically extract categories from menu items.
  List<RestaurantMenuCategory> extractCategories(List<FoodModel> items) {
    if (items.isEmpty) return const [];

    final seenIds = <String>{};
    final seenNames = <String>{};
    final result = <RestaurantMenuCategory>[];

    for (final entry in _categoryOrder) {
      final id = entry.key;
      final name = entry.value;
      final nameKey = name.trim().toLowerCase();

      if (seenIds.contains(id) || seenNames.contains(nameKey)) continue;

      final count = id == 'all'
          ? items.length
          : items.where((f) => _categoryIdsFor(f).contains(id)).length;

      if (count > 0) {
        seenIds.add(id);
        seenNames.add(nameKey);
        result.add(RestaurantMenuCategory(id: id, name: name, itemCount: count));
      }
    }
    return result;
  }

  /// Groups items by category id, preserving [_categoryOrder]. Used to
  /// render the menu as jump-to sections instead of a single filtered grid.
  Map<String, List<FoodModel>> groupByCategory(
    List<FoodModel> items,
    List<RestaurantMenuCategory> categories,
  ) {
    final map = <String, List<FoodModel>>{};
    for (final cat in categories) {
      if (cat.id == 'all') continue;
      final matched = items.where((f) => _categoryIdsFor(f).contains(cat.id)).toList();
      if (matched.isNotEmpty) map[cat.id] = matched;
    }
    return map;
  }

  /// Filters food items based on query, selected category, veg/non-veg toggles, and rating.
  List<FoodModel> filterMenu({
    required List<FoodModel> items,
    required String query,
    required String categoryId,
    required bool isVegOnly,
    required bool isNonVegOnly,
    required bool isMinRating4,
  }) {
    var result = List<FoodModel>.from(items);

    // 1. Text Search Filter
    final cleanQuery = query.trim().toLowerCase();
    if (cleanQuery.isNotEmpty) {
      result = result.where((f) {
        final matchesName = f.name.toLowerCase().contains(cleanQuery);
        final matchesDesc = f.description.toLowerCase().contains(cleanQuery);
        return matchesName || matchesDesc;
      }).toList();
    }

    // 2. Category Filter
    if (categoryId != 'all') {
      result = result.where((f) => _categoryIdsFor(f).contains(categoryId)).toList();
    }

    // 3. Veg / Non-Veg Toggle
    if (isVegOnly) {
      result = result.where((f) => f.isVeg).toList();
    } else if (isNonVegOnly) {
      result = result.where((f) => !f.isVeg).toList();
    }

    // 4. Rating Filter
    if (isMinRating4) {
      result = result.where((f) => f.rating >= 4.0).toList();
    }

    return result;
  }
}
