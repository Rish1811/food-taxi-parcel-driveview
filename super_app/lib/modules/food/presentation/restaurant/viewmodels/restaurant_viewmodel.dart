import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superapp_user/modules/food/data/models/food_model.dart';
import 'package:superapp_user/modules/food/data/models/restaurant_model.dart';
import 'package:superapp_user/modules/food/application/providers/restaurant_providers.dart';
import 'package:superapp_user/modules/food/data/services/restaurant_service.dart';
import 'package:superapp_user/modules/food/presentation/home/viewmodels/veg_filter_provider.dart';
import 'package:superapp_user/modules/food/presentation/restaurant/viewmodels/restaurant_state.dart';

final restaurantViewModelProvider =
    NotifierProvider<RestaurantViewModel, RestaurantState>(
        RestaurantViewModel.new);

class RestaurantViewModel extends Notifier<RestaurantState> {
  late final RestaurantService _service;
  Timer? _debounceTimer;

  @override
  RestaurantState build() {
    _service = ref.watch(restaurantServiceProvider);

    ref.listen<bool>(vegFilterProvider, (previous, next) {
      _updateFilteredList();
    });

    return const RestaurantState(isLoading: true);
  }

  Future<void> loadMenu(RestaurantModel restaurant, {bool isRefresh = false}) async {
    if (!isRefresh && state.allItems.isEmpty) {
      state = state.copyWith(restaurant: restaurant, isLoading: true);
    } else {
      state = state.copyWith(restaurant: restaurant);
    }

    try {
      final response = await _service.getMenu(restaurant.id);
      if (response.isSuccess && response.data != null) {
        final allItems = response.data!;
        final categories = _service.extractCategories(allItems);
        final filtered = _applyFilters(allItems, state);

        state = state.copyWith(
          allItems: allItems,
          filteredItems: filtered,
          categories: categories,
          isLoading: false,
        );
      } else {
        state = state.copyWith(
          isLoading: false,
          errorMessage: response.message ?? 'Failed to load restaurant menu.',
        );
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: e.toString(),
      );
    }
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 200), () {
      _updateFilteredList();
    });
  }

  void selectCategory(String categoryId) {
    state = state.copyWith(selectedCategoryId: categoryId);
    _updateFilteredList();
  }

  /// Groups the currently filtered items (search + veg/non-veg + rating
  /// applied, category untouched) into ordered category sections so the
  /// menu can render as jump-to-section blocks instead of a flat grid.
  Map<String, List<FoodModel>> groupFilteredByCategory() {
    return _service.groupByCategory(state.filteredItems, state.categories);
  }

  void toggleVegOnly() {
    final next = !state.isVegOnly;
    state = state.copyWith(
      isVegOnly: next,
      isNonVegOnly: next ? false : state.isNonVegOnly,
    );
    _updateFilteredList();
  }

  void toggleNonVegOnly() {
    final next = !state.isNonVegOnly;
    state = state.copyWith(
      isNonVegOnly: next,
      isVegOnly: next ? false : state.isVegOnly,
    );
    _updateFilteredList();
  }

  void toggleMinRating4() {
    state = state.copyWith(isMinRating4: !state.isMinRating4);
    _updateFilteredList();
  }

  void _updateFilteredList() {
    final filtered = _applyFilters(state.allItems, state);
    state = state.copyWith(filteredItems: filtered);
  }

  List<FoodModel> _applyFilters(List<FoodModel> items, RestaurantState currentState) {
    final isGlobalVegOnly = ref.read(vegFilterProvider);
    final effectiveVegOnly = isGlobalVegOnly || currentState.isVegOnly;
    return _service.filterMenu(
      items: items,
      query: currentState.searchQuery,
      categoryId: currentState.selectedCategoryId,
      isVegOnly: effectiveVegOnly,
      isNonVegOnly: effectiveVegOnly ? false : currentState.isNonVegOnly,
      isMinRating4: currentState.isMinRating4,
    );
  }
}
