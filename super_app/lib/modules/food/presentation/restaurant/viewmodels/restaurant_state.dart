import 'package:superapp_user/modules/food/data/models/food_model.dart';
import 'package:superapp_user/modules/food/data/models/restaurant_model.dart';
import 'package:superapp_user/modules/food/data/models/restaurant_menu_category.dart';

/// Immutable presentation state for the Restaurant Details screen.
class RestaurantState {
  final RestaurantModel? restaurant;
  final List<FoodModel> allItems;
  final List<FoodModel> filteredItems;
  final List<RestaurantMenuCategory> categories;
  final String selectedCategoryId;
  final String searchQuery;
  final bool isVegOnly;
  final bool isNonVegOnly;
  final bool isMinRating4;
  final bool isLoading;
  final String? errorMessage;

  const RestaurantState({
    this.restaurant,
    this.allItems = const [],
    this.filteredItems = const [],
    this.categories = const [],
    this.selectedCategoryId = 'all',
    this.searchQuery = '',
    this.isVegOnly = false,
    this.isNonVegOnly = false,
    this.isMinRating4 = false,
    this.isLoading = false,
    this.errorMessage,
  });

  RestaurantState copyWith({
    RestaurantModel? restaurant,
    List<FoodModel>? allItems,
    List<FoodModel>? filteredItems,
    List<RestaurantMenuCategory>? categories,
    String? selectedCategoryId,
    String? searchQuery,
    bool? isVegOnly,
    bool? isNonVegOnly,
    bool? isMinRating4,
    bool? isLoading,
    String? errorMessage,
  }) {
    return RestaurantState(
      restaurant: restaurant ?? this.restaurant,
      allItems: allItems ?? this.allItems,
      filteredItems: filteredItems ?? this.filteredItems,
      categories: categories ?? this.categories,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      searchQuery: searchQuery ?? this.searchQuery,
      isVegOnly: isVegOnly ?? this.isVegOnly,
      isNonVegOnly: isNonVegOnly ?? this.isNonVegOnly,
      isMinRating4: isMinRating4 ?? this.isMinRating4,
      isLoading: isLoading ?? this.isLoading,
      errorMessage: errorMessage,
    );
  }
}
