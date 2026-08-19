import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/services/socket_service.dart';
import '../../work_mode/application/work_mode_controller.dart';
import '../data/models/delivery_order.dart';
import '../data/orders_repository.dart';
import 'orders_controller.dart';

/// Single source of truth for the full-screen incoming-order alert.
/// `null` means no active alert; non-null means "show it now" — regardless
/// of whether the order arrived via Socket.IO (app open) or FCM (app
/// backgrounded/foregrounded), both transports funnel into this state.
class IncomingOrderController extends Notifier<DeliveryOrder?> {
  StreamSubscription<Map<String, dynamic>>? _socketSub;
  StreamSubscription<Map<String, dynamic>>? _fcmReceivedSub;
  StreamSubscription<Map<String, dynamic>>? _fcmTapSub;
  StreamSubscription<Map<String, dynamic>>? _orderClaimedSub;
  StreamSubscription<Map<String, dynamic>>? _orderDeassignedSub;

  // Backend keeps re-offering an order to this partner across re-offer
  // rounds even after it's been declined/expired here — track what's
  // already been resolved this session so it isn't shown again.
  final Set<String> _dismissedOrderIds = {};

  @override
  DeliveryOrder? build() {
    final socket = ref.read(socketServiceProvider);
    _socketSub = socket.onNewOrderAvailable.listen(_onRealtimePayload);
    _orderClaimedSub = socket.onOrderClaimed.listen(_autoDismissIfMatch);
    _orderDeassignedSub = socket.onOrderDeassigned.listen(_autoDismissIfMatch);

    final fcm = ref.read(fcmServiceProvider);
    _fcmReceivedSub = fcm.onNotificationReceived.listen(_onRealtimePayload);
    _fcmTapSub = fcm.onNotificationTap.listen(_onRealtimePayload);

    ref.onDispose(() {
      _socketSub?.cancel();
      _fcmReceivedSub?.cancel();
      _fcmTapSub?.cancel();
      _orderClaimedSub?.cancel();
      _orderDeassignedSub?.cancel();
    });

    return null;
  }

  void _onRealtimePayload(Map<String, dynamic> data) {
    // FCM data always tags {type: 'new_order'}; non-order push types (e.g.
    // referral_bonus) must be ignored here. Socket order events carry no
    // 'type' field, so absence of the key means "treat as an order".
    // Another rider got there first. Arrives here rather than on the socket
    // stream when the app was backgrounded at the moment of the claim.
    if (data['type'] == 'order_taken') {
      _withdraw(data);
      return;
    }
    if (data['type'] != null && data['type'] != 'new_order') return;

    // A driver in Taxi-only mode must never see a food order, mirroring the
    // ride side. The backend filters dispatch too, but there is a real window
    // between it building the shortlist and this event arriving in which the
    // driver may have switched — and a queued FCM offer can land later still.
    if (!ref.read(workModeControllerProvider.notifier).acceptsFood) return;

    final orderId =
        (data['orderMongoId'] ?? data['_id'] ?? data['orderId'])?.toString();
    if (orderId == null || orderId.isEmpty) return;
    if (_dismissedOrderIds.contains(orderId)) return;
    if (state != null && state!.id == orderId) return;
    show(DeliveryOrder.fromRealtimePayload(data));
    // Raise the alert from the payload first so the ringtone and the countdown
    // start immediately, then fill in what the payload could not carry.
    unawaited(_hydrate(orderId));
  }

  /// Replaces a payload-built offer with the real order.
  ///
  /// A socket/FCM offer carries only what dispatch chose to put in it. Anything
  /// missing lands in the model as an empty string or a zero, and absent items
  /// are padded out with generic "Item" rows priced at 0 — so the rider was
  /// shown a card with no restaurant, no address and a list of blank items,
  /// which is indistinguishable from a bogus order. Accepting it then loaded
  /// the real thing and the card appeared to vanish.
  ///
  /// Deliberately non-blocking and failure-tolerant: the offer is already on
  /// screen, so a slow or failed fetch degrades to the old sparse card rather
  /// than costing the rider the job.
  Future<void> _hydrate(String orderId) async {
    final result =
        await ref.read(ordersRepositoryProvider).getOrderDetails(orderId);
    result.when(
      success: (full) {
        // The rider may have accepted, declined, or been handed a different
        // offer while this was in flight — never resurrect a resolved alert.
        final offer = state;
        if (offer == null || offer.id != orderId) return;
        state = full.copyWith(
          // `GET /orders/:id` has no notion of this rider's cut or of the
          // dispatch distances, so keep the offer's values where it is silent.
          riderEarning: full.riderEarning > 0 ? null : offer.riderEarning,
          pickupDistanceKm: offer.pickupDistanceKm,
          tripDistanceKm: offer.tripDistanceKm,
          tripDurationMins: offer.tripDurationMins,
          acceptanceDeadlineAt: offer.acceptanceDeadlineAt,
        );
      },
      failure: (_) {},
    );
  }

  void _withdraw(Map<String, dynamic> data) {
    final orderId =
        (data['orderMongoId'] ?? data['orderId'] ?? data['_id'] ?? data['id'])
            ?.toString();
    if (orderId == null || orderId.isEmpty) return;

    // Recorded even when the alert is not currently up. The withdrawal can beat
    // the offer here — FCM makes no ordering guarantee and a queued push is
    // delivered on reconnect — and without this the alert would be raised for an
    // order that is already gone.
    _dismissedOrderIds.add(orderId);
    if (state?.id == orderId) state = null;
  }

  void _autoDismissIfMatch(Map<String, dynamic> data) => _withdraw(data);

  void show(DeliveryOrder order) {
    state = order;
  }

  /// Raises the alert for an order found by the 15s poll.
  ///
  /// The poll is the only delivery path that cannot be lost: the socket drops
  /// an event if the connection is down at that instant, and a push can be
  /// delayed or dropped by the OS. Previously a poll-discovered order was
  /// added to the available list and nothing else — no full-screen alert, no
  /// ringtone — so an order that missed both realtime paths sat there silently
  /// until the rider happened to look. That is the "sometimes it never comes".
  ///
  /// Runs the same guards as the realtime path, so it cannot double-show an
  /// order already on screen, one already declined, or anything at all while a
  /// delivery is in progress.
  void offerFromPoll(DeliveryOrder order) {
    // Named reasons rather than silent returns: when the alert does not appear
    // the only question worth answering is which guard stopped it, and a bare
    // `return` makes that unanswerable from a log.
    String? blocked;
    if (order.id.isEmpty) {
      blocked = 'order has no id';
    } else if (_dismissedOrderIds.contains(order.id)) {
      blocked = 'already declined/handled this session';
    } else if (state != null) {
      blocked = 'an alert is already on screen';
    } else if (!ref.read(workModeControllerProvider.notifier).acceptsFood) {
      blocked = 'work mode is not accepting food orders';
    }

    if (blocked != null) {
      debugPrint('[POLL ALERT] skipped ${order.id}: $blocked');
      return;
    }

    debugPrint('[POLL ALERT] raising alert for ${order.id}');
    state = order;
  }

  /// Takes the job. Returns `null` on success, or the reason it failed.
  ///
  /// The result used to be discarded and the alert closed either way, so an
  /// accept that the backend rejected — the order already claimed by another
  /// rider, or a busy-lock still held from a previous job — looked exactly like
  /// an order that silently deleted itself. The caller is expected to show what
  /// comes back.
  Future<String?> accept() async {
    final order = state;
    if (order == null) return null;
    // Belt and braces: an offer with no id can only ever produce a failed
    // accept against an empty path, which is how a blank card used to look
    // like an order that deleted itself.
    if (order.id.isEmpty) {
      state = null;
      return 'This order is no longer available.';
    }
    _dismissedOrderIds.add(order.id);
    // Don't set state to null yet! Let the IncomingOrderScreen show its loader.
    // Wait for the API to actually complete.
    final result =
        await ref.read(ordersControllerProvider.notifier).acceptOrder(order.id);

    // Dismissed either way: on success ordersController has already swapped in
    // the ActiveTripScreen, and on failure this offer is no longer takeable.
    state = null;

    return result.when(
      success: (_) => null,
      failure: (error) => error.message,
    );
  }

  Future<void> decline() async {
    final order = state;
    if (order == null) return;
    _dismissedOrderIds.add(order.id);
    state = null;
    await ref.read(ordersControllerProvider.notifier).rejectOrder(order.id);
  }

  /// Countdown ran out client-side — best-effort notify the backend so it
  /// can reassign sooner. The BullMQ `processDispatchTimeout` job remains
  /// the authoritative fallback if this call never arrives.
  Future<void> expire() => decline();

  void dismiss() {
    state = null;
  }
}

final incomingOrderControllerProvider =
    NotifierProvider<IncomingOrderController, DeliveryOrder?>(
  IncomingOrderController.new,
);
