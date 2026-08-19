import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/design_system/tokens/module_accent.dart';
import 'package:superapp_user/modules/module_id.dart';

/// A destination a push notification resolves to.
@immutable
class PushRoute {
  const PushRoute(this.location, {this.replace = false});

  /// An in-app route, e.g. `/food/orders/665f/track`.
  final String location;

  /// True when the target replaces the current page rather than stacking on
  /// it — used for terminal states like "search cancelled, nothing to track".
  final bool replace;
}

/// A push notification, normalised away from FCM's shape.
///
/// The k9 backend currently sends a free-form `data` map with **no `module`
/// field** (see `core/notifications/firebase.service.js`), so [module] is
/// usually null today and modules must fall back to matching [type]. Once the
/// backend adds `data.module`, resolution becomes unambiguous with no client
/// change beyond deleting the type-prefix fallbacks.
@immutable
class PushMessage {
  const PushMessage({
    required this.type,
    required this.data,
    this.module,
    this.title,
    this.body,
  });

  final ModuleId? module;
  final String type;
  final String? title;
  final String? body;
  final Map<String, dynamic> data;

  String? string(String key) {
    final value = data[key];
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }
}

/// One vertical product inside the super app.
///
/// Every cross-cutting system — routing, push routing, the hub, DI scoping —
/// takes its per-module contribution from here. That is the whole point: adding
/// a module is writing one implementation and adding one line to the registry,
/// never editing the router or the push handler.
///
/// Rules a module must respect:
///  * every route it returns starts with [entryRoute]
///  * it never imports another module
///  * anything it needs from another module goes through `shared/`
abstract class AppModule {
  const AppModule();

  ModuleId get id;

  /// Short name shown on the service switcher.
  String get label;

  /// One-line description under the label ("Delicious meals", "Book a ride").
  String get tagline;

  /// Brand colour applied to this module's route subtree.
  ModuleAccent get accent;

  /// Hub tile icon. Kept as [IconData] for now; swap for an asset when the
  /// hub gets its final design.
  IconData get icon;

  /// Which backend this module talks to. All four currently resolve to the
  /// single k9 host — the indirection exists so a future split (or a
  /// transitional second host) is a config change, not a refactor.
  String get endpointId;

  /// Where the hub sends the user. Always this module's own namespace.
  String get entryRoute;

  /// Ordering on the hub. Lower sorts first.
  int get order;

  /// This module's route subtree, already namespaced under [entryRoute].
  List<RouteBase> routes(GlobalKey<NavigatorState> rootNavigatorKey);

  /// Wraps this module's route subtree.
  ///
  /// This is where a module installs its own `ProviderScope` (so its
  /// controllers dispose on exit instead of living in the root scope forever)
  /// and its `ModuleTheme` accent.
  ///
  /// It returns a widget rather than a list of overrides because Riverpod 3
  /// no longer exports the `Override` type publicly — overrides can be built
  /// (`provider.overrideWith(...)`) but not named in a signature. Letting the
  /// module compose its own wrapper is the better shape anyway: scope and
  /// theme are one concern, owned in one place.
  Widget wrapSubtree(BuildContext context, Widget child) => child;

  /// Claim a push, or return null to decline so the next module can try.
  ///
  /// Be conservative: a module that matches too eagerly silently steals
  /// another module's notifications.
  PushRoute? resolvePush(PushMessage message) => null;

  /// Server-driven availability. A disabled module is hidden from the hub and
  /// its routes are not registered at all, so deep links into it 404 rather
  /// than opening a half-initialised screen.
  bool get isEnabled => true;

  /// Expensive one-time setup, deferred until the module is first entered —
  /// never run at app boot.
  Future<void> warmUp(Ref ref) async {}

  /// Release heavy resources (map controllers, image caches) on exit.
  Future<void> coolDown(Ref ref) async {}
}
