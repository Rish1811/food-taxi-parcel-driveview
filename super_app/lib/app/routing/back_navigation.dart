import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import 'package:superapp_user/app/routing/route_names.dart';

extension SafeBackNavigation on BuildContext {
  /// A back action that always does something.
  ///
  /// Bare `context.pop()` asserts in debug and does nothing in release when
  /// there is no history to pop — which is the normal state for a screen opened
  /// from a notification tap or a deep link, or reached after a `go()` replaced
  /// the stack. Those back buttons simply did not respond.
  ///
  /// Falls back to a sensible destination instead of dead-ending.
  void backOr([String fallbackRoute = RouteNames.home]) {
    if (canPop()) {
      pop();
    } else {
      go(fallbackRoute);
    }
  }
}
