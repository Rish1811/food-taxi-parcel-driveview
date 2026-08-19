import 'package:superapp_user/modules/food/data/models/food_model.dart';
import 'package:superapp_user/modules/food/data/models/restaurant_model.dart';

/// Domain entity representing a 99 Store product item.
/// 
/// Contains business properties for discounted 99 Store deals, cuisine linkage,
/// and helper for cart model conversion without violating layer boundaries.
class Store99Product {
  final String id;
  final String restaurantId;
  final String restaurantName;
  final String name;
  final String description;
  final double price;
  final double? originalPrice;
  final String imageUrl;
  final double rating;
  final int ratingCount;
  final String deliveryTime;
  final bool isVeg;
  final String cuisineId;
  final RestaurantModel? restaurant;

  const Store99Product({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.name,
    required this.description,
    required this.price,
    this.originalPrice,
    required this.imageUrl,
    this.rating = 0.0,
    this.ratingCount = 0,
    this.deliveryTime = '',
    this.isVeg = false,
    this.cuisineId = 'all',
    this.restaurant,
  });

  /// Converts this 99 Store product into a [FoodModel] for cart operations.
  FoodModel toFoodModel() {
    return FoodModel(
      id: id,
      restaurantId: restaurantId,
      name: name,
      description: description,
      price: price,
      originalPrice: originalPrice,
      imageUrl: imageUrl,
      rating: rating,
      reviewCount: ratingCount,
      deliveryTime: deliveryTime,
      isVeg: isVeg,
      isPopular: true,
    );
  }

  Store99Product copyWith({
    String? id,
    String? restaurantId,
    String? restaurantName,
    String? name,
    String? description,
    double? price,
    double? originalPrice,
    String? imageUrl,
    double? rating,
    int? ratingCount,
    String? deliveryTime,
    bool? isVeg,
    String? cuisineId,
    RestaurantModel? restaurant,
  }) {
    return Store99Product(
      id: id ?? this.id,
      restaurantId: restaurantId ?? this.restaurantId,
      restaurantName: restaurantName ?? this.restaurantName,
      name: name ?? this.name,
      description: description ?? this.description,
      price: price ?? this.price,
      originalPrice: originalPrice ?? this.originalPrice,
      imageUrl: imageUrl ?? this.imageUrl,
      rating: rating ?? this.rating,
      ratingCount: ratingCount ?? this.ratingCount,
      deliveryTime: deliveryTime ?? this.deliveryTime,
      isVeg: isVeg ?? this.isVeg,
      cuisineId: cuisineId ?? this.cuisineId,
      restaurant: restaurant ?? this.restaurant,
    );
  }
}
