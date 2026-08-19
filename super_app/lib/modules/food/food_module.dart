import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/core/config/backend_ids.dart';
import 'package:superapp_user/design_system/tokens/module_accent.dart';
import 'package:superapp_user/modules/app_module.dart';
import 'package:superapp_user/modules/food/food_route_names.dart';
import 'package:superapp_user/modules/food/food_routes.dart';
import 'package:superapp_user/modules/module_id.dart';

/// Food ordering: restaurants, dishes, cart, checkout, orders, Store99.
class FoodModule extends AppModule {
  const FoodModule();

  @override
  ModuleId get id => ModuleId.food;

  @override
  String get label => 'Food';

  @override
  String get tagline => 'Delicious meals';

  @override
  IconData get icon => Icons.restaurant_rounded;

  @override
  ModuleAccent get accent => ModuleAccent.food;

  @override
  String get endpointId => BackendIds.k9;

  @override
  String get entryRoute => FoodRoutePaths.home;

  @override
  int get order => 0;

  @override
  bool get isEnabled => true;

  @override
  List<RouteBase> routes(GlobalKey<NavigatorState> rootNavigatorKey) =>
      foodRoutes(rootNavigatorKey);

  /// Order-lifecycle pushes.
  ///
  /// The k9 backend does not yet send a `module` discriminator, so this also
  /// matches on `type`. Those prefixes are genuinely ambiguous — food uses
  /// `delivery_*` for *food* delivery, and the parcel module will want the same
  /// words — which is exactly why `data.module` is worth asking the backend
  /// for. Once it lands, the prefix fallbacks below can be deleted.
  @override
  PushRoute? resolvePush(PushMessage message) {
    if (message.module != null && message.module != ModuleId.food) return null;

    final type = message.type;
    final isFoodEvent = type.startsWith('order_') ||
        type.startsWith('delivery_') ||
        type == 'payment_success';
    if (!isFoodEvent) return null;

    // The Mongo id is what `GET /food/orders/:id` expects; `orderId` is the
    // human-facing reference and will 404 if used as the path parameter.
    final orderId = message.string('orderMongoId') ??
        message.string('jobId') ??
        message.string('orderId');
    if (orderId == null) return null;

    return switch (type) {
      'order_delivered' => PushRoute(FoodRoutePaths.orderDeliveredOf(orderId)),
      'payment_success' => PushRoute(FoodRoutePaths.orderSuccessOf(orderId)),
      _ => PushRoute(FoodRoutePaths.trackOrder(orderId)),
    };
  }
}
