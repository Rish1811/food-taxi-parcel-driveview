import 'package:superapp_user/modules/food/data/models/store99_product.dart';

/// Data Transfer Object for 99 Store product items.
class Store99ProductDto {
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

  const Store99ProductDto({
    required this.id,
    required this.restaurantId,
    required this.restaurantName,
    required this.name,
    required this.description,
    required this.price,
    this.originalPrice,
    required this.imageUrl,
    required this.rating,
    required this.ratingCount,
    required this.deliveryTime,
    required this.isVeg,
    required this.cuisineId,
  });

  factory Store99ProductDto.fromJson(Map<String, dynamic> json) {
    return Store99ProductDto(
      id: json['id'] as String,
      restaurantId: json['restaurantId'] as String,
      restaurantName: json['restaurantName'] as String,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      price: (json['price'] as num).toDouble(),
      originalPrice: json['originalPrice'] != null ? (json['originalPrice'] as num).toDouble() : null,
      imageUrl: json['imageUrl'] as String,
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      ratingCount: json['ratingCount'] as int? ?? 0,
      deliveryTime: json['deliveryTime'] as String? ?? '',
      isVeg: json['isVeg'] as bool? ?? false,
      cuisineId: json['cuisineId'] as String? ?? 'all',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'name': name,
      'description': description,
      'price': price,
      'originalPrice': originalPrice,
      'imageUrl': imageUrl,
      'rating': rating,
      'ratingCount': ratingCount,
      'deliveryTime': deliveryTime,
      'isVeg': isVeg,
      'cuisineId': cuisineId,
    };
  }

  Store99Product toDomain() {
    return Store99Product(
      id: id,
      restaurantId: restaurantId,
      restaurantName: restaurantName,
      name: name,
      description: description,
      price: price,
      originalPrice: originalPrice,
      imageUrl: imageUrl,
      rating: rating,
      ratingCount: ratingCount,
      deliveryTime: deliveryTime,
      isVeg: isVeg,
      cuisineId: cuisineId,
    );
  }
}
