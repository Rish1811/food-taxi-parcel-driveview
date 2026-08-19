import 'package:superapp_user/core/config/api_config.dart';
import 'package:superapp_user/modules/food/data/models/food_variant.dart';

class FoodModel {
  final String id;
  final String restaurantId;
  final String name;
  final String description;
  final double price;
  final double? originalPrice;
  final String imageUrl;
  final List<String> imageGallery;
  final double rating;
  final int reviewCount;
  final int calories;
  final String deliveryTime;
  final bool isVeg;
  final bool isSpicy;
  final bool isPopular;

  /// Size/portion choices. Empty when the item has a single price.
  final List<FoodVariant> variants;

  const FoodModel({
    required this.id,
    required this.restaurantId,
    required this.name,
    required this.description,
    required this.price,
    this.originalPrice,
    required this.imageUrl,
    this.imageGallery = const [],
    this.rating = 0.0,
    this.reviewCount = 0,
    this.calories = 0,
    this.deliveryTime = '',
    this.isVeg = false,
    this.isSpicy = false,
    this.isPopular = false,
    this.variants = const [],
  });

  /// "X% OFF" badge value, or null when there's no genuine [originalPrice] to
  /// compare against. Single source of truth so every badge agrees.
  int? get discountPercent {
    final original = originalPrice;
    if (original == null || original <= 0) return null;
    return (((1 - (price / original)) * 100).clamp(0, 99)).round();
  }

  /// Every image for the dish, primary first, as absolute URLs.
  ///
  /// Deduplicated because the backend keeps `image` as `images[0]`, so a naive
  /// merge of the two would repeat the primary and render a duplicate slide.
  static List<String> _galleryFrom(Map<String, dynamic> json) {
    final raw = <String?>[
      json['image'] as String?,
      ...((json['images'] as List<dynamic>?) ?? const [])
          .map((e) => e?.toString()),
    ];

    final seen = <String>{};
    final gallery = <String>[];
    for (final entry in raw) {
      if (entry == null || entry.trim().isEmpty) continue;
      final url = ApiConfig.resolveMedia(entry);
      if (url.isEmpty || !seen.add(url)) continue;
      gallery.add(url);
    }
    return gallery;
  }

  /// A compare-at price, or null when there is no genuine discount to show.
  ///
  /// The backend stores `otherPrice: 0` for dishes that were never given one,
  /// and 0 is not null — so it slipped through every `originalPrice != null`
  /// guard in the UI. The percent-off badges divide by it, and 1 - price/0 is
  /// Infinity, which `.toInt()` refuses: "Unsupported operation: Infinity or
  /// NaN toInt". That replaced the whole section with a red error box the
  /// moment a dish priced this way went live.
  ///
  /// Anything not strictly above the selling price is discarded here rather
  /// than at each call site, so the strikethrough and the badge can never
  /// disagree, and no future screen has to remember the rule.
  static double? _compareAtPrice(Object? raw, double price) {
    final value = (raw as num?)?.toDouble();
    if (value == null || !value.isFinite) return null;
    return value > price ? value : null;
  }

  /// Maps a backend food/menu item. Used by the cross-restaurant feed
  /// (`/public/foods`) and by each menu section's `items[]` — same shape.
  factory FoodModel.fromApi(Map<String, dynamic> json, {String? restaurantId}) {
    final price = (json['price'] as num?)?.toDouble() ?? 0.0;
    return FoodModel(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      restaurantId: (json['restaurantId'] ?? restaurantId ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      description: (json['description'] ?? '').toString(),
      price: price,
      originalPrice: _compareAtPrice(json['otherPrice'], price),
      imageUrl: ApiConfig.resolveMedia(json['image'] as String?),
      // The API sends `images` (primary first) for dishes with a gallery, and
      // only `image` for everything saved before galleries existed. Falling back
      // to the single image means the detail screen can always just read
      // imageGallery instead of special-casing the old shape.
      imageGallery: _galleryFrom(json),
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: (json['totalRatings'] as num?)?.toInt() ?? 0,
      calories: (json['calories'] as num?)?.toInt() ?? 0,
      deliveryTime: (json['preparationTime'] ?? json['prepTime'] ?? json['deliveryTime'] ?? '').toString(),
      isVeg: (json['foodType']?.toString().toLowerCase() ?? '') == 'veg',
      isPopular: json['isRecommended'] as bool? ?? false,
      variants: FoodVariant.listFrom(json),
    );
  }

  factory FoodModel.fromJson(Map<String, dynamic> json) {
    return FoodModel(
      id: json['id'] as String,
      restaurantId: json['restaurantId'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      // Same rule as fromApi: a cached model must not resurrect a zero or
      // below-price compare-at value that the network path would have dropped.
      originalPrice: _compareAtPrice(
        json['originalPrice'],
        (json['price'] as num).toDouble(),
      ),
      imageUrl: json['imageUrl'] as String,
      imageGallery: (json['imageGallery'] as List<dynamic>?)?.map((e) => e as String).toList() ?? [],
      rating: (json['rating'] as num?)?.toDouble() ?? 0.0,
      reviewCount: json['reviewCount'] as int? ?? 0,
      calories: json['calories'] as int? ?? 0,
      deliveryTime: json['deliveryTime'] as String? ?? '',
      isVeg: json['isVeg'] as bool? ?? false,
      isSpicy: json['isSpicy'] as bool? ?? false,
      isPopular: json['isPopular'] as bool? ?? false,
      variants: FoodVariant.listFrom(json),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'restaurantId': restaurantId,
      'name': name,
      'description': description,
      'price': price,
      'originalPrice': originalPrice,
      'imageUrl': imageUrl,
      'imageGallery': imageGallery,
      'rating': rating,
      'reviewCount': reviewCount,
      'calories': calories,
      'deliveryTime': deliveryTime,
      'isVeg': isVeg,
      'isSpicy': isSpicy,
      'isPopular': isPopular,
      'variants': variants.map((v) => v.toJson()).toList(),
    };
  }
}
