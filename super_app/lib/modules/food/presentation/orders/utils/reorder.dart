import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/modules/food/data/models/cart_item_model.dart';
import 'package:superapp_user/modules/food/data/models/food_model.dart';
import 'package:superapp_user/modules/food/data/models/food_variant.dart';
import 'package:superapp_user/modules/food/data/models/order_model.dart';
import 'package:superapp_user/modules/food/application/providers/catalog_providers.dart';

/// Rebuilds an order's items as cart lines, resolved against the
/// restaurant's CURRENT menu/add-on catalog rather than the order's own
/// (stale, id-less) display data — the backend rejects a placed order whose
/// `variantId` isn't a real catalog id, so reordering must look the chosen
/// variant/add-ons back up by name on the live menu to recover their ids.
///
/// An item no longer on the menu falls back to the order's own name/price
/// with no variant/add-ons selected, rather than failing the whole reorder.
Future<List<CartItemModel>> resolveReorderItems(
  WidgetRef ref,
  OrderModel order,
) async {
  var menu = const <FoodModel>[];
  var addons = const <FoodAddon>[];
  try {
    menu = await ref
        .read(catalogRemoteDataSourceProvider)
        .getRestaurantMenu(order.restaurantId);
  } catch (_) {}
  try {
    addons = await ref.read(restaurantAddonsProvider(order.restaurantId).future);
  } catch (_) {}

  return order.items.map((item) {
    final liveFood = menu.where((f) => f.id == item.itemId).firstOrNull;
    final food =
        liveFood ??
        FoodModel(
          id: item.itemId,
          restaurantId: order.restaurantId,
          name: item.name,
          description: '',
          price: item.price,
          imageUrl: item.imageUrl,
          isVeg: item.isVeg,
        );

    final variant = (liveFood == null || item.variants.isEmpty)
        ? null
        : liveFood.variants.where((v) => v.name == item.variants.first).firstOrNull;

    final selectedAddons = (liveFood == null || item.addons.isEmpty)
        ? const <FoodAddon>[]
        : addons.where((a) => item.addons.contains(a.name)).toList();

    return CartItemModel(
      id: item.itemId,
      food: food,
      quantity: item.quantity,
      selectedVariant: variant?.name,
      selectedVariantPrice: variant == null ? 0.0 : variant.price - food.price,
      selectedAddons: selectedAddons.map((a) => a.id).toList(),
      selectedAddonsPrice: selectedAddons.fold(0.0, (sum, a) => sum + a.price),
    );
  }).toList();
}
