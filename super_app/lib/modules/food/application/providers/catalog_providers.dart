import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/modules/food/api/datasources/catalog_remote_datasource.dart';
import 'package:superapp_user/modules/food/data/models/food_model.dart';
import 'package:superapp_user/modules/food/data/models/food_variant.dart';
import 'package:superapp_user/modules/food/data/models/restaurant_model.dart';
import 'package:superapp_user/core/network/network_providers.dart';

/// Discovery transport — shared by the catalog repository, zone detection and
/// search, so they all go through the one Dio instance.
final catalogRemoteDataSourceProvider = Provider<CatalogRemoteDataSource>((
  ref,
) {
  return CatalogRemoteDataSource(ref.watch(apiClientProvider));
});

/// Restaurant-scoped add-ons, cached per restaurant for the session.
///
/// Returns an empty list on failure so the variant sheet still shows sizes
/// when the add-on endpoint is unavailable.
final restaurantAddonsProvider = FutureProvider.family<List<FoodAddon>, String>(
  (ref, restaurantId) async {
    if (restaurantId.isEmpty) return const [];
    try {
      return await ref
          .watch(catalogRemoteDataSourceProvider)
          .getAddons(restaurantId);
    } catch (_) {
      return const [];
    }
  },
);

/// Resolves any restaurant by id regardless of whether it's in the current
/// "nearby" list — used by the cart header, which must show the right name
/// even if the user has since moved out of that zone.
final restaurantByIdProvider = FutureProvider.family<RestaurantModel?, String>((
  ref,
  restaurantId,
) async {
  if (restaurantId.isEmpty) return null;
  try {
    return await ref
        .watch(catalogRemoteDataSourceProvider)
        .getRestaurantById(restaurantId);
  } catch (_) {
    return null;
  }
});

/// Resolves any food item by foodId and optional restaurantId from the backend.
/// Used for deep linking when opening a shared product link directly.
final foodByIdProvider = FutureProvider.family<
    FoodModel?,
    ({String foodId, String restaurantId})
>((ref, args) async {
  if (args.foodId.isEmpty) return null;
  final dataSource = ref.watch(catalogRemoteDataSourceProvider);

  if (args.restaurantId.isNotEmpty) {
    try {
      final menu = await dataSource.getRestaurantMenu(args.restaurantId);
      final match = menu.where((f) => f.id == args.foodId).firstOrNull;
      if (match != null) return match;
    } catch (_) {}
  }

  try {
    final foods = await dataSource.getPublicFoods(limit: 200);
    return foods.where((f) => f.id == args.foodId).firstOrNull;
  } catch (_) {
    return null;
  }
});
