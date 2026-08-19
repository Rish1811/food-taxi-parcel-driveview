import 'package:superapp_user/modules/food/data/models/store99_brand.dart';
import 'package:superapp_user/modules/food/data/models/store99_cuisine.dart';
import 'package:superapp_user/modules/food/data/models/store99_product.dart';

/// Immutable presentation state for the 99 Store screen.
class Store99State {
  final List<Store99Cuisine> cuisines;
  final List<Store99Brand> brands;
  final List<Store99Product> trendingDishes;
  final List<Store99Product> exploreDishes;
  final String selectedCuisineId;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasMore;
  final int page;
  final String? errorMessage;

  const Store99State({
    this.cuisines = const [],
    this.brands = const [],
    this.trendingDishes = const [],
    this.exploreDishes = const [],
    this.selectedCuisineId = 'all',
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasMore = true,
    this.page = 1,
    this.errorMessage,
  });

  Store99State copyWith({
    List<Store99Cuisine>? cuisines,
    List<Store99Brand>? brands,
    List<Store99Product>? trendingDishes,
    List<Store99Product>? exploreDishes,
    String? selectedCuisineId,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasMore,
    int? page,
    String? errorMessage,
  }) {
    return Store99State(
      cuisines: cuisines ?? this.cuisines,
      brands: brands ?? this.brands,
      trendingDishes: trendingDishes ?? this.trendingDishes,
      exploreDishes: exploreDishes ?? this.exploreDishes,
      selectedCuisineId: selectedCuisineId ?? this.selectedCuisineId,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasMore: hasMore ?? this.hasMore,
      page: page ?? this.page,
      errorMessage: errorMessage,
    );
  }
}
