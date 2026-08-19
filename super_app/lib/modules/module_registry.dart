import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/modules/app_module.dart';
import 'package:superapp_user/modules/food/food_module.dart';
import 'package:superapp_user/modules/parcel/parcel_module.dart';
import 'package:superapp_user/modules/rental/rental_module.dart';
import 'package:superapp_user/modules/taxi/taxi_module.dart';
import 'package:superapp_user/modules/module_id.dart';

/// **The only place modules are listed.**
///
/// Adding a module is one line here plus one implementation file. If anything
/// else has to change to make a module appear, that is a bug in the platform
/// layer, not something to work around in the module.
final moduleRegistryProvider = Provider<ModuleRegistry>((ref) {
  return const ModuleRegistry([
    FoodModule(),
    TaxiModule(),
    ParcelModule(),
    RentalModule(),
  ]);
});

class ModuleRegistry {
  const ModuleRegistry(this._modules);

  final List<AppModule> _modules;

  /// Every registered module, including disabled ones.
  List<AppModule> get all => _modules;

  /// Modules that are switched on, in hub display order.
  List<AppModule> get enabled {
    final list = _modules.where((m) => m.isEnabled).toList()
      ..sort((a, b) => a.order.compareTo(b.order));
    return list;
  }

  AppModule? byId(ModuleId id) {
    for (final module in _modules) {
      if (module.id == id) return module;
    }
    return null;
  }

  bool isEnabledId(ModuleId id) => byId(id)?.isEnabled ?? false;

  /// Route subtrees of every enabled module, flattened for the router.
  List<RouteBase> routes(GlobalKey<NavigatorState> rootNavigatorKey) => [
        for (final module in enabled) ...module.routes(rootNavigatorKey),
      ];

  /// First module to claim the push wins. Order is hub order, so a module can
  /// be given priority by lowering its [AppModule.order].
  PushRoute? resolvePush(PushMessage message) {
    // An explicitly addressed message goes straight to its owner — no chance
    // for another module to intercept it.
    final addressed = message.module;
    if (addressed != null) {
      final owner = byId(addressed);
      if (owner == null || !owner.isEnabled) return null;
      return owner.resolvePush(message);
    }
    for (final module in enabled) {
      final route = module.resolvePush(message);
      if (route != null) return route;
    }
    return null;
  }

  /// Wraps [child] in the owning module's scope and accent, if the location
  /// belongs to a module. Shared and session routes pass through untouched.
  Widget wrapForLocation(BuildContext context, String location, Widget child) {
    final id = ModuleId.fromLocation(location);
    if (id == null) return child;
    return byId(id)?.wrapSubtree(context, child) ?? child;
  }
}
