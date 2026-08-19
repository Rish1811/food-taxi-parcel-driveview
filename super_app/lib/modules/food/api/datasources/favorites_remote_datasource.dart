import 'dart:developer' as developer;
import 'package:superapp_user/core/config/api_config.dart';
import 'package:superapp_user/core/network/api_client.dart';
import 'package:superapp_user/modules/food/data/models/food_model.dart';
import 'package:superapp_user/modules/food/data/models/restaurant_model.dart';

class FavoritesResponse {
  final Set<String> restaurantIds;
  final Set<String> foodIds;
  final List<RestaurantModel> restaurants;
  final List<FoodModel> foods;

  const FavoritesResponse({
    this.restaurantIds = const {},
    this.foodIds = const {},
    this.restaurants = const [],
    this.foods = const [],
  });
}

/// Remote transport for favorites operations under `/food/user/favorites`.
class FavoritesRemoteDataSource {
  final ApiClient _client;

  const FavoritesRemoteDataSource(this._client);

  Future<FavoritesResponse> getFavorites() async {
    final endpoint = ApiPaths.favorites;
    developer.log(
      '[FAVORITE] [API Request] GET $endpoint',
      name: 'FAVORITE',
    );

    try {
      final res = await _client.get<dynamic>(endpoint);
      developer.log(
        '[FAVORITE] [API Response Status 200] GET $endpoint | Raw Body: $res',
        name: 'FAVORITE',
      );

      Map<String, dynamic> data = {};
      if (res is Map<String, dynamic>) {
        data = res;
      } else if (res is Map) {
        data = res.cast<String, dynamic>();
      }

      final rawRIds = ((data['restaurantIds'] as List?) ??
          (data['favorites']?['restaurantIds'] as List?) ??
          const []);
      final rawFIds = ((data['foodIds'] as List?) ??
          (data['favoriteFoodIds'] as List?) ??
          (data['favorites']?['foodIds'] as List?) ??
          const []);

      final rListRaw = ((data['restaurants'] as List?) ??
          (data['favoriteRestaurants'] as List?) ??
          const []);
      final fListRaw = ((data['foods'] as List?) ??
          (data['favoriteFoods'] as List?) ??
          const []);

      final rList = rListRaw
          .whereType<Map>()
          .map((e) => RestaurantModel.fromApi(e.cast<String, dynamic>()))
          .toList();

      final fList = fListRaw
          .whereType<Map>()
          .map((e) => FoodModel.fromApi(e.cast<String, dynamic>()))
          .toList();

      final rIds = {
        ...rawRIds.map((e) => e.toString()),
        ...rList.map((r) => r.id),
      };

      final fIds = {
        ...rawFIds.map((e) => e.toString()),
        ...fList.map((f) => f.id),
      };

      final response = FavoritesResponse(
        restaurantIds: rIds,
        foodIds: fIds,
        restaurants: rList,
        foods: fList,
      );

      developer.log(
        '[FAVORITE] [Parsed Model] Restaurant IDs (${response.restaurantIds.length}): ${response.restaurantIds} | Food IDs (${response.foodIds.length}): ${response.foodIds}',
        name: 'FAVORITE',
      );

      return response;
    } catch (e, stack) {
      developer.log(
        '[FAVORITE] [API Error] GET $endpoint Exception: $e\n$stack',
        name: 'FAVORITE',
      );
      // Must throw, not return an empty response. An empty response is
      // indistinguishable from "this user has no favourites", so the caller
      // wrote those empty lists over the cached ids and pushed an empty state
      // into the UI — one failed refresh (expired token, flaky network) and
      // every saved favourite disappeared from the app.
      rethrow;
    }
  }

  Future<bool> toggleFavoriteRestaurant(
      String restaurantId, bool isFavorite) async {
    final endpoint = '${ApiPaths.favoriteRestaurants}/$restaurantId';
    final action = isFavorite ? 'POST' : 'DELETE';
    developer.log(
      '[FAVORITE] [API Request] Entity: Restaurant | ID: $restaurantId | Action: $action | Endpoint: $endpoint',
      name: 'FAVORITE',
    );

    try {
      final dynamic res;
      if (isFavorite) {
        res = await _client.post<dynamic>(endpoint);
      } else {
        res = await _client.delete<dynamic>(endpoint);
      }
      developer.log(
        '[FAVORITE] [API Response Status 200] $action $endpoint | Body: $res',
        name: 'FAVORITE',
      );
      return true;
    } catch (e, stack) {
      developer.log(
        '[FAVORITE] [API Error] $action $endpoint Exception: $e\n$stack',
        name: 'FAVORITE',
      );
      rethrow;
    }
  }

  Future<bool> toggleFavoriteFood(String foodId, bool isFavorite) async {
    final endpoint = '${ApiPaths.favoriteFoods}/$foodId';
    final action = isFavorite ? 'POST' : 'DELETE';
    developer.log(
      '[FAVORITE] [API Request] Entity: Food/Product | ID: $foodId | Action: $action | Endpoint: $endpoint',
      name: 'FAVORITE',
    );

    try {
      final dynamic res;
      if (isFavorite) {
        res = await _client.post<dynamic>(endpoint);
      } else {
        res = await _client.delete<dynamic>(endpoint);
      }
      developer.log(
        '[FAVORITE] [API Response Status 200] $action $endpoint | Body: $res',
        name: 'FAVORITE',
      );
      return true;
    } catch (e, stack) {
      developer.log(
        '[FAVORITE] [API Error] $action $endpoint Exception: $e\n$stack',
        name: 'FAVORITE',
      );
      rethrow;
    }
  }
}
