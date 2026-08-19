import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../core/services/fcm_service.dart';
import '../../../core/services/socket_service.dart';
import '../../work_mode/application/work_mode_controller.dart';
import '../data/models/taxi_ride.dart';
import '../data/rides_repository.dart';
import 'active_ride_controller.dart';

/// The ride-offer equivalent of `IncomingOrderController`.
///
/// `null` means no offer on screen. Offers reach the app two ways — the socket
/// while it is open, FCM `type: ride_request` while it is backgrounded — and
/// both funnel here so the alert is raised exactly once either way.
class IncomingRideController extends Notifier<TaxiRide?> {
  StreamSubscription<Map<String, dynamic>>? _requestSub;
  StreamSubscription<Map<String, dynamic>>? _closedSub;
  StreamSubscription<Map<String, dynamic>>? _fcmReceivedSub;
  StreamSubscription<Map<String, dynamic>>? _fcmTapSub;

  /// Dispatch re-offers a ride to the same driver across retry rounds. Without
  /// this the alert reappears seconds after being declined.
  final Set<String> _dismissedRideIds = {};

  @override
  TaxiRide? build() {
    final socket = ref.read(socketServiceProvider);
    _requestSub = socket.onRideRequest.listen(_onOffer);
    _closedSub = socket.onRideRequestClosed.listen(_onClosed);

    final fcm = ref.read(fcmServiceProvider);
    _fcmReceivedSub = fcm.onNotificationReceived.listen(_onOffer);
    _fcmTapSub = fcm.onNotificationTap.listen(_onOffer);

    ref.onDispose(() {
      _requestSub?.cancel();
      _closedSub?.cancel();
      _fcmReceivedSub?.cancel();
      _fcmTapSub?.cancel();
    });

    return null;
  }

  Future<void> _onOffer(Map<String, dynamic> data) async {
    // FCM carries every push type on one stream; socket ride offers carry no
    // 'type' at all, so only an explicitly non-ride type is filtered out.
    final type = data['type']?.toString();
    if (type != null && type != 'ride_request' && type != 'ride' && type != 'parcel') {
      return;
    }

    // A driver in Food-only mode must never see a ride, even if a stale offer
    // arrives from a dispatch round that started before they switched.
    if (!ref.read(workModeControllerProvider.notifier).acceptsRides) return;

    final rideId = (data['rideId'] ?? data['_id'] ?? data['id'])?.toString();
    if (rideId == null || rideId.isEmpty) return;
    if (_dismissedRideIds.contains(rideId)) return;
    if (state?.id == rideId) return;

    // Already driving? A second offer would be a backend bug, but showing it
    // would let the driver abandon a passenger mid-trip.
    if (ref.read(activeRideControllerProvider).value != null) return;

    final offer = TaxiRide.fromJson(data);

    // The push carries only {type, rideId, serviceType, userId} — no fare, no
    // addresses — so an offer that arrived that way has to be filled in before
    // it can be shown. The socket payload is already complete and skips this.
    if (offer.pickup == null && offer.fare == 0) {
      final full = await ref.read(ridesRepositoryProvider).getRide(rideId);
      // Re-check: the driver may have declined or taken another job while the
      // fetch was in flight.
      if (_dismissedRideIds.contains(rideId)) return;
      if (ref.read(activeRideControllerProvider).value != null) return;
      full.when(
        success: (ride) {
          // Someone else won it, or the passenger cancelled, between the push
          // being sent and this reaching the server.
          if (ride.stage != RideStage.searching) return;
          state = ride;
        },
        failure: (_) {},
      );
      return;
    }

    state = offer;
  }

  void _onClosed(Map<String, dynamic> data) {
    final rideId = (data['rideId'] ?? data['_id'] ?? data['id'])?.toString();
    if (rideId == null || rideId.isEmpty) return;
    // Recorded even when nothing is on screen: a queued FCM offer can be
    // delivered after the close event, and would otherwise raise an alert for
    // a ride that is already gone.
    _dismissedRideIds.add(rideId);
    if (state?.id == rideId) state = null;
  }

  /// Takes the ride. On success the active-ride controller owns it from here
  /// and the trip screen takes over.
  Future<Result<TaxiRide, AppError>> accept() async {
    final ride = state;
    if (ride == null) {
      return Result.failure(UnknownError('This ride is no longer available'));
    }
    _dismissedRideIds.add(ride.id);

    final result =
        await ref.read(activeRideControllerProvider.notifier).acceptRide(ride);
    // Cleared either way — on success the trip screen replaces it, on failure
    // the offer is stale (another driver won it) and re-showing it is a lie.
    state = null;
    return result;
  }

  /// Declines. Told to the server over the socket so dispatch moves on at once
  /// instead of waiting out the accept window.
  void decline() {
    final ride = state;
    if (ride == null) return;
    _dismissedRideIds.add(ride.id);
    state = null;
    ref.read(socketServiceProvider).rejectRide(ride.id);
  }

  /// The countdown ran out on this device. Same wire call as a decline — the
  /// server's own dispatch timer remains the authority.
  void expire() => decline();

  void dismiss() => state = null;
}

final incomingRideControllerProvider =
    NotifierProvider<IncomingRideController, TaxiRide?>(
  IncomingRideController.new,
);
