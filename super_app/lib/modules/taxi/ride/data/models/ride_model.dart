import 'package:superapp_user/modules/taxi/ride/data/models/ride_message_model.dart';

class LatLngPoint {
  final double lat;
  final double lng;
  const LatLngPoint({required this.lat, required this.lng});

  factory LatLngPoint.fromGeoJson(dynamic geo) {
    if (geo is Map && geo['coordinates'] is List && geo['coordinates'].length == 2) {
      final coords = geo['coordinates'] as List;
      return LatLngPoint(
        lat: double.tryParse('${coords[1]}') ?? 0,
        lng: double.tryParse('${coords[0]}') ?? 0,
      );
    }
    return const LatLngPoint(lat: 0, lng: 0);
  }
}

class RideDriverInfo {
  final String id;
  final String name;
  final String phone;
  final String profileImage;
  final String vehicleNumber;
  final String vehicleModel;
  final String vehicleMake;
  final double rating;

  const RideDriverInfo({
    required this.id,
    required this.name,
    required this.phone,
    required this.profileImage,
    required this.vehicleNumber,
    required this.vehicleModel,
    required this.vehicleMake,
    required this.rating,
  });

  factory RideDriverInfo.fromJson(Map<String, dynamic> json) {
    return RideDriverInfo(
      id: (json['_id'] ?? json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString(),
      phone: (json['phone'] ?? '').toString(),
      profileImage: (json['profileImage'] ?? '').toString(),
      vehicleNumber: (json['vehicleNumber'] ?? '').toString(),
      vehicleModel: (json['vehicleModel'] ?? '').toString(),
      vehicleMake: (json['vehicleMake'] ?? '').toString(),
      rating: double.tryParse('${json['rating'] ?? 0}') ?? 0,
    );
  }
}

class RideStopPoint {
  final LatLngPoint location;
  final String address;
  const RideStopPoint({required this.location, required this.address});

  factory RideStopPoint.fromJson(Map<String, dynamic> json) {
    double lat = 0;
    double lng = 0;
    if (json['lat'] != null) lat = double.tryParse('${json['lat']}') ?? 0;
    if (json['lng'] != null) lng = double.tryParse('${json['lng']}') ?? 0;
    if (lat == 0 && json['location'] != null) {
      final p = LatLngPoint.fromGeoJson(json['location']);
      lat = p.lat;
      lng = p.lng;
    }
    return RideStopPoint(
      location: LatLngPoint(lat: lat, lng: lng),
      address: (json['address'] ?? json['name'] ?? '').toString(),
    );
  }
}

class RideModel {
  final String rideId;
  final String status;
  final String liveStatus;
  final double fare;
  final double baseFare;
  final double estimatedDistanceMeters;
  final double estimatedDurationMinutes;
  final String? paymentMethod;
  /// Encoded route for the current leg, resolved server-side.
  final String routePolyline;
  final String otp;
  final LatLngPoint pickup;
  final String pickupAddress;
  final LatLngPoint drop;
  final String dropAddress;
  final List<RideStopPoint> stops;
  final DateTime? scheduledAt;
  final DateTime? acceptedAt;
  final DateTime? arrivedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final RideDriverInfo? driver;
  final LatLngPoint? lastDriverLocation;
  final double? lastDriverHeading;
  final List<RideMessageModel> messages;
  final String? serviceType;
  final String? vehicleType;
  /// The catalog's icon family for the assigned driver's vehicle. This is what
  /// the backend actually sends; `vehicleType` is absent from every ride
  /// payload, so relying on it alone always fell through to the car default.
  final String? vehicleIconType;

  const RideModel({
    required this.rideId,
    required this.status,
    required this.liveStatus,
    required this.fare,
    required this.baseFare,
    required this.estimatedDistanceMeters,
    required this.estimatedDurationMinutes,
    required this.paymentMethod,
    this.routePolyline = '',
    required this.otp,
    required this.pickup,
    required this.pickupAddress,
    required this.drop,
    required this.dropAddress,
    this.stops = const [],
    this.scheduledAt,
    this.acceptedAt,
    this.arrivedAt,
    this.startedAt,
    this.completedAt,
    this.driver,
    this.lastDriverLocation,
    this.lastDriverHeading,
    this.messages = const [],
    this.serviceType,
    this.vehicleType,
    this.vehicleIconType,
  });

  factory RideModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic v) => v == null ? null : DateTime.tryParse(v.toString());

    return RideModel(
      rideId: (json['rideId'] ?? json['_id'] ?? json['id'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      liveStatus: (json['liveStatus'] ?? '').toString(),
      fare: double.tryParse('${json['fare'] ?? 0}') ?? 0,
      baseFare: double.tryParse('${json['baseFare'] ?? json['fare'] ?? 0}') ?? 0,
      estimatedDistanceMeters:
          double.tryParse('${json['estimatedDistanceMeters'] ?? 0}') ?? 0,
      estimatedDurationMinutes:
          double.tryParse('${json['estimatedDurationMinutes'] ?? 0}') ?? 0,
      paymentMethod: json['paymentMethod']?.toString() ?? 'cash',
      routePolyline: ((json['route'] is Map
              ? ((json['route'] as Map)['polyline'] ?? (json['route'] as Map)['encodedPolyline'])
              : null) ??
          json['polyline'] ??
          json['encodedPolyline'] ??
          json['routePolyline'] ??
          (json['route'] is String ? json['route'] : '') ??
          '').toString(),
      otp: (json['otp'] ?? '').toString(),
      pickup: LatLngPoint.fromGeoJson(json['pickupLocation']),
      pickupAddress: (json['pickupAddress'] ?? '').toString(),
      drop: LatLngPoint.fromGeoJson(json['dropLocation']),
      dropAddress: (json['dropAddress'] ?? '').toString(),
      stops: ((json['stops'] as List?) ?? [])
          .map((e) => RideStopPoint.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      scheduledAt: parseDate(json['scheduledAt']),
      acceptedAt: parseDate(json['acceptedAt']),
      arrivedAt: parseDate(json['arrivedAt']),
      startedAt: parseDate(json['startedAt']),
      completedAt: parseDate(json['completedAt']),
      driver: json['driver'] is Map && (json['driver'] as Map).isNotEmpty
          ? RideDriverInfo.fromJson(Map<String, dynamic>.from(json['driver']))
          : null,
      lastDriverLocation: json['lastDriverLocation'] != null
          ? LatLngPoint.fromGeoJson(json['lastDriverLocation'])
          : null,
      lastDriverHeading: json['lastDriverLocation'] is Map
          ? double.tryParse('${json['lastDriverLocation']['heading'] ?? ''}')
          : null,
      messages: ((json['messages'] as List?) ?? [])
          .map((e) => RideMessageModel.fromJson(Map<String, dynamic>.from(e)))
          .toList(),
      serviceType: json['serviceType']?.toString(),
      vehicleType: json['vehicleType']?.toString(),
      vehicleIconType: json['vehicleIconType']?.toString(),
    );
  }

  RideModel copyWith({
    String? status,
    String? liveStatus,
    RideDriverInfo? driver,
    LatLngPoint? lastDriverLocation,
    double? lastDriverHeading,
    List<RideMessageModel>? messages,
    DateTime? acceptedAt,
    DateTime? arrivedAt,
    DateTime? startedAt,
    DateTime? completedAt,
  }) {
    return RideModel(
      rideId: rideId,
      status: status ?? this.status,
      liveStatus: liveStatus ?? this.liveStatus,
      fare: fare,
      baseFare: baseFare,
      estimatedDistanceMeters: estimatedDistanceMeters,
      estimatedDurationMinutes: estimatedDurationMinutes,
      paymentMethod: paymentMethod,
      routePolyline: routePolyline,
      otp: otp,
      pickup: pickup,
      pickupAddress: pickupAddress,
      drop: drop,
      dropAddress: dropAddress,
      stops: stops,
      scheduledAt: scheduledAt,
      acceptedAt: acceptedAt ?? this.acceptedAt,
      arrivedAt: arrivedAt ?? this.arrivedAt,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      driver: driver ?? this.driver,
      lastDriverLocation: lastDriverLocation ?? this.lastDriverLocation,
      lastDriverHeading: lastDriverHeading ?? this.lastDriverHeading,
      messages: messages ?? this.messages,
      // Previously omitted, so every copyWith silently reset these to null —
      // which reset the map's vehicle marker back to the default on the first
      // status or location update.
      serviceType: serviceType,
      vehicleType: vehicleType,
      vehicleIconType: vehicleIconType,
    );
  }

  /// True once the trip is finished, by either status axis.
  ///
  /// The server carries two: `status` (searching/accepted/ongoing/completed)
  /// and `liveStatus` (which adds arriving/arrived/started). Reading only one
  /// means a payload that advances the other is missed.
  bool get isCompleted =>
      status.toLowerCase() == 'completed' || liveStatus.toLowerCase() == 'completed';

  bool get isCancelled =>
      status.toLowerCase() == 'cancelled' || liveStatus.toLowerCase() == 'cancelled';
}
