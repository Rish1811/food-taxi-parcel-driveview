import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superapp_user/modules/food/data/models/food_model.dart';
import 'package:superapp_user/modules/food/data/models/restaurant_model.dart';
import 'package:superapp_user/modules/food/application/providers/favorites_providers.dart';
import 'package:superapp_user/modules/food/data/contracts/favorites_repository.dart';

class FavoritesState {
  final Set<String> restaurantIds;
  final Set<String> foodIds;
  final List<RestaurantModel> restaurants;
  final List<FoodModel> foods;

  const FavoritesState({
    this.restaurantIds = const {},
    this.foodIds = const {},
    this.restaurants = const [],
    this.foods = const [],
  });

  FavoritesState copyWith({
    Set<String>? restaurantIds,
    Set<String>? foodIds,
    List<RestaurantModel>? restaurants,
    List<FoodModel>? foods,
  }) {
    return FavoritesState(
      restaurantIds: restaurantIds ?? this.restaurantIds,
      foodIds: foodIds ?? this.foodIds,
      restaurants: restaurants ?? this.restaurants,
      foods: foods ?? this.foods,
    );
  }

  @override
  String toString() =>
      'FavoritesState(restaurantIds: ${restaurantIds.length}, foodIds: ${foodIds.length})';
}

final favoritesViewModelProvider =
    AsyncNotifierProvider<FavoritesViewModel, FavoritesState>(
        FavoritesViewModel.new);

final favoriteFoodIdsProvider = Provider<Set<String>>((ref) {
  return ref.watch(favoritesViewModelProvider).value?.foodIds ?? const {};
});

class FavoritesViewModel extends AsyncNotifier<FavoritesState> {
  late final FavoritesRepository _repository;
  final Set<String> _pendingToggles = {};

  @override
  Future<FavoritesState> build() async {
    _repository = ref.watch(favoritesRepositoryProvider);

    final localR = await _repository.getFavoriteIds();
    final localF = await _repository.getFavoriteFoodIds();
    final initialState = FavoritesState(restaurantIds: localR, foodIds: localF);

    developer.log(
      '[FAVORITE] [Initial State Built] Restaurant Count: ${initialState.restaurantIds.length} | Food Count: ${initialState.foodIds.length}',
      name: 'FAVORITE',
    );

    // Trigger backend sync in background
    _syncWithBackend();

    return initialState;
  }

  Future<void> _syncWithBackend() async {
    try {
      developer.log('[FAVORITE] [Backend Sync Started]', name: 'FAVORITE');
      final remoteRes = await _repository.getRemoteFavorites();
      final current = state.value ?? const FavoritesState();

      if (remoteRes != null) {
        final updatedState = current.copyWith(
          restaurantIds: remoteRes.restaurantIds,
          foodIds: remoteRes.foodIds,
          restaurants: remoteRes.restaurants,
          foods: remoteRes.foods,
        );
        state = AsyncData(updatedState);
        developer.log(
          '[FAVORITE] [Backend Sync Success & State Updated] State: $updatedState',
          name: 'FAVORITE',
        );
      }
    } catch (e, stack) {
      developer.log('[FAVORITE] [Backend Sync Failed] Exception: $e\n$stack', name: 'FAVORITE');
    }
  }

  bool isRestaurantFavorite(String restaurantId) {
    return state.value?.restaurantIds.contains(restaurantId) ?? false;
  }

  bool isFoodFavorite(String foodId) {
    return state.value?.foodIds.contains(foodId) ?? false;
  }

  /// Toggles favorite status for a restaurant with optimistic update,
  /// rapid-tap prevention, backend sync, and graceful error revert.
  Future<void> toggle(String restaurantId, [RestaurantModel? restaurant]) async {
    final key = 'r_$restaurantId';
    developer.log(
      '[FAVORITE] [Tap Detected] Entity Type: Restaurant | Entity ID: $restaurantId',
      name: 'FAVORITE',
    );

    if (_pendingToggles.contains(key)) {
      developer.log(
        '[FAVORITE] [Duplicate Tap Blocked] Request already in-flight for Restaurant ID: $restaurantId',
        name: 'FAVORITE',
      );
      return;
    }
    _pendingToggles.add(key);

    final current = state.value ?? const FavoritesState();
    final currentR = Set<String>.from(current.restaurantIds);
    final isCurrentlyFav = currentR.contains(restaurantId);
    final isAdding = !isCurrentlyFav;

    developer.log(
      '[FAVORITE] [State Before Update] Restaurant ID: $restaurantId | Is Favorite: $isCurrentlyFav | Next Action: ${isAdding ? "ADD" : "REMOVE"}',
      name: 'FAVORITE',
    );

    final updatedRList = List<RestaurantModel>.from(current.restaurants);
    if (isAdding) {
      currentR.add(restaurantId);
      if (restaurant != null && !updatedRList.any((r) => r.id == restaurantId)) {
        updatedRList.add(restaurant);
      }
    } else {
      currentR.remove(restaurantId);
      updatedRList.removeWhere((r) => r.id == restaurantId);
    }

    // 1. Optimistic UI update immediately with updated IDs and model list
    final nextState = current.copyWith(
      restaurantIds: currentR,
      restaurants: updatedRList,
    );
    state = AsyncData(nextState);

    developer.log(
      '[FAVORITE] [State After Update / UI Rebuild Triggered] Restaurant ID: $restaurantId | New State: ${currentR.contains(restaurantId)}',
      name: 'FAVORITE',
    );

    // 2. Persist locally and sync with backend
    try {
      await _repository.toggleFavoriteRestaurant(restaurantId, isAdding);
      developer.log(
        '[FAVORITE] [Persist & API Success] Restaurant ID: $restaurantId',
        name: 'FAVORITE',
      );
    } catch (e) {
      // 3. Revert on failure
      developer.log(
        '[FAVORITE] [API Failed - Reverting State] Restaurant ID: $restaurantId | Error: $e',
        name: 'FAVORITE',
      );
      state = AsyncData(current);
    } finally {
      _pendingToggles.remove(key);
    }
  }

  /// Toggles favorite status for a food item with optimistic update,
  /// rapid-tap prevention, backend sync, and graceful error revert.
  Future<void> toggleFood(String foodId, [FoodModel? food]) async {
    final key = 'f_$foodId';
    developer.log(
      '[FAVORITE] [Tap Detected] Entity Type: Food/Dish | Entity ID: $foodId',
      name: 'FAVORITE',
    );

    if (_pendingToggles.contains(key)) {
      developer.log(
        '[FAVORITE] [Duplicate Tap Blocked] Request already in-flight for Food ID: $foodId',
        name: 'FAVORITE',
      );
      return;
    }
    _pendingToggles.add(key);

    final current = state.value ?? const FavoritesState();
    final currentF = Set<String>.from(current.foodIds);
    final isCurrentlyFav = currentF.contains(foodId);
    final isAdding = !isCurrentlyFav;

    developer.log(
      '[FAVORITE] [State Before Update] Food ID: $foodId | Is Favorite: $isCurrentlyFav | Next Action: ${isAdding ? "ADD" : "REMOVE"}',
      name: 'FAVORITE',
    );

    final updatedFList = List<FoodModel>.from(current.foods);
    if (isAdding) {
      currentF.add(foodId);
      if (food != null && !updatedFList.any((f) => f.id == foodId)) {
        updatedFList.add(food);
      }
    } else {
      currentF.remove(foodId);
      updatedFList.removeWhere((f) => f.id == foodId);
    }

    // 1. Optimistic UI update immediately with updated IDs and model list
    final nextState = current.copyWith(
      foodIds: currentF,
      foods: updatedFList,
    );
    state = AsyncData(nextState);

    developer.log(
      '[FAVORITE] [State After Update / UI Rebuild Triggered] Food ID: $foodId | New State: ${currentF.contains(foodId)}',
      name: 'FAVORITE',
    );

    // 2. Persist locally and sync with backend
    try {
      await _repository.toggleFavoriteFood(foodId, isAdding);
      developer.log(
        '[FAVORITE] [Persist & API Success] Food ID: $foodId',
        name: 'FAVORITE',
      );
    } catch (e) {
      // 3. Revert on failure
      developer.log(
        '[FAVORITE] [API Failed - Reverting State] Food ID: $foodId | Error: $e',
        name: 'FAVORITE',
      );
      state = AsyncData(current);
    } finally {
      _pendingToggles.remove(key);
    }
  }
}
