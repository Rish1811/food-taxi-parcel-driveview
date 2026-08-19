import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Server-side ride lifecycle (`RIDE_LIVE_STATUS` in the k9 backend).
///
/// The driver drives the transitions with
/// `PATCH /taxi/rides/:rideId/status { status }`, which accepts only
/// accepted / arriving / arrived / started / completed.
enum RideStage {
  /// Dispatch is still offering the ride; no driver has taken it.
  searching,

  /// This driver took it. Next step is to head to the pickup.
  accepted,

  /// En route to the pickup, and waiting there once they arrive.
  arriving,

  /// Passenger on board, trip in progress.
  ///
  /// Note the ordering: in k9 `started` is the **pickup** and comes *before*
  /// `arrived`. Entering it requires the passenger's OTP.
  started,

  /// Reached the destination. The trip has run; the fare is not settled yet.
  arrived,

  /// Dropped off and paid.
  completed,

  cancelled;

  static RideStage parse(String? raw) {
    switch ((raw ?? '').trim().toLowerCase()) {
      case 'accepted':
        return RideStage.accepted;
      case 'arriving':
        return RideStage.arriving;
      case 'arrived':
        return RideStage.arrived;
      case 'started':
      case 'ongoing':
        return RideStage.started;
      case 'completed':
        return RideStage.completed;
      case 'cancelled':
      case 'canceled':
        return RideStage.cancelled;
      default:
        return RideStage.searching;
    }
  }

  /// Wire value for the status endpoint.
  String get wire => name;

  bool get isActive =>
      this == RideStage.accepted ||
      this == RideStage.arriving ||
      this == RideStage.arrived ||
      this == RideStage.started;

  bool get isFinished =>
      this == RideStage.completed || this == RideStage.cancelled;

  /// True once the passenger is in the car, which is what decides whether the
  /// driver is navigating to the pickup or to the drop.
  bool get isOnBoard => this == RideStage.started || this == RideStage.arrived;

  /// The single transition the driver can make from here, or null at the end
  /// of the flow. Keeping this on the enum stops each screen inventing its own
  /// idea of what "next" means — and this sequence is not the obvious one:
  /// `started` (pickup) precedes `arrived` (reached the destination).
  ///
  /// `searching` maps to nothing: an offer is claimed over the socket, not by
  /// a status transition, because acceptance has to be an atomic first-wins
  /// claim rather than a write to a ride this driver does not yet hold.
  RideStage? get next {
    switch (this) {
      case RideStage.accepted:
        return RideStage.arriving;
      case RideStage.arriving:
        return RideStage.started;
      case RideStage.started:
        return RideStage.arrived;
      case RideStage.arrived:
        return RideStage.completed;
      case RideStage.searching:
      case RideStage.completed:
      case RideStage.cancelled:
        return null;
    }
  }

  /// The backend refuses to start a ride without the OTP the passenger reads
  /// out — that is the only proof the right person got in the car.
  bool get nextNeedsOtp => next == RideStage.started;

  /// The last step settles the fare and cannot be undone from the app.
  bool get nextSettlesFare => next == RideStage.completed;

  /// Label for the primary action button.
  String get actionLabel {
    switch (this) {
      case RideStage.searching:
        return 'Accept ride';
      case RideStage.accepted:
        return 'Start navigation';
      case RideStage.arriving:
        return 'Passenger picked up';
      case RideStage.started:
        return 'Reached destination';
      case RideStage.arrived:
        return 'Complete trip';
      case RideStage.completed:
      case RideStage.cancelled:
        return 'Done';
    }
  }

  String get headline {
    switch (this) {
      case RideStage.searching:
        return 'New ride request';
      case RideStage.accepted:
        return 'Head to pickup';
      case RideStage.arriving:
        return 'On the way to pickup';
      case RideStage.started:
        return 'Trip in progress';
      case RideStage.arrived:
        return 'At the destination';
      case RideStage.completed:
        return 'Trip completed';
      case RideStage.cancelled:
        return 'Ride cancelled';
    }
  }
}

/// The passenger, as far as the driver needs to know.
class RidePassenger {
  const RidePassenger({
    required this.id,
    required this.name,
    required this.phone,
  });

  final String id;
  final String name;
  final String phone;

  factory RidePassenger.fromJson(Map<String, dynamic>? json) {
    final j = json ?? const {};
    return RidePassenger(
      id: (j['id'] ?? j['_id'] ?? '').toString(),
      name: (j['name'] ?? 'Customer').toString(),
      phone: (j['phone'] ?? '').toString(),
    );
  }
}

/// A ride, whether it is being offered or already in progress.
///
/// The dispatch socket payload (`rideRequest`) and the REST ride document use
/// overlapping but not identical shapes, so both are parsed here rather than
/// having two near-duplicate models drift apart.
class TaxiRide {
  const TaxiRide({
    required this.id,
    required this.stage,
    required this.passenger,
    required this.pickupAddress,
    required this.dropAddress,
    this.pickup,
    this.drop,
    this.fare = 0,
    this.distanceMeters = 0,
    this.durationMinutes = 0,
    this.paymentMethod = 'cash',
    this.otp,
    this.vehicleTypeName = '',
    this.serviceType = 'ride',
    this.expiresInSeconds,
  });

  final String id;
  final RideStage stage;
  final RidePassenger passenger;
  final String pickupAddress;
  final String dropAddress;
  final LatLng? pickup;
  final LatLng? drop;
  final double fare;
  final int distanceMeters;
  final int durationMinutes;
  final String paymentMethod;

  /// Start OTP, when the payload carries one.
  ///
  /// Never shown to the driver: the passenger reads it out and the driver types
  /// it in, which is what makes it proof the right person got in the car.
  /// Displaying it here would reduce it to a formality.
  final String? otp;

  final String vehicleTypeName;

  /// `ride` or `delivery` — dispatch uses one channel for both.
  final String serviceType;

  /// Only present on an offer: how long the driver has to accept.
  final int? expiresInSeconds;

  bool get isCash => paymentMethod.toLowerCase() == 'cash';

  double get distanceKm => distanceMeters / 1000.0;

  TaxiRide copyWith({RideStage? stage, String? otp}) => TaxiRide(
        id: id,
        stage: stage ?? this.stage,
        passenger: passenger,
        pickupAddress: pickupAddress,
        dropAddress: dropAddress,
        pickup: pickup,
        drop: drop,
        fare: fare,
        distanceMeters: distanceMeters,
        durationMinutes: durationMinutes,
        paymentMethod: paymentMethod,
        otp: otp ?? this.otp,
        vehicleTypeName: vehicleTypeName,
        serviceType: serviceType,
        expiresInSeconds: expiresInSeconds,
      );

  /// GeoJSON is `[lng, lat]` — reversing these silently puts every pickup in
  /// the wrong hemisphere, so it is done in exactly one place.
  static LatLng? _point(dynamic value) {
    if (value is Map) {
      final coords = value['coordinates'];
      if (coords is List && coords.length >= 2) {
        final lng = (coords[0] as num?)?.toDouble();
        final lat = (coords[1] as num?)?.toDouble();
        if (lat != null && lng != null) return LatLng(lat, lng);
      }
      final lat = (value['lat'] ?? value['latitude']) as num?;
      final lng = (value['lng'] ?? value['longitude']) as num?;
      if (lat != null && lng != null) {
        return LatLng(lat.toDouble(), lng.toDouble());
      }
    }
    return null;
  }

  static double _num(dynamic v) => (v as num?)?.toDouble() ?? 0;
  static int _int(dynamic v) => (v as num?)?.toInt() ?? 0;

  /// Parses both the `rideRequest` socket payload and a REST ride document.
  factory TaxiRide.fromJson(Map<String, dynamic> json) {
    final ride = json['ride'] is Map<String, dynamic>
        ? json['ride'] as Map<String, dynamic>
        : json;

    return TaxiRide(
      id: (ride['rideId'] ?? ride['_id'] ?? ride['id'] ?? '').toString(),
      // An offer carries no status; it is by definition still searching.
      stage: RideStage.parse(
        (ride['liveStatus'] ?? ride['status'])?.toString(),
      ),
      passenger: RidePassenger.fromJson(
        ride['user'] as Map<String, dynamic>? ??
            ride['userId'] as Map<String, dynamic>?,
      ),
      pickupAddress: (ride['pickupAddress'] ?? '').toString(),
      dropAddress: (ride['dropAddress'] ?? '').toString(),
      pickup: _point(ride['pickupLocation']),
      drop: _point(ride['dropLocation']),
      fare: _num(ride['fare'] ?? ride['baseFare']),
      distanceMeters: _int(ride['estimatedDistanceMeters']),
      durationMinutes: _int(ride['estimatedDurationMinutes']),
      paymentMethod: (ride['paymentMethod'] ?? 'cash').toString(),
      otp: ride['otp']?.toString(),
      vehicleTypeName: (ride['vehicleTypeName'] ?? ride['vehicleIconType'] ?? '')
          .toString(),
      serviceType: (ride['serviceType'] ?? ride['type'] ?? 'ride').toString(),
      expiresInSeconds: (ride['expiresInSeconds'] as num?)?.toInt(),
    );
  }
}
