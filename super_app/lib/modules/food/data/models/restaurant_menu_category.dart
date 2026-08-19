/// Domain entity representing a menu category inside a restaurant.
class RestaurantMenuCategory {
  final String id;
  final String name;
  final int itemCount;

  const RestaurantMenuCategory({
    required this.id,
    required this.name,
    this.itemCount = 0,
  });
}
