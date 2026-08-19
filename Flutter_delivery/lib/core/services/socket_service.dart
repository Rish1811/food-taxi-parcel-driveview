import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;

import '../constants/app_constants.dart';

/// Wraps the Socket.IO connection to the delivery backend and exposes
/// broadcast streams for the events documented in the realtime section
/// of DELIVERY_API_SPEC.md. Polling `/orders/available` remains the
/// required fallback — this is a convenience layer on top, not a
/// replacement for it.
class SocketService {
  io.Socket? _socket;

  final _newOrderController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _orderClaimedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _orderDeassignedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _orderReadyController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _orderStatusUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _locationUpdateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _chatMessageController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _chatTypingController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _connectionController = StreamController<bool>.broadcast();

  // ── Taxi dispatch ─────────────────────────────────────────────────
  // Emitted by the taxi dispatcher into the driver's own room. Unlike the
  // food events these are namespaced camelCase, because they come from the
  // taxi module's socket layer rather than the food one.
  final _rideRequestController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _rideRequestClosedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _rideStateController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _rideAcceptedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final _socketErrorController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onNewOrderAvailable =>
      _newOrderController.stream;
  Stream<Map<String, dynamic>> get onOrderClaimed =>
      _orderClaimedController.stream;
  Stream<Map<String, dynamic>> get onOrderDeassigned =>
      _orderDeassignedController.stream;
  Stream<Map<String, dynamic>> get onOrderReady => _orderReadyController.stream;
  Stream<Map<String, dynamic>> get onOrderStatusUpdate =>
      _orderStatusUpdateController.stream;
  Stream<Map<String, dynamic>> get onLocationUpdate =>
      _locationUpdateController.stream;
  Stream<Map<String, dynamic>> get onChatMessage =>
      _chatMessageController.stream;
  Stream<Map<String, dynamic>> get onChatTyping =>
      _chatTypingController.stream;
  Stream<bool> get onConnectionChange => _connectionController.stream;

  /// A ride is being offered to this driver. Carries the full offer — pickup,
  /// drop, fare and the accept window — so the alert can be raised without a
  /// round trip.
  Stream<Map<String, dynamic>> get onRideRequest =>
      _rideRequestController.stream;

  /// The offer is gone: taken by another driver, cancelled by the passenger,
  /// or the accept window expired.
  Stream<Map<String, dynamic>> get onRideRequestClosed =>
      _rideRequestClosedController.stream;

  /// Server-side movement on a ride this driver already holds — chiefly a
  /// passenger cancellation mid-trip.
  Stream<Map<String, dynamic>> get onRideState => _rideStateController.stream;

  /// This driver won the ride. Emitted only to the socket that claimed it.
  Stream<Map<String, dynamic>> get onRideAccepted =>
      _rideAcceptedController.stream;

  /// The taxi module reports every failed socket operation on one channel,
  /// including losing an accept race — there is no per-call ack.
  Stream<Map<String, dynamic>> get onSocketError =>
      _socketErrorController.stream;

  bool get isConnected => _socket?.connected ?? false;

  void connect({required String accessToken, required String partnerId}) {
    disconnect();

    _socket = io.io(
      AppConstants.apiHost,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': accessToken})
          .enableReconnection()
          .disableAutoConnect()
          .build(),
    );

    final socket = _socket!;

    socket.onConnect((_) {
      _connectionController.add(true);
      socket.emit('join-delivery', partnerId);
    });
    socket.onDisconnect((_) => _connectionController.add(false));
    socket.onConnectError((_) => _connectionController.add(false));

    socket.on(
      'new_order_available',
      (data) => _newOrderController.add(_asMap(data)),
    );
    // Primary dispatch broadcasts use 'new_order'; re-offer rounds use
    // 'new_order_available' — both feed the same incoming-order stream.
    socket.on('new_order', (data) => _newOrderController.add(_asMap(data)));
    socket.on('order_claimed', (data) => _orderClaimedController.add(_asMap(data)));
    socket.on(
      'order_deassigned',
      (data) => _orderDeassignedController.add(_asMap(data)),
    );
    socket.on('order_ready', (data) => _orderReadyController.add(_asMap(data)));
    socket.on(
      'order_status_update',
      (data) => _orderStatusUpdateController.add(_asMap(data)),
    );
    socket.on(
      'location-update',
      (data) => _locationUpdateController.add(_asMap(data)),
    );
    socket.on(
      'chat:message',
      (data) => _chatMessageController.add(_asMap(data)),
    );
    socket.on(
      'chat:typing',
      (data) => _chatTypingController.add(_asMap(data)),
    );

    socket.on('rideRequest', (data) => _rideRequestController.add(_asMap(data)));
    socket.on(
      'rideRequestClosed',
      (data) => _rideRequestClosedController.add(_asMap(data)),
    );
    socket.on('ride:state', (data) => _rideStateController.add(_asMap(data)));
    socket.on(
      'rideAccepted',
      (data) => _rideAcceptedController.add(_asMap(data)),
    );
    socket.on(
      'errorMessage',
      (data) => _socketErrorController.add(_asMap(data)),
    );
    socket.on(
      'rideCancelled',
      (data) => _rideStateController.add({..._asMap(data), 'status': 'cancelled'}),
    );

    socket.connect();
  }

  /// Ride-scoped events (`ride:state`, chat) are only delivered to sockets that
  /// have joined the ride room; the driver room alone is not enough.
  ///
  /// Rooms are per-connection, so this has to be re-sent after every reconnect
  /// — see the connection listener in the active-ride controller.
  void joinRide(String rideId) => _socket?.emit('ride:join', {'rideId': rideId});

  /// Claims an offered ride.
  ///
  /// Socket-only by design on the backend: acceptance is a first-wins
  /// transaction against a ride this driver does not yet hold, so there is no
  /// REST equivalent — `PATCH /rides/:id/status` looks the ride up by
  /// `{_id, driverId}` and 404s until the claim has already succeeded.
  ///
  /// Success arrives on [onRideAccepted], loss on [onSocketError].
  void acceptRide(String rideId) => _socket?.emit('acceptRide', {'rideId': rideId});

  /// Declines an offer so dispatch can move to the next driver immediately
  /// rather than waiting out the accept window.
  void rejectRide(String rideId) => _socket?.emit('rejectRide', {'rideId': rideId});

  /// Keeps this driver's position current in the taxi matching index, which is
  /// what decides whether they are inside the dispatch radius at all. Send it
  /// whenever online, ride or no ride.
  ///
  /// Coordinates are GeoJSON order — `[lng, lat]`. The server rejects the pair
  /// outright if it is the wrong way round only when it falls outside valid
  /// ranges, so most of India would be silently accepted and mislocated.
  void sendDriverLocation({required double lat, required double lng}) {
    _socket?.emit('locationUpdate', {
      'coordinates': [lng, lat],
    });
  }

  /// Live position *within a ride*, which is what moves the marker on the
  /// passenger's map. Requires [joinRide] first.
  void sendRideDriverLocation({
    required String rideId,
    required double lat,
    required double lng,
    double? heading,
    double? speed,
  }) {
    _socket?.emit('ride:driver-location:update', {
      'rideId': rideId,
      'coordinates': [lng, lat],
      if (heading != null) 'heading': heading,
      if (speed != null) 'speed': speed,
    });
  }

  void joinTracking(String orderId) => _socket?.emit('join-tracking', orderId);

  void leaveTracking(String orderId) =>
      _socket?.emit('leave-tracking', orderId);

  void sendLocationUpdate({
    required String orderId,
    required double lat,
    required double lng,
    String? userId,
    String? restaurantId,
    double? heading,
    double? speed,
    double? accuracy,
  }) {
    _socket?.emit('update-location', {
      'orderId': orderId,
      'lat': lat,
      'lng': lng,
      if (userId != null) 'userId': userId,
      if (restaurantId != null) 'restaurantId': restaurantId,
      if (heading != null) 'heading': heading,
      if (speed != null) 'speed': speed,
      if (accuracy != null) 'accuracy': accuracy,
    });
  }

  void sendChatTyping({
    required String toRole,
    String? toId,
    required String conversationId,
    required bool typing,
  }) {
    _socket?.emit('chat:typing', {
      'toRole': toRole,
      if (toId != null) 'toId': toId,
      'conversationId': conversationId,
      'typing': typing,
    });
  }

  void disconnect() {
    _socket?.dispose();
    _socket = null;
  }

  void dispose() {
    disconnect();
    _newOrderController.close();
    _orderClaimedController.close();
    _orderDeassignedController.close();
    _orderReadyController.close();
    _orderStatusUpdateController.close();
    _locationUpdateController.close();
    _chatMessageController.close();
    _chatTypingController.close();
    _connectionController.close();
    _rideRequestController.close();
    _rideRequestClosedController.close();
    _rideStateController.close();
    _rideAcceptedController.close();
    _socketErrorController.close();
  }

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map<String, dynamic>) return data;
    if (data is Map) return Map<String, dynamic>.from(data);
    return <String, dynamic>{};
  }
}

final socketServiceProvider = Provider<SocketService>((ref) {
  final service = SocketService();
  ref.onDispose(service.dispose);
  return service;
});
