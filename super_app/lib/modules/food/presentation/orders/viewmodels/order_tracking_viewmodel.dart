import 'package:superapp_user/modules/food/presentation/orders/viewmodels/active_order_viewmodel.dart';
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/core/error/failures.dart';
import 'package:superapp_user/modules/food/data/models/active_order_rtdb_model.dart';
import 'package:superapp_user/modules/food/data/models/order_model.dart';
import 'package:superapp_user/modules/food/application/providers/order_providers.dart';
import 'package:superapp_user/modules/food/application/providers/socket_providers.dart';
import 'package:superapp_user/core/realtime/socket_service.dart';

void _trackingLog(String message) {
  if (kDebugMode) debugPrint('[TRACKING] $message');
}

class OrderTrackingState {
  final OrderModel? order;
  final bool isLoading;
  final String? error;

  /// Live rider position driven by Firebase RTDB active_orders node.
  final double? riderLat;
  final double? riderLng;
  final double heading;
  final double speed;
  final double accuracy;

  /// Waypoints and route polyline from RTDB.
  final double? restaurantLat;
  final double? restaurantLng;
  final double? customerLat;
  final double? customerLng;
  final String? polyline;
  final List<PointLatLng> routePoints;

  /// True once riderLat/riderLng came from an actual rider fix rather than a
  /// caller-side fallback. The map must not trim the route to a placeholder.
  final bool hasRiderFix;

  final int? lastUpdated;
  final bool isLocatingRider;
  final String? rtdbStatus;

  /// Handover OTP — shown only while required and unverified.
  final String? dropOtp;
  final bool socketConnected;

  const OrderTrackingState({
    this.order,
    this.isLoading = true,
    this.error,
    this.riderLat,
    this.riderLng,
    this.heading = 0.0,
    this.speed = 0.0,
    this.accuracy = 0.0,
    this.restaurantLat,
    this.restaurantLng,
    this.customerLat,
    this.customerLng,
    this.polyline,
    this.routePoints = const [],
    this.hasRiderFix = false,
    this.lastUpdated,
    this.isLocatingRider = false,
    this.rtdbStatus,
    this.dropOtp,
    this.socketConnected = false,
  });

  OrderTrackingState copyWith({
    OrderModel? order,
    bool? isLoading,
    String? error,
    double? riderLat,
    double? riderLng,
    double? heading,
    double? speed,
    double? accuracy,
    double? restaurantLat,
    double? restaurantLng,
    double? customerLat,
    double? customerLng,
    String? polyline,
    List<PointLatLng>? routePoints,
    bool? hasRiderFix,
    int? lastUpdated,
    bool? isLocatingRider,
    String? rtdbStatus,
    String? dropOtp,
    bool? socketConnected,
    bool clearError = false,
  }) {
    return OrderTrackingState(
      order: order ?? this.order,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      riderLat: riderLat ?? this.riderLat,
      riderLng: riderLng ?? this.riderLng,
      heading: heading ?? this.heading,
      speed: speed ?? this.speed,
      accuracy: accuracy ?? this.accuracy,
      restaurantLat: restaurantLat ?? this.restaurantLat,
      restaurantLng: restaurantLng ?? this.restaurantLng,
      customerLat: customerLat ?? this.customerLat,
      customerLng: customerLng ?? this.customerLng,
      polyline: polyline ?? this.polyline,
      routePoints: routePoints ?? this.routePoints,
      hasRiderFix: hasRiderFix ?? this.hasRiderFix,
      lastUpdated: lastUpdated ?? this.lastUpdated,
      isLocatingRider: isLocatingRider ?? this.isLocatingRider,
      rtdbStatus: rtdbStatus ?? this.rtdbStatus,
      dropOtp: dropOtp ?? this.dropOtp,
      socketConnected: socketConnected ?? this.socketConnected,
    );
  }
}

/// Live tracking for one order driven by Firebase Realtime Database.
final orderTrackingProvider =
    NotifierProvider<OrderTrackingViewModel, OrderTrackingState>(
  OrderTrackingViewModel.new,
);

class OrderTrackingViewModel extends Notifier<OrderTrackingState> {
  StreamSubscription<ActiveOrderRtdbModel?>? _rtdbSub;

  // Socket.IO (the one shared app-wide connection) is the primary live-location
  // source; RTDB supplies the server-precomputed route polyline that
  // location-update lacks. Both feed the same rider-position fields, so
  // whichever arrives moves the marker.
  StreamSubscription<OrderSocketMessage>? _socketSub;

  // Sockets are an optimisation, not the contract — this polls REST every
  // ~10s as a fallback for whenever the shared socket is disconnected, so the
  // screen never needs a manual pull-to-refresh to stay current.
  Timer? _pollTimer;

  // Refetches the road route from the rider's CURRENT position every 30s, the same
  // cadence the rider app uses. Without this the map drew the RTDB polyline, which
  // the server computes once at accept time as restaurant→customer and never
  // re-cuts: before pickup that is a route the rider is not on, and after pickup it
  // never follows them.
  Timer? _routeTimer;

  /// Once the REST route endpoint has answered, its polyline wins. The RTDB one is
  /// the stale accept-time geometry, so letting it keep overwriting would undo the
  /// fix on the next RTDB tick. RTDB is still used for the rider's position.
  bool _hasRestRoute = false;

  /// Guards against a stampede: the route is now requested eagerly from several
  /// triggers (start, rider assigned, first movement, status change, timer).
  bool _routeFetchInFlight = false;

  /// When Socket.IO last delivered a rider position.
  ///
  /// The socket outranks the other sources while it is genuinely live, being
  /// near real-time where the route origin is up to 12s behind. But that
  /// authority has to EXPIRE: this was a plain bool, so the first socket ping
  /// disabled every fallback permanently — and if the socket then dropped
  /// mid-trip (backgrounded app, flaky data, a tunnel) the marker froze for the
  /// rest of the delivery with nothing able to move it again.
  DateTime? _lastSocketFixAt;

  /// How long a socket fix keeps precedence. Comfortably longer than the rider
  /// app's ~4s ping throttle, so ordinary jitter does not flip authority about.
  static const _socketFixTtl = Duration(seconds: 20);

  bool get _socketFixIsFresh {
    final at = _lastSocketFixAt;
    return at != null && DateTime.now().difference(at) < _socketFixTtl;
  }

  String _orderId = '';

  @override
  OrderTrackingState build() {
    ref.onDispose(_teardown);
    return const OrderTrackingState();
  }

  /// Seeds the order once over REST, attaches ONE RTDB listener for the route,
  /// and joins the shared socket's tracking room for live location + status.
  Future<void> start(String orderId) async {
    if (_orderId == orderId && (_rtdbSub != null || _socketSub != null)) return;
    _teardown();
    _orderId = orderId;
    state = const OrderTrackingState();

    // 1. Seed once over REST.
    await refresh();

    final currentOrder = state.order;
    if (currentOrder != null && currentOrder.id.isNotEmpty) {
      // 2. RTDB for the route polyline + a location fallback.
      _subscribeRtdb(currentOrder.id);
      // 3. Shared socket for live location-update + order_status_update.
      _joinSocket(currentOrder.id);
      // 4. REST fallback poll, in case both of the above stay silent.
      // 4s, not 10s. This is the only position source when the socket is down, and
      // a 10s gap is what made the rider look almost stationary while their own app
      // showed them moving. GET /orders/:id measures ~31ms, so the extra calls are
      // cheap, and this only runs while the socket is actually disconnected.
      _pollTimer ??= Timer.periodic(const Duration(seconds: 4), (_) {
        if (!ref.read(socketServiceProvider).isConnected) refresh();
      });
      // 5. Road route from the rider's live position — same 30s cadence as the
      //    rider app, which is why that map looks right and this one didn't.
      unawaited(_fetchRoute());
      // 12s, not 30s. The route is what wipes behind the rider between socket
      // pings, and a 30s hold made the line look frozen and slow to appear.
      _routeTimer ??= Timer.periodic(const Duration(seconds: 8), (_) {
        unawaited(_fetchRoute());
      });
    }
  }

  /// Pulls the current leg's road route. Silent on failure: the RTDB polyline
  /// stays as the fallback, so a flaky route call degrades to the old behaviour
  /// rather than clearing the line off the map.
  Future<void> _fetchRoute() async {
    if (_orderId.isEmpty || _routeFetchInFlight) return;
    _routeFetchInFlight = true;
    try {
      final data = await ref.read(orderRemoteDataSourceProvider).getRoute(_orderId);

      // Position first, and independently of the geometry. `origin` is where the
      // backend believes the rider is (their last ping); before pickup nothing else
      // tells the customer that, since the order's lastRiderLocation is unset and
      // the RTDB node still holds the accept-time restaurant coordinates. Reading
      // it after the unchanged-geometry early return meant a stationary route
      // stopped refreshing the marker too.
      //
      // Skipped once the socket is feeding us positions: those are near real-time,
      // so applying a 12s-old origin over them would jerk the bike backwards.
      final origin = data['origin'];
      final oLat = origin is Map ? (origin['lat'] as num?)?.toDouble() : null;
      final oLng = origin is Map ? (origin['lng'] as num?)?.toDouble() : null;
      if (!_socketFixIsFresh && oLat != null && oLng != null) {
        state = state.copyWith(riderLat: oLat, riderLng: oLng, hasRiderFix: true);
      }

      final encoded = data['polyline']?.toString() ?? '';
      if (encoded.isEmpty) {
        _trackingLog('Route endpoint returned no polyline yet');
        return;
      }
      if (encoded == state.polyline) return; // unchanged — skip the decode
      final points = _decodePolyline(encoded);
      if (points.length < 2) return;
      _hasRestRoute = true;

      _trackingLog(
        'Route endpoint: target=${data['target']} '
        '${points.length} points, ${data['durationMins']} mins, '
        'origin=$oLat,$oLng',
      );
      state = state.copyWith(polyline: encoded, routePoints: points);
    } catch (e) {
      _trackingLog('Route fetch failed ($e) — keeping existing route');
    } finally {
      _routeFetchInFlight = false;
    }
  }

  /// Stops all live subscriptions — call from the screen's dispose.
  void stop() => _teardown();

  void _joinSocket(String orderId) {
    final service = ref.read(socketServiceProvider);
    service.joinTracking(orderId);

    _socketSub = service.orderEvents.listen((message) {
      if (message.orderId != null && message.orderId != _orderId) return;
      switch (message.event) {
        case OrderSocketEvent.riderMoved:
          final lat = message.lat;
          final lng = message.lng;
          if (lat != null && lng != null) {
            // Only the marker position changes here — the polyline is never
            // touched on a location update.
            state = state.copyWith(
              riderLat: lat,
              riderLng: lng,
              heading: message.heading,
              hasRiderFix: true,
              isLocatingRider: false,
              socketConnected: true,
            );
            _lastSocketFixAt = DateTime.now();
            // First sign of the rider and still no line — ask immediately rather
            // than waiting out the timer.
            if (state.routePoints.isEmpty) unawaited(_fetchRoute());
          }
        case OrderSocketEvent.dropOtp:
          final otp = message.otp;
          if (otp != null) state = state.copyWith(dropOtp: otp, socketConnected: true);
        case OrderSocketEvent.statusUpdate:
        case OrderSocketEvent.orderReady:
          // REST is authoritative for the normalized order — refetch rather
          // than patch from the socket payload.
          state = state.copyWith(socketConnected: true);
          unawaited(refresh());
          // A status change can flip the route target (restaurant -> customer at
          // pickup), so don't wait up to 30s for the next tick.
          unawaited(_fetchRoute());
      }
    });
  }

  Future<void> refresh() async {
    try {
      final order = await ref.read(orderRemoteDataSourceProvider).getOrderModel(_orderId);
      state = state.copyWith(
        order: order,
        isLoading: false,
        clearError: true,
        // order.riderLat comes from lastRiderLocation — genuine when set, but do
        // not let it clobber a fresher fix we already hold.
        riderLat: state.hasRiderFix ? state.riderLat : (order.riderLat ?? state.riderLat),
        riderLng: state.hasRiderFix ? state.riderLng : (order.riderLng ?? state.riderLng),
        hasRiderFix: state.hasRiderFix || order.riderLat != null,
        restaurantLat: order.restaurantLat ?? state.restaurantLat,
        restaurantLng: order.restaurantLng ?? state.restaurantLng,
        customerLat: order.dropLat ?? state.customerLat,
        customerLng: order.dropLng ?? state.customerLng,
      );

      // A rider just got assigned, or we still have no line — ask now. Assignment
      // does not always arrive as a socket status change, so waiting for the timer
      // was what made the polyline appear seconds late.
      if (order.hasRider && state.routePoints.isEmpty) unawaited(_fetchRoute());

      // Pull the handover OTP whenever one is still outstanding — not just the
      // first time. This used to latch on `state.dropOtp == null`, so once a
      // code had been shown the screen kept displaying it no matter what the
      // server held. If the stored code ever moved, the customer read out a
      // dead number and the rider could not complete the drop. The endpoint is
      // authoritative, so re-reading it is what makes the screen self-correct.
      if (order.showDropOtp) {
        unawaited(_fetchDropOtp());
      }

      if (!order.isActive) {
        _teardown();
        unawaited(ref.read(activeOrderViewModelProvider.notifier).fetchActiveOrder());
      }
    } on Failure catch (f) {
      state = state.copyWith(isLoading: false, error: f.message);
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Could not load tracking details.');
    }
  }

  void _subscribeRtdb(String orderMongoId) {
    _rtdbSub?.cancel();
    _trackingLog('Subscribing RTDB route/location for order $orderMongoId');
    final rtdb = ref.read(orderRtdbDataSourceProvider);

    _rtdbSub = rtdb.watchActiveOrder(orderMongoId).listen((rtdbData) {
      if (rtdbData == null) {
        _trackingLog('RTDB update: no data (node missing or order not yet picked up)');
        state = state.copyWith(isLocatingRider: true, socketConnected: false);
        return;
      }

      List<PointLatLng>? decodedPoints = state.routePoints;
      final newPolyline = rtdbData.polyline;
      if (_hasRestRoute) {
        // The route endpoint owns the GEOMETRY once it has answered, but this
        // tick still carries a position worth having.
        //
        // RTDB seeds boy_lat/boy_lng with the RESTAURANT's coordinates at accept
        // time, so it cannot be trusted before the rider actually pings — but
        // once they do, the backend writes their real pings here. Gating on
        // hasRiderFix meant RTDB was locked out FOREVER after the first fix from
        // any source, so with the socket down the marker had nothing left to move
        // it. Take a live, non-stale RTDB position unless the socket is fresher.
        final rtdbHasLiveFix =
            rtdbData.lat != null && rtdbData.lng != null && !rtdbData.isStale;
        final useRtdbPosition = rtdbHasLiveFix && !_socketFixIsFresh;

        state = state.copyWith(
          riderLat: useRtdbPosition ? rtdbData.lat : state.riderLat,
          riderLng: useRtdbPosition ? rtdbData.lng : state.riderLng,
          hasRiderFix: state.hasRiderFix || rtdbHasLiveFix,
          heading: rtdbData.heading,
          speed: rtdbData.speed,
          accuracy: rtdbData.accuracy,
          restaurantLat: rtdbData.restaurantLat ?? state.restaurantLat,
          restaurantLng: rtdbData.restaurantLng ?? state.restaurantLng,
          customerLat: rtdbData.customerLat ?? state.customerLat,
          customerLng: rtdbData.customerLng ?? state.customerLng,
          lastUpdated: rtdbData.lastUpdated ?? state.lastUpdated,
          isLocatingRider: rtdbData.isStale,
          rtdbStatus: rtdbData.status,
          socketConnected: true,
          clearError: true,
        );
        return;
      }
      if (newPolyline == null || newPolyline.isEmpty) {
        _trackingLog('RTDB update: polyline not populated yet for this order');
      } else if (newPolyline == state.polyline) {
        _trackingLog('RTDB update: polyline unchanged (${newPolyline.length} chars) — not re-decoding');
      } else {
        try {
          decodedPoints = _decodePolyline(newPolyline);
          _trackingLog(
            'RTDB update: new polyline (${newPolyline.length} chars) decoded to ${decodedPoints.length} points'
            '${decodedPoints.isNotEmpty ? ' — first=${decodedPoints.first.latitude},${decodedPoints.first.longitude} last=${decodedPoints.last.latitude},${decodedPoints.last.longitude}' : ''}',
          );
        } catch (e) {
          _trackingLog('RTDB update: polyline decode FAILED: $e — keeping previous route');
        }
      }

      state = state.copyWith(
      // RTDB seeds boy_lat/boy_lng with the RESTAURANT's coordinates at accept
      // time, so it is only a position source until something real arrives.
      riderLat: state.hasRiderFix ? state.riderLat : (rtdbData.lat ?? state.riderLat),
      riderLng: state.hasRiderFix ? state.riderLng : (rtdbData.lng ?? state.riderLng),
        heading: rtdbData.heading,
        speed: rtdbData.speed,
        accuracy: rtdbData.accuracy,
        restaurantLat: rtdbData.restaurantLat ?? state.restaurantLat,
        restaurantLng: rtdbData.restaurantLng ?? state.restaurantLng,
        customerLat: rtdbData.customerLat ?? state.customerLat,
        customerLng: rtdbData.customerLng ?? state.customerLng,
        polyline: newPolyline ?? state.polyline,
        routePoints: decodedPoints,
        lastUpdated: rtdbData.lastUpdated ?? state.lastUpdated,
        isLocatingRider: rtdbData.isStale,
        rtdbStatus: rtdbData.status,
        socketConnected: true,
        clearError: true,
      );
    });
  }

  Future<void> _fetchDropOtp() async {
    try {
      final otp = await ref.read(orderRemoteDataSourceProvider).getDropOtp(_orderId);
      if (otp != null) state = state.copyWith(dropOtp: otp);
    } catch (_) {
      // Non-fatal
    }
  }

  Future<String?> cancel({String? reason}) async {
    try {
      await ref.read(orderRemoteDataSourceProvider).cancelOrder(_orderId, reason: reason);
      await refresh();
      return null;
    } on Failure catch (f) {
      return f.message;
    } catch (_) {
      return 'Could not cancel this order.';
    }
  }

  void _teardown() {
    _rtdbSub?.cancel();
    _rtdbSub = null;
    _socketSub?.cancel();
    _socketSub = null;
    _pollTimer?.cancel();
    _pollTimer = null;
    _routeTimer?.cancel();
    _routeTimer = null;
    _hasRestRoute = false;
    _lastSocketFixAt = null;
    _routeFetchInFlight = false;
    if (_orderId.isNotEmpty) ref.read(socketServiceProvider).leaveTracking(_orderId);
  }
}

/// Decodes an encoded Google Polyline string into a list of [PointLatLng] coordinates.
List<PointLatLng> _decodePolyline(String encoded) {
  final List<PointLatLng> poly = [];
  int index = 0;
  final int len = encoded.length;
  int lat = 0;
  int lng = 0;

  while (index < len) {
    int b;
    int shift = 0;
    int result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final int dlat = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lat += dlat;

    shift = 0;
    result = 0;
    do {
      b = encoded.codeUnitAt(index++) - 63;
      result |= (b & 0x1f) << shift;
      shift += 5;
    } while (b >= 0x20);
    final int dlng = (result & 1) != 0 ? ~(result >> 1) : (result >> 1);
    lng += dlng;

    poly.add(PointLatLng(lat / 1E5, lng / 1E5));
  }
  return poly;
}
