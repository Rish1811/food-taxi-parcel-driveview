import 'package:superapp_user/core/network/api_response.dart';
import 'package:superapp_user/modules/food/data/models/restaurant_model.dart';
import 'package:superapp_user/modules/food/data/models/store99_brand.dart';
import 'package:superapp_user/modules/food/data/models/store99_cuisine.dart';
import 'package:superapp_user/modules/food/data/models/store99_product.dart';

/// Repository interface for 99 Store operations following Clean Architecture.
abstract class Store99Repository {
  Future<ApiResponse<List<Store99Cuisine>>> getCuisines();
  Future<ApiResponse<List<Store99Brand>>> getBrands();
  Future<ApiResponse<List<Store99Product>>> getTrendingDishes();
  Future<ApiResponse<List<Store99Product>>> getExploreProducts({
    String cuisineId = 'all',
    int page = 1,
    int limit = 10,
  });
  Future<ApiResponse<RestaurantModel?>> getRestaurantForProduct(String restaurantId);
}
