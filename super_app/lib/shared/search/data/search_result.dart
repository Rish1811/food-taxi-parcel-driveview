enum SearchResultType {
  restaurant,
  food,
  category,
  brand,
  store99,
}

/// Unified domain entity representing a search result item across Home & 99 Store.
class SearchResult {
  final String id;
  final String title;
  final String subtitle;
  final String imageUrl;
  final SearchResultType type;
  final double? price;
  final double? originalPrice;
  final double? rating;
  final int? reviewCount;
  final bool? isVeg;
  final String? restaurantId;
  final String? deliveryTime;
  final dynamic rawItem;

  const SearchResult({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.type,
    this.price,
    this.originalPrice,
    this.rating,
    this.reviewCount,
    this.isVeg,
    this.restaurantId,
    this.deliveryTime,
    this.rawItem,
  });

  String get typeLabel {
    switch (type) {
      case SearchResultType.restaurant:
        return 'Restaurant';
      case SearchResultType.food:
        return 'Dish';
      case SearchResultType.category:
        return 'Category';
      case SearchResultType.brand:
        return 'Brand';
      case SearchResultType.store99:
        return '₹99 Meal';
    }
  }
}
