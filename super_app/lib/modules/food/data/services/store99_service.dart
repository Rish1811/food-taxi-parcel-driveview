import 'package:superapp_user/core/network/api_response.dart';
import 'package:superapp_user/modules/food/data/models/restaurant_model.dart';
import 'package:superapp_user/modules/food/data/models/store99_brand.dart';
import 'package:superapp_user/modules/food/data/models/store99_cuisine.dart';
import 'package:superapp_user/modules/food/data/models/store99_product.dart';
import 'package:superapp_user/modules/food/data/contracts/store99_repository.dart';

/// Business domain service for 99 Store rules, filtering, and data orchestration.
class Store99Service {
  final Store99Repository _repository;

  Store99Service(this._repository);

  Future<ApiResponse<List<Store99Cuisine>>> getCuisines() {
    return _repository.getCuisines();
  }

  Future<ApiResponse<List<Store99Brand>>> getBrands() {
    return _repository.getBrands();
  }

  Future<ApiResponse<List<Store99Product>>> getTrendingDishes() async {
    final response = await _repository.getTrendingDishes();
    if (response.isSuccess && response.data != null) {
      final eligible = response.data!.where((p) => p.price <= 99.0).toList();
      return ApiResponse.success(eligible);
    }
    return response;
  }

  Future<ApiResponse<List<Store99Product>>> fetchProductsPage({
    String cuisineId = 'all',
    int page = 1,
    int limit = 10,
  }) async {
    final response = await _repository.getExploreProducts(
      cuisineId: cuisineId,
      page: page,
      limit: limit,
    );

    if (response.isSuccess && response.data != null) {
      // Enforce business rule: keep only products with selling price <= 99
      final products =
          response.data!.where((p) => p.price <= 99.0).toList();
      return ApiResponse.success(products);
    }

    return response;
  }

  Future<RestaurantModel?> findRestaurant(String restaurantId) async {
    final response = await _repository.getRestaurantForProduct(restaurantId);
    return response.data;
  }
}
