/// Route names and paths for the food module.
///
/// Every path starts with `/food`. That prefix is what guarantees this module
/// can never collide with taxi, parcel or rental — nine paths collided between
/// the two source apps before namespacing (`/home`, `/search`, `/profile`,
/// `/wallet`, `/notifications`, `/` among them).
///
/// Navigate with `context.goNamed` / `pushNamed` and the `name` constants, not
/// with raw path strings: with four modules and ~90 routes a typo in a literal
/// is a runtime "page not found" that no compiler catches.
class FoodRoutePaths {
  const FoodRoutePaths._();

  static const String home = '/food';
  static const String cart = '/food/cart';
  static const String store99 = '/food/store99';
  static const String profile = '/food/profile';

  static const String restaurantRoot = '/food/restaurants';
  static const String restaurant = ':id';
  static const String dishRoot = '/food/dishes';
  static const String dish = ':id';
  static const String filter = '/food/filter';
  static const String favorites = '/food/favorites';
  static const String offers = '/food/offers';
  static const String reorder = '/food/reorder';

  static const String orders = '/food/orders';
  static const String orderDetails = '/food/orders/:id';
  static const String orderTracking = '/food/orders/:id/track';
  static const String orderSuccess = '/food/orders/:id/success';
  static const String orderDelivered = '/food/orders/:id/delivered';

  // Builders for call sites, so no one hand-concatenates ids.
  static String restaurantOf(String id) => '/food/restaurants/$id';
  static String dishOf(String id, {String? restaurantId}) => restaurantId == null
      ? '/food/dishes/$id'
      : '/food/dishes/$id?restaurantId=$restaurantId';
  static String orderOf(String id) => '/food/orders/$id';
  static String trackOrder(String id) => '/food/orders/$id/track';
  static String orderSuccessOf(String id) => '/food/orders/$id/success';
  static String orderDeliveredOf(String id) => '/food/orders/$id/delivered';
}

class FoodRouteNames {
  const FoodRouteNames._();

  static const String home = 'food.home';
  static const String cart = 'food.cart';
  static const String store99 = 'food.store99';
  static const String profile = 'food.profile';

  static const String restaurantRoot = 'food.restaurants';
  static const String restaurant = 'food.restaurant';
  static const String dishRoot = 'food.dishes';
  static const String dish = 'food.dish';
  static const String filter = 'food.filter';
  static const String favorites = 'food.favorites';
  static const String offers = 'food.offers';
  static const String reorder = 'food.reorder';

  static const String orders = 'food.orders';
  static const String orderDetails = 'food.order.details';
  static const String orderTracking = 'food.order.track';
  static const String orderSuccess = 'food.order.success';
  static const String orderDelivered = 'food.order.delivered';
}
