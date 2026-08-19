import 'package:superapp_user/core/network/api_response.dart';
import 'package:superapp_user/modules/food/data/models/restaurant_model.dart';
import 'package:superapp_user/modules/food/data/models/category_model.dart';
import 'package:superapp_user/modules/food/data/models/food_model.dart';

abstract class RestaurantRepository {
  /// [onCache], where supported, fires synchronously with a cached copy (if
  /// any) before the network call resolves — lets a caller paint instantly
  /// and then replace with the live result.
  Future<ApiResponse<List<CategoryModel>>> getCategories({void Function(List<CategoryModel>)? onCache});
  Future<ApiResponse<List<RestaurantModel>>> getFeaturedRestaurants();
  Future<ApiResponse<List<RestaurantModel>>> getPopularRestaurants({void Function(List<RestaurantModel>)? onCache});
  Future<ApiResponse<List<FoodModel>>> getRestaurantMenu(String restaurantId);
  Future<ApiResponse<List<FoodModel>>> getPopularFoods({void Function(List<FoodModel>)? onCache});
  Future<ApiResponse<List<FoodModel>>> getBestOffers({void Function(List<FoodModel>)? onCache});
}
