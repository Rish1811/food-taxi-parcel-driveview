import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/features/orders/application/orders_controller.dart';
import 'package:food_user_application/features/orders/application/orders_state.dart';

/// Tracks whether the full-screen active-trip overlay should be shown on top
/// of whatever route is currently active. Defaults to visible whenever a new
/// order id appears, so a minimized trip re-maximizes automatically the
/// moment a new active order comes in.
class ActiveTripVisibilityController extends Notifier<bool> {
  String? _lastOrderId;

  @override
  bool build() {
    ref.listen<OrdersState>(ordersControllerProvider, (previous, next) {
      final nextId = next is OrdersLoaded ? next.currentOrder?.id : null;
      if (nextId != _lastOrderId) {
        _lastOrderId = nextId;
        if (nextId != null) state = true;
      }
    });
    final current = ref.read(ordersControllerProvider);
    _lastOrderId = current is OrdersLoaded ? current.currentOrder?.id : null;
    return true;
  }

  void show() => state = true;
  void hide() => state = false;
}

final activeTripVisibilityControllerProvider =
    NotifierProvider<ActiveTripVisibilityController, bool>(
  ActiveTripVisibilityController.new,
);
