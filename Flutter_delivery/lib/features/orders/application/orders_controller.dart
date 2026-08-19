import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../core/services/socket_service.dart';
import '../data/models/delivery_order.dart';
import '../data/orders_repository.dart';
import 'incoming_order_controller.dart';
import 'orders_state.dart';
import 'pending_customer_rating_controller.dart';

class OrdersController extends Notifier<OrdersState> {
  late final OrdersRepository _repository;
  Timer? _pollTimer;
  StreamSubscription? _newOrderSub;
  StreamSubscription? _orderClaimedSub;
  StreamSubscription? _orderDeassignedSub;
  StreamSubscription? _orderStatusSub;
  StreamSubscription? _orderReadySub;
  StreamSubscription? _connectionSub;

  // Socket events (new_order/order_claimed/order_deassigned) and the 15s
  // poll can all ask for the same refresh within milliseconds of each other
  // — coalesce concurrent callers onto one in-flight request instead of
  // firing duplicate GETs and replacing state multiple times in a row.
  Future<void>? _refreshAllInFlight;
  Future<void>? _refreshAvailableInFlight;
  Future<void>? _refreshCurrentInFlight;

  @override
  OrdersState build() {
    _repository = ref.read(ordersRepositoryProvider);

    final socket = ref.read(socketServiceProvider);
    _newOrderSub = socket.onNewOrderAvailable.listen((_) => refreshAvailable());
    _orderClaimedSub = socket.onOrderClaimed.listen((_) => refreshAvailable());
    _orderDeassignedSub = socket.onOrderDeassigned.listen((data) {
      _leaveTrackingIfCurrent(data);
      refreshAvailable();
    });
    _orderStatusSub = socket.onOrderStatusUpdate.listen(
      (_) => refreshCurrent(),
    );
    _orderReadySub = socket.onOrderReady.listen((_) => refreshCurrent());
    // Resume live-location sharing for the active order after a reconnect.
    _connectionSub = socket.onConnectionChange.listen((connected) {
      if (!connected) return;
      final current = state;
      if (current is OrdersLoaded && current.currentOrder != null) {
        socket.joinTracking(current.currentOrder!.id);
        return;
      }
      // Socket.IO does not replay room events, so any order broadcast while
      // the connection was down is simply gone. Re-read immediately on
      // reconnect rather than waiting out the rest of the 15s poll window.
      refreshAvailable();
    });

    ref.onDispose(() {
      _pollTimer?.cancel();
      _newOrderSub?.cancel();
      _orderClaimedSub?.cancel();
      _orderDeassignedSub?.cancel();
      _orderStatusSub?.cancel();
      _orderReadySub?.cancel();
      _connectionSub?.cancel();
    });

    return const OrdersInitial();
  }

  /// `GET /orders/current` and `GET /orders/available` don't project
  /// `deliveryVerification`, so a routine refresh always reports OTP as
  /// not-required. Never let that silently clear an OTP requirement we
  /// already learned about from reachedDrop/verifyDropOtp responses —
  /// otherwise a background refresh mid-delivery would let the driver
  /// complete the order without ever verifying it.
  DeliveryOrder _preserveOtpState(DeliveryOrder? previousCurrent, DeliveryOrder fresh) {
    if (previousCurrent == null || previousCurrent.id != fresh.id) return fresh;
    if (previousCurrent.dropOtpRequired && !fresh.dropOtpRequired) {
      return fresh.copyWith(
        dropOtpRequired: true,
        dropOtpVerified: previousCurrent.dropOtpVerified,
      );
    }
    return fresh;
  }

  /// On a fresh app start (or provider rebuild) there's no `previousCurrent`
  /// to fall back on, so `_preserveOtpState` can't protect against
  /// `/orders/current`'s stripped `deliveryVerification`. If the order is
  /// already at the drop step in that situation, hydrate the real OTP state
  /// from `GET /orders/:orderId`, which returns the full document.
  Future<DeliveryOrder> _hydrateOtpState(
    DeliveryOrder? previousCurrent,
    DeliveryOrder fresh,
  ) async {
    if (previousCurrent != null && previousCurrent.id == fresh.id) {
      return _preserveOtpState(previousCurrent, fresh);
    }
    if (fresh.currentPhase == 'at_drop') {
      final detailsResult = await _repository.getOrderDetails(fresh.id);
      return detailsResult.when(
        success: (full) => full,
        failure: (_) => fresh,
      );
    }
    return fresh;
  }

  /// `_doRefreshAll`/`_doRefreshCurrent` run on every 15s poll tick AND every
  /// order-status/order-ready socket event. Without this check, each one
  /// replaces `state` with a brand-new `OrdersLoaded`/`DeliveryOrder` even
  /// when nothing actually changed — `OrdersLoaded` has no `==`, so Riverpod
  /// treats it as new state and rebuilds every watcher, including the
  /// always-mounted `ActiveTripScreen` and its `GoogleMap`. That churn is
  /// what was causing the active-trip flow to jank/feel unresponsive.
  bool _currentOrderChanged(DeliveryOrder? previous, DeliveryOrder? next) {
    if (identical(previous, next)) return false;
    if (previous == null || next == null) return true;
    return previous.id != next.id ||
        previous.currentPhase != next.currentPhase ||
        previous.orderStatus != next.orderStatus ||
        previous.paymentStatus != next.paymentStatus ||
        previous.dropOtpRequired != next.dropOtpRequired ||
        previous.dropOtpVerified != next.dropOtpVerified;
  }

  void _leaveTrackingIfCurrent(Map<String, dynamic> data) {
    final current = state;
    if (current is! OrdersLoaded || current.currentOrder == null) return;
    final orderId = (data['orderId'] ?? data['_id'] ?? data['id'])?.toString();
    if (orderId == null || orderId == current.currentOrder!.id) {
      ref.read(socketServiceProvider).leaveTracking(current.currentOrder!.id);
    }
  }

  void startPolling() {
    _pollTimer?.cancel();
    refreshAll();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 15),
      (_) => refreshAll(),
    );
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> refreshAll() {
    return _refreshAllInFlight ??=
        _doRefreshAll().whenComplete(() => _refreshAllInFlight = null);
  }

  Future<void> _doRefreshAll() async {
    if (state is OrdersInitial) state = const OrdersLoading();
    final currentResult = await _repository.getCurrentOrder();
    final DeliveryOrder? current = currentResult.when(
      success: (order) => order,
      failure: (_) => null,
    );

    if (current != null) {
      final prev = state;
      final previousCurrent = prev is OrdersLoaded ? prev.currentOrder : null;
      final hydrated = await _hydrateOtpState(previousCurrent, current);
      if (!_currentOrderChanged(previousCurrent, hydrated)) return;
      state = OrdersLoaded(
        availableOrders: prev is OrdersLoaded ? prev.availableOrders : const [],
        currentOrder: hydrated,
      );
      return;
    }

    final availableResult = await _repository.getAvailableOrders();
    availableResult.when(
      success: (orders) {
        state = OrdersLoaded(availableOrders: orders, currentOrder: null);
        _raiseAlertForPolled(orders);
      },
      failure: (error) {
        if (state is! OrdersLoaded) state = OrdersError(error.message);
      },
    );
  }

  /// Hands a polled order to the incoming-order alert.
  ///
  /// Shared by both refresh paths deliberately. The 15s timer calls
  /// [refreshAll], not [refreshAvailable] — wiring this into only one of them
  /// is exactly how a polled order ends up in the list with no alert and no
  /// ringtone, which is the failure this is here to prevent.
  void _raiseAlertForPolled(List<DeliveryOrder> orders) {
    if (orders.isEmpty) return;
    ref
        .read(incomingOrderControllerProvider.notifier)
        .offerFromPoll(orders.first);
  }

  Future<void> refreshAvailable() {
    return _refreshAvailableInFlight ??=
        _doRefreshAvailable().whenComplete(() => _refreshAvailableInFlight = null);
  }

  Future<void> _doRefreshAvailable() async {
    final prev = state;
    if (prev is OrdersLoaded && prev.hasActiveOrder) return;
    final result = await _repository.getAvailableOrders();
    result.when(
      success: (orders) {
        state = OrdersLoaded(availableOrders: orders, currentOrder: null);

        // Raise the alert for anything the realtime paths missed. The socket
        // silently drops an event when the connection is down at that instant,
        // and a push can be delayed or withheld by the OS — this poll is the
        // only path that cannot be lost, so it has to be able to ring too.
        // Guards inside offerFromPoll stop it re-showing a declined order or
        // interrupting a delivery already under way.
        _raiseAlertForPolled(orders);
      },
      failure: (_) {},
    );
  }

  Future<void> refreshCurrent() {
    return _refreshCurrentInFlight ??=
        _doRefreshCurrent().whenComplete(() => _refreshCurrentInFlight = null);
  }

  Future<void> _doRefreshCurrent() async {
    final result = await _repository.getCurrentOrder();
    await result.when(
      success: (order) async {
        final prev = state;
        final previousCurrent = prev is OrdersLoaded ? prev.currentOrder : null;
        final hydrated = order != null
            ? await _hydrateOtpState(previousCurrent, order)
            : null;
        if (!_currentOrderChanged(previousCurrent, hydrated)) return;
        state = OrdersLoaded(
          availableOrders: prev is OrdersLoaded ? prev.availableOrders : const [],
          currentOrder: hydrated,
        );
      },
      failure: (_) async {},
    );
  }

  Future<Result<DeliveryOrder, AppError>> acceptOrder(String orderId) async {
    final result = await _repository.accept(orderId);
    result.when(
      success: (order) {
        state = OrdersLoaded(availableOrders: const [], currentOrder: order);
        // Start live location sharing for this order (requirement: after accept).
        ref.read(socketServiceProvider).joinTracking(order.id);
      },
      // A rejected accept means this order is no longer takeable — almost
      // always because another rider claimed it first. Re-read rather than
      // leaving it sitting in state where the next poll can offer it again.
      failure: (_) => refreshAvailable(),
    );
    return result;
  }

  Future<Result<DeliveryOrder, AppError>> rejectOrder(String orderId) async {
    final result = await _repository.reject(orderId);
    result.when(success: (_) => refreshAvailable(), failure: (_) {});
    return result;
  }

  Future<Result<DeliveryOrder, AppError>> reachedPickup(String orderId) =>
      _mutateCurrent(() => _repository.reachedPickup(orderId));

  Future<Result<DeliveryOrder, AppError>> confirmPickup(
    String orderId, {
    String? billImageUrl,
  }) => _mutateCurrent(
    () => _repository.confirmPickup(orderId, billImageUrl: billImageUrl),
  );

  Future<Result<DeliveryOrder, AppError>> reachedDrop(String orderId) =>
      _mutateCurrent(() => _repository.reachedDrop(orderId));

  Future<Result<DeliveryOrder, AppError>> verifyDropOtp(
    String orderId,
    String otp,
  ) => _mutateCurrent(() => _repository.verifyDropOtp(orderId, otp));

  Future<Result<DeliveryOrder, AppError>> completeOrder(String orderId) async {
    final previousOrder =
        state is OrdersLoaded ? (state as OrdersLoaded).currentOrder : null;
    final result = await _repository.complete(orderId);
    result.when(
      success: (_) {
        // Stop live location sharing for this order (requirement: after delivered).
        ref.read(socketServiceProvider).leaveTracking(orderId);
        state = const OrdersLoaded(availableOrders: [], currentOrder: null);
        refreshAvailable();
        if (previousOrder != null && previousOrder.id == orderId) {
          ref
              .read(pendingCustomerRatingControllerProvider.notifier)
              .show(previousOrder);
        }
      },
      failure: (_) {},
    );
    return result;
  }

  Future<Result<DeliveryOrder, AppError>> _mutateCurrent(
    Future<Result<DeliveryOrder, AppError>> Function() action,
  ) async {
    final result = await action();
    result.when(
      success: (order) {
        final prev = state;
        state = OrdersLoaded(
          availableOrders: prev is OrdersLoaded ? prev.availableOrders : const [],
          currentOrder: order,
        );
      },
      failure: (_) {},
    );
    return result;
  }
}

final ordersControllerProvider =
    NotifierProvider<OrdersController, OrdersState>(OrdersController.new);
