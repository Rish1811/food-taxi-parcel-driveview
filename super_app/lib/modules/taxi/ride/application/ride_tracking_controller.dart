import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superapp_user/modules/taxi/application/taxi_core_providers.dart';
import 'package:superapp_user/core/audio/taxi_audio_service.dart';
import 'package:superapp_user/core/realtime/taxi_socket_events.dart';
import 'package:superapp_user/core/realtime/taxi_socket_service.dart';
import 'package:superapp_user/modules/taxi/ride/data/models/ride_message_model.dart';
import 'package:superapp_user/modules/taxi/ride/data/models/ride_model.dart';
import 'package:superapp_user/modules/taxi/ride/application/ride_providers.dart';
import 'package:superapp_user/modules/taxi/ride/application/ride_tracking_state.dart';

class RideTrackingController extends Notifier<RideTrackingState> {
  RideTrackingController(this.rideId);

  final String rideId;
  late final TaxiSocketService _socket;
  Timer? _pollingTimer;

  /// Riverpod 3 notifiers expose no `mounted`; a poll in flight when the
  /// controller is torn down must not write to a disposed notifier.
  bool _disposed = false;

  /// Removes this controller's reconnect listener on teardown.
  late final void Function() _removeConnectionListener;

  @override
  RideTrackingState build() {
    _socket = ref.read(taxiSocketServiceProvider);
    _registerListeners();

    // Socket.IO rooms are per-connection: a reconnect gets a new socket id and
    // the server drops every room this client had joined. Re-joining here is
    // what stops a rider silently going deaf mid-trip after a network blip.
    _removeConnectionListener = _socket.addConnectionListener(_handleReconnected);
    _socket.joinRide(rideId);

    ref.onDispose(_teardown);

    // Deferred: build() must return synchronously, and it re-runs on
    // invalidation — firing the fetch inline would issue a duplicate request
    // and re-enter the notifier before it is registered.
    Future.microtask(_loadRide);
    _startPolling();

    return const RideTrackingState();
  }

  void _handleReconnected() {
    _socket.joinRide(rideId);
    _loadRide();
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      final r = state.ride;
      if (r != null && (r.isCompleted || r.isCancelled)) {
        _pollingTimer?.cancel();
        return;
      }
      _loadRideSilently();
    });
  }

  void _checkAudioTrigger(RideModel? ride) {
    if (ride == null) return;
    final status = ride.status.toLowerCase();
    final liveStatus = ride.liveStatus.toLowerCase();

    if (status == 'started' || status == 'ongoing' || liveStatus == 'started') {
      AudioService.playTripStarted();
    } else if (status == 'completed' || liveStatus == 'completed') {
      AudioService.playRideEnded();
    }
  }

  Future<void> _loadRide() async {
    try {
      final ride = await ref.read(rideRepositoryProvider).getRideById(rideId);
      state = state.copyWith(ride: ride, isLoading: false);
      _checkAudioTrigger(ride);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> _loadRideSilently() async {
    try {
      final ride = await ref.read(rideRepositoryProvider).getRideById(rideId);
      if (!_disposed) {
        state = state.copyWith(ride: ride);
        _checkAudioTrigger(ride);
      }
    } catch (_) {}
  }

  void _registerListeners() {
    _socket.on(SocketEvents.rideState, _handleRideState);
    _socket.on('ride:state', _handleRideState);

    _socket.on(SocketEvents.rideStatusUpdated, _handleStatusUpdated);
    _socket.on('ride:status:updated', _handleStatusUpdated);
    _socket.on('ride_status_updated', _handleStatusUpdated);
    _socket.on('driver_arrived', _handleDriverArrived);
    _socket.on('trip_started', _handleTripStarted);

    _socket.on(SocketEvents.rideDriverLocationUpdated, _handleDriverLocationUpdated);
    _socket.on('ride:driver-location:updated', _handleDriverLocationUpdated);

    _socket.on(SocketEvents.rideMessageNew, _handleNewMessage);
    _socket.on(SocketEvents.error, _handleSocketError);
  }

  void _handleRideState(dynamic data) {
    final map = _asMap(data);
    if (map == null) return;
    final payload = map['ride'] is Map ? Map<String, dynamic>.from(map['ride']) : map;
    if ((payload['rideId'] ?? payload['_id'] ?? payload['id'] ?? '').toString() != rideId) return;
    final ride = RideModel.fromJson(payload);
    state = state.copyWith(ride: ride, isLoading: false);
    _checkAudioTrigger(ride);
  }

  void _handleDriverArrived(dynamic data) {
    final map = _asMap(data);
    if (map != null && (map['rideId'] ?? '').toString() != rideId) return;
    final ride = state.ride;
    if (ride != null) {
      final updated = ride.copyWith(status: 'arrived', liveStatus: 'arrived');
      state = state.copyWith(ride: updated);
      _checkAudioTrigger(updated);
    }
    _loadRideSilently();
  }

  void _handleTripStarted(dynamic data) {
    final map = _asMap(data);
    if (map != null && (map['rideId'] ?? '').toString() != rideId) return;
    final ride = state.ride;
    if (ride != null) {
      final updated = ride.copyWith(status: 'started', liveStatus: 'started');
      state = state.copyWith(ride: updated);
      _checkAudioTrigger(updated);
    } else {
      AudioService.playTripStarted();
    }
    _loadRideSilently();
  }

  void _handleStatusUpdated(dynamic data) {
    final map = _asMap(data);
    if (map == null) return;
    final id = (map['rideId'] ?? map['_id'] ?? map['id'] ?? '').toString();
    if (id.isNotEmpty && id != rideId) return;

    final ride = state.ride;
    if (ride == null) {
      _loadRide();
      return;
    }

    DateTime? parseDate(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());
    final updated = ride.copyWith(
      status: map['status']?.toString() ?? ride.status,
      liveStatus: map['liveStatus']?.toString() ?? map['status']?.toString() ?? ride.liveStatus,
      acceptedAt: parseDate(map['acceptedAt']) ?? ride.acceptedAt,
      arrivedAt: parseDate(map['arrivedAt']) ?? ride.arrivedAt,
      startedAt: parseDate(map['startedAt']) ?? ride.startedAt,
      completedAt: parseDate(map['completedAt']) ?? ride.completedAt,
      driver: map['driver'] is Map && (map['driver'] as Map).isNotEmpty
          ? RideDriverInfo.fromJson(Map<String, dynamic>.from(map['driver']))
          : ride.driver,
    );
    state = state.copyWith(ride: updated);
    _checkAudioTrigger(updated);
  }

  void _handleDriverLocationUpdated(dynamic data) {
    final map = _asMap(data);
    final ride = state.ride;
    if (map == null || ride == null) return;
    final id = (map['rideId'] ?? map['_id'] ?? map['id'] ?? '').toString();
    if (id.isNotEmpty && id != rideId) return;

    final coords = map['coordinates'];
    final double? lat;
    final double? lng;
    if (coords is List && coords.length >= 2) {
      lng = double.tryParse('${coords[0]}');
      lat = double.tryParse('${coords[1]}');
    } else {
      lat = double.tryParse('${map['lat'] ?? map['latitude'] ?? ''}');
      lng = double.tryParse('${map['lng'] ?? map['longitude'] ?? ''}');
    }
    if (lat == null || lng == null) return;

    state = state.copyWith(
      ride: ride.copyWith(
        lastDriverLocation: LatLngPoint(lat: lat, lng: lng),
        lastDriverHeading: double.tryParse('${map['heading'] ?? ''}'),
      ),
    );
  }

  void _handleNewMessage(dynamic data) {
    final map = _asMap(data);
    final ride = state.ride;
    if (map == null || ride == null) return;
    if ((map['rideId'] ?? '').toString() != rideId) return;

    final message = RideMessageModel.fromJson(map);
    state = state.copyWith(ride: ride.copyWith(messages: [...ride.messages, message]));
  }

  void _handleSocketError(dynamic data) {
    final map = _asMap(data);
    state = state.copyWith(error: map?['message']?.toString() ?? 'Something went wrong');
  }

  Map<String, dynamic>? _asMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    return null;
  }

  void sendMessage(String message) {
    if (message.trim().isEmpty) return;
    _socket.sendRideMessage(rideId, message.trim());
  }

  Future<bool> cancelRide({String? reason}) async {
    state = state.copyWith(isCancelling: true, clearError: true);
    try {
      await ref.read(rideRepositoryProvider).cancelRide(rideId, reason: reason);
      state = state.copyWith(isCancelling: false);
      return true;
    } catch (e) {
      state = state.copyWith(isCancelling: false, error: e.toString());
      return false;
    }
  }

  Future<bool> submitReview({required int rating, String? comment, double tipAmount = 0}) async {
    try {
      await ref.read(rideRepositoryProvider).submitReview(
            rideId,
            rating: rating,
            comment: comment,
            tipAmount: tipAmount,
          );
      return true;
    } catch (e) {
      state = state.copyWith(error: e.toString());
      return false;
    }
  }

  void _teardown() {
    _disposed = true;
    _pollingTimer?.cancel();
    _socket.off(SocketEvents.rideState, _handleRideState);
    _socket.off('ride:state', _handleRideState);
    _socket.off(SocketEvents.rideStatusUpdated, _handleStatusUpdated);
    _socket.off('ride:status:updated', _handleStatusUpdated);
    _socket.off('ride_status_updated', _handleStatusUpdated);
    _socket.off('driver_arrived', _handleDriverArrived);
    _socket.off('trip_started', _handleTripStarted);
    _socket.off(SocketEvents.rideDriverLocationUpdated, _handleDriverLocationUpdated);
    _socket.off('ride:driver-location:updated', _handleDriverLocationUpdated);
    _socket.off(SocketEvents.rideMessageNew, _handleNewMessage);
    _socket.off(SocketEvents.error, _handleSocketError);
    _removeConnectionListener();
  }
}

final rideTrackingControllerProvider = NotifierProvider.family<RideTrackingController, RideTrackingState, String>(RideTrackingController.new);
