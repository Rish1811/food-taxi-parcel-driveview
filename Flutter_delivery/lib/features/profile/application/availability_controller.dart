import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/error/result.dart';
import '../../../core/services/location_service.dart';
import '../../../core/services/rider_online_service.dart';
import '../../../core/services/socket_service.dart';
import '../../auth/application/auth_state.dart';
import '../../auth/application/auth_controller.dart';
import '../../orders/application/orders_controller.dart';
import '../../orders/application/orders_state.dart';
import '../../work_mode/application/work_mode_controller.dart';
import '../../work_mode/data/driver_availability_repository.dart';
import '../data/profile_repository.dart';

class AvailabilityController extends Notifier<bool> {
  late final ProfileRepository _repository;
  StreamSubscription<Position>? _positionSub;
  Timer? _keepAliveTimer;
  DateTime _lastPing = DateTime.fromMillisecondsSinceEpoch(0);

  @override
  bool build() {
    _repository = ref.read(profileRepositoryProvider);
    final authState = ref.read(authControllerProvider);
    final startedOnline = authState is AuthAuthenticated && authState.user.isOnline;

    ref.onDispose(() {
      _positionSub?.cancel();
      _keepAliveTimer?.cancel();
      // Covers logout, which tears this controller down without going through
      // goOffline — otherwise the service and its notification outlive the
      // session, claiming a signed-out rider is online.
      unawaited(RiderOnlineService.stop());
    });

    if (startedOnline) {
      Future.microtask(() {
        _startTracking();
        ref.read(ordersControllerProvider.notifier).startPolling();
      });
    }
    return startedOnline;
  }

  Future<Result<void, AppError>> toggle({String? selfieImageUrl}) async {
    if (state) {
      return goOffline();
    }
    return goOnline(selfieImageUrl: selfieImageUrl);
  }

  /// [selfieImageUrl] is only needed on the first go-online of the day, and
  /// only by the taxi side — the caller checks with
  /// [DriverAvailabilityRepository.selfieStatus] and captures one if so.
  Future<Result<void, AppError>> goOnline({String? selfieImageUrl}) async {
    final locationService = ref.read(locationServiceProvider);
    final hasPermission = await locationService.ensurePermissions();
    if (!hasPermission) {
      return Result.failure(
        NetworkError('Location permission is required to go online'),
      );
    }

    Position? position;
    try {
      position = await Geolocator.getCurrentPosition();
      locationService.lastPosition = position;
    } catch (_) {
      // fall through — the availability ping will pick up the next fix
    }

    final result = await _repository.updateAvailability(
      true,
      lat: position?.latitude,
      lng: position?.longitude,
    );
    return result.when(
      success: (_) {
        state = true;
        ref.read(ordersControllerProvider.notifier).startPolling();
        _startTracking();
        // Fire-and-forget: a taxi-side failure (no selfie today, wallet
        // blocked) must not undo a successful food go-online. The switcher
        // surfaces the reason separately via [taxiOnlineError].
        unawaited(_goOnlineForRides(position, selfieImageUrl: selfieImageUrl));
        return const Result.success(null);
      },
      failure: (error) => Result.failure(error),
    );
  }

  /// Why the taxi half of going online failed, or null.
  ///
  /// Kept out of [state] deliberately: the driver *is* online — for food — and
  /// flipping the switch back would be a lie. This is the "you won't get rides,
  /// and here's why" channel.
  String? taxiOnlineError;

  /// Re-applies the taxi online state after the work mode changes mid-shift.
  ///
  /// Switching Food → Both while already online otherwise leaves `isOnline`
  /// false on the taxi document, so the new mode would appear to take effect
  /// and produce no rides at all until the driver toggled offline and back.
  Future<String?> syncRideAvailability({String? selfieImageUrl}) async {
    if (!state) return null;
    if (ref.read(currentWorkModeProvider).acceptsRides) {
      await _goOnlineForRides(null, selfieImageUrl: selfieImageUrl);
      return taxiOnlineError;
    }
    // Switched to Food-only: stand down from ride dispatch, or offers keep
    // arriving for a mode the driver just turned off.
    await ref.read(driverAvailabilityRepositoryProvider).goOffline();
    return null;
  }

  /// Mirrors the online state onto the unified taxi driver document.
  ///
  /// Without this the driver is online for food only: taxi dispatch matches on
  /// `Driver.isOnline` and `acceptRideAssignment` re-checks it, so every ride
  /// would pass them by and any offer that did arrive could not be accepted.
  Future<void> _goOnlineForRides(
    Position? position, {
    String? selfieImageUrl,
  }) async {
    taxiOnlineError = null;
    if (!ref.read(currentWorkModeProvider).acceptsRides) return;

    final pos = position ?? ref.read(locationServiceProvider).lastPosition;
    if (pos == null) {
      taxiOnlineError = 'Waiting for GPS before ride requests can start';
      return;
    }

    final result = await ref.read(driverAvailabilityRepositoryProvider).goOnline(
          lat: pos.latitude,
          lng: pos.longitude,
          selfieImageUrl: selfieImageUrl,
        );
    result.when(
      success: (_) => taxiOnlineError = null,
      failure: (error) => taxiOnlineError = error.message,
    );
  }

  Future<Result<void, AppError>> goOffline() async {
    final result = await _repository.updateAvailability(false);
    _stopTracking();
    ref.read(ordersControllerProvider.notifier).stopPolling();
    state = false;
    taxiOnlineError = null;
    // Always sent, regardless of work mode: a driver who switches to Food-only
    // and then goes offline would otherwise stay `isOnline` on the taxi side
    // and keep being offered rides they never see.
    unawaited(ref.read(driverAvailabilityRepositoryProvider).goOffline());
    return result.when(
      success: (_) => const Result.success(null),
      failure: (error) => Result.failure(error),
    );
  }

  void _startTracking() {
    // Ask Android to stop freezing us first. Everything below — the position
    // stream and the keep-alive ping — silently stops running once the process
    // is backgrounded without this, which is what let riders go stale and drop
    // out of dispatch while believing they were online.
    unawaited(RiderOnlineService.start());

    final locationService = ref.read(locationServiceProvider);
    locationService.startTracking();
    _positionSub?.cancel();
    _positionSub = locationService.positionStream.listen(_onPosition);

    // The position stream only emits on movement (distanceFilter), so a
    // stationary rider would otherwise never refresh lastLocationAt and
    // silently drop out of dispatch once the backend's GPS staleness
    // window elapses. Ping on a timer too, independent of movement.
    _keepAliveTimer?.cancel();
    _keepAliveTimer = Timer.periodic(const Duration(minutes: 3), (_) => _pingLocation());
    // Ping immediately as well. build() starts tracking for a rider who was
    // already online without ever taking a fix (unlike goOnline, which calls
    // getCurrentPosition), so without this their first ping is 3 minutes away
    // at best — and never, if they don't move.
    unawaited(_pingLocation());
  }

  /// Refreshes lastLocationAt server-side so dispatch keeps considering this rider.
  ///
  /// Resolving a position here rather than bailing on null is the whole point:
  /// LocationService.lastPosition stays null until the movement-gated stream first
  /// emits, which never happens for a rider who resumed the app already-online and
  /// hasn't moved 15m. Those riders were being dropped from every order offer, so
  /// they never even received the new-order push.
  Future<void> _pingLocation() async {
    final service = ref.read(locationServiceProvider);
    var pos = service.lastPosition ?? await Geolocator.getLastKnownPosition();
    if (pos == null) {
      try {
        pos = await Geolocator.getCurrentPosition();
      } catch (_) {
        return; // No fix available at all — nothing useful to report.
      }
    }
    service.lastPosition = pos;
    _lastPing = DateTime.now();
    await _repository.updateAvailability(true, lat: pos.latitude, lng: pos.longitude);
    _pushTaxiLocation(pos);
  }

  /// Taxi dispatch matches on the unified driver's own `location` field, which
  /// the food availability ping never touches. Without this a driver in Taxi or
  /// Both mode sits at whatever coordinates they last had — or none at all —
  /// and falls outside every dispatch radius while believing they are online.
  void _pushTaxiLocation(Position position) {
    if (!ref.read(currentWorkModeProvider).acceptsRides) return;
    ref.read(socketServiceProvider).sendDriverLocation(
          lat: position.latitude,
          lng: position.longitude,
        );
  }

  void _stopTracking() {
    _positionSub?.cancel();
    _positionSub = null;
    _keepAliveTimer?.cancel();
    _keepAliveTimer = null;
    ref.read(locationServiceProvider).stopTracking();

    // The notification must go the moment the rider goes offline. A lingering
    // "You're online" is both a lie and a battery drain, and it is the single
    // fastest way to get uninstalled.
    unawaited(RiderOnlineService.stop());
  }

  void _onPosition(Position position) {
    final now = DateTime.now();
    if (now.difference(_lastPing) < const Duration(seconds: 4)) return;
    _lastPing = now;

    _repository.updateAvailability(
      true,
      lat: position.latitude,
      lng: position.longitude,
    );
    _pushTaxiLocation(position);

    final ordersState = ref.read(ordersControllerProvider);
    if (ordersState is OrdersLoaded && ordersState.currentOrder != null) {
      ref.read(socketServiceProvider).sendLocationUpdate(
        orderId: ordersState.currentOrder!.id,
        lat: position.latitude,
        lng: position.longitude,
        heading: position.heading,
        speed: position.speed,
        accuracy: position.accuracy,
      );
    }
  }
}

final availabilityControllerProvider =
    NotifierProvider<AvailabilityController, bool>(AvailabilityController.new);
