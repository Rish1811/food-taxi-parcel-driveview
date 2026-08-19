import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/delivery_order.dart';

/// Single source of truth for the auto-shown "Rate the customer" prompt.
/// `null` means no pending prompt; non-null means "show it now" — set by
/// [OrdersController.completeOrder] right after a successful delivery
/// completion, and rendered as a global overlay in main.dart regardless of
/// which screen the app lands on afterward.
class PendingCustomerRatingController extends Notifier<DeliveryOrder?> {
  @override
  DeliveryOrder? build() => null;

  void show(DeliveryOrder order) => state = order;

  void dismiss() => state = null;
}

final pendingCustomerRatingControllerProvider =
    NotifierProvider<PendingCustomerRatingController, DeliveryOrder?>(
  PendingCustomerRatingController.new,
);
