import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/error/result.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/socket_service.dart';
import '../data/models/taxi_ride.dart';
import '../data/rides_repository.dart';

/// The one ride this driver is currently on, `null` when free.
///
/// Every stage transition goes through here so the ride can only ever move
/// forward one step at a time — the server rejects out-of-order transitions,
/// and a screen calling `setStage` directly could ask for one.
class ActiveRideController extends AsyncNotifier<TaxiRide?> {
  StreamSubscription<Map<String, dynamic>>? _stateSub;
  StreamSubscription<bool>? _connectionSub;
  StreamSubscription<Position>? _positionSub;

  RidesRepository get _repository => ref.read(ridesRepositoryProvider);
  SocketService get _socket => ref.read(socketServiceProvider);

  @override
  Future<TaxiRide?> build() async {
    _stateSub = _socket.onRideState.listen(_onServerState);

    // Socket.IO rooms are per-connection: a reconnect gets a new socket id and
    // the server drops every room this client had joined. Nothing re-sends
    // ride:join on its own, so without this the driver silently stops
    // receiving ride events — including a passenger cancellation — after any
    // network blip mid-trip.
    _connectionSub = _socket.onConnectionChange.listen((connected) {
      if (!connected) return;
      final ride = state.value;
      if (ride != null) _socket.joinRide(ride.id);
    });

    ref.onDispose(() {
      _stateSub?.cancel();
      _connectionSub?.cancel();
      _positionSub?.cancel();
    });

    // Recovery path: a killed app misses every socket event, so the active
    // ride is always re-read rather than assumed absent.
    final result = await _repository.getActiveRide();
    final ride = result.when(success: (r) => r, failure: (_) => null);
    if (ride != null) {
      _socket.joinRide(ride.id);
      _startLocationSharing();
    }
    return ride;
  }

  /// Server-pushed movement on the current ride — chiefly a passenger
  /// cancellation, which has to clear the trip screen immediately.
  void _onServerState(Map<String, dynamic> data) {
    final ride = state.value;
    if (ride == null) return;
    final rideId = (data['rideId'] ?? data['_id'] ?? data['id'])?.toString();
    if (rideId != null && rideId.isNotEmpty && rideId != ride.id) return;

    final stage = RideStage.parse(
      (data['liveStatus'] ?? data['status'])?.toString(),
    );
    if (stage == RideStage.searching) return; // no usable status in the payload
    if (stage.isFinished) {
      _finish();
      return;
    }
    if (stage != ride.stage) state = AsyncData(ride.copyWith(stage: stage));
  }

  /// Claims an offered ride.
  ///
  /// Acceptance is socket-only on the backend and deliberately racy: several
  /// drivers are offered the same ride and the first transaction wins. There is
  /// no per-call ack, so success arrives as `rideAccepted` and loss as
  /// `errorMessage`, and this waits on whichever lands first.
  Future<Result<TaxiRide, AppError>> acceptRide(TaxiRide offer) async {
    final accepted = _socket.onRideAccepted
        .firstWhere((data) => _idOf(data) == offer.id || _idOf(data).isEmpty)
        .then<Object?>((data) => data);
    final failed = _socket.onSocketError.first.then<Object?>((data) => data);

    _socket.acceptRide(offer.id);

    Object? outcome;
    try {
      outcome = await Future.any([accepted, failed]).timeout(
        const Duration(seconds: 12),
      );
    } catch (_) {
      // Timed out, or the socket went away mid-claim. Silence is not failure —
      // the claim may well have landed — so fall back to the authoritative
      // read rather than guessing in either direction.
      await refresh();
      final ride = state.value;
      if (ride == null) {
        return Result.failure(
          NetworkError('No response from the server. Check your connection.'),
        );
      }
      _afterClaim(ride);
      return Result.success(ride);
    }

    final data = outcome is Map<String, dynamic> ? outcome : const {};
    if (data.containsKey('message') && !data.containsKey('liveStatus')) {
      return Result.failure(
        UnknownError(data['message']?.toString() ?? 'Ride is no longer available'),
      );
    }

    // `rideAccepted` is an acknowledgement, not the ride document — it carries
    // no passenger, addresses or fare. Keep the offer's details and take only
    // the confirmed stage from the server.
    final ride = offer.copyWith(
      stage: RideStage.parse(
        (data['liveStatus'] ?? data['status'])?.toString(),
      ),
    );
    final confirmed =
        ride.stage == RideStage.searching ? offer.copyWith(stage: RideStage.accepted) : ride;
    state = AsyncData(confirmed);
    _afterClaim(confirmed);
    return Result.success(confirmed);
  }

  void _afterClaim(TaxiRide ride) {
    _socket.joinRide(ride.id);
    _startLocationSharing();
  }

  static String _idOf(Map<String, dynamic> data) =>
      (data['rideId'] ?? data['_id'] ?? data['id'] ?? '').toString();

  /// Moves the ride to the next stage in the lifecycle.
  ///
  /// Deliberately takes no target: the sequence is fixed
  /// (accepted → arriving → started → arrived → completed) and letting callers
  /// name a stage is how a screen ends up skipping the pickup.
  /// [collectedByDriver] records that the driver physically took the money, for
  /// the cash-in-hand ledger. It is intentionally not sent to the server: the
  /// backend derives cash owed from `paymentMethod` on completion, and the only
  /// ride field named for a payment collection is the Razorpay link object,
  /// which a boolean cannot be cast into.
  Future<Result<TaxiRide, AppError>> advance({
    String? otp,
    String? paymentMethod,
    double? fare,
    bool? collectedByDriver,
  }) async {
    final ride = state.value;
    if (ride == null) {
      return Result.failure(UnknownError('No ride in progress'));
    }
    final next = ride.stage.next;
    if (next == null) {
      return Result.failure(UnknownError('This ride is already finished'));
    }

    final result = await _repository.setStage(
      ride.id,
      next,
      otp: otp,
      paymentMethod: paymentMethod,
      fare: fare,
    );
    return result.when(
      success: (updated) {
        if (updated.stage.isFinished) {
          _finish();
        } else {
          state = AsyncData(updated);
        }
        return Result.success(updated);
      },
      failure: (error) => Result.failure(error),
    );
  }

  Future<Result<void, AppError>> cancel({String? reason}) async {
    final ride = state.value;
    if (ride == null) return const Result.success(null);
    final result = await _repository.cancel(ride.id, reason: reason);
    return result.when(
      success: (_) {
        _finish();
        return const Result.success(null);
      },
      failure: (error) => Result.failure(error),
    );
  }

  Future<void> refresh() async {
    final result = await _repository.getActiveRide();
    result.when(
      success: (ride) => state = AsyncData(ride),
      failure: (_) {},
    );
  }

  void _finish() {
    _positionSub?.cancel();
    _positionSub = null;
    state = const AsyncData(null);
  }

  /// Feeds the passenger's live map for the duration of the ride.
  ///
  /// Separate from the food flow's `update-location`, which is keyed by order
  /// id and would not reach the taxi ride room.
  void _startLocationSharing() {
    _positionSub?.cancel();
    final locationService = ref.read(locationServiceProvider);
    locationService.startTracking();
    _positionSub = locationService.positionStream.listen((position) {
      final ride = state.value;
      if (ride == null) return;
      _socket.sendRideDriverLocation(
        rideId: ride.id,
        lat: position.latitude,
        lng: position.longitude,
        heading: position.heading,
        speed: position.speed,
      );
    });
  }
}

final activeRideControllerProvider =
    AsyncNotifierProvider<ActiveRideController, TaxiRide?>(
  ActiveRideController.new,
);
