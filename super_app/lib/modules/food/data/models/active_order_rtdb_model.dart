/// RTDB node schema for `active_orders/{orderMongoId}`.
class ActiveOrderRtdbModel {
  final double? lat;
  final double? lng;
  final double heading;
  final double speed;
  final double accuracy;
  final double? restaurantLat;
  final double? restaurantLng;
  final double? customerLat;
  final double? customerLng;
  final String? polyline;
  final String? status;
  final int? lastUpdated;

  const ActiveOrderRtdbModel({
    this.lat,
    this.lng,
    this.heading = 0.0,
    this.speed = 0.0,
    this.accuracy = 0.0,
    this.restaurantLat,
    this.restaurantLng,
    this.customerLat,
    this.customerLng,
    this.polyline,
    this.status,
    this.lastUpdated,
  });

  /// Check if location was updated within the last 60 seconds.
  bool get isStale {
    if (lastUpdated == null) return true;
    final diffMs = DateTime.now().millisecondsSinceEpoch - lastUpdated!;
    return diffMs > 60000;
  }

  factory ActiveOrderRtdbModel.fromMap(Map<dynamic, dynamic> map) {
    double? parseNum(dynamic val) {
      if (val is num) return val.toDouble();
      if (val is String) return double.tryParse(val);
      return null;
    }

    int? parseEpoch(dynamic val) {
      if (val is num) return val.toInt();
      if (val is String) return int.tryParse(val);
      return null;
    }

    // Read both `lat`/`lng` and legacy `boy_lat`/`boy_lng`.
    final latitude = parseNum(map['lat']) ?? parseNum(map['boy_lat']);
    final longitude = parseNum(map['lng']) ?? parseNum(map['boy_lng']);

    return ActiveOrderRtdbModel(
      lat: latitude,
      lng: longitude,
      heading: parseNum(map['heading']) ?? 0.0,
      speed: parseNum(map['speed']) ?? 0.0,
      accuracy: parseNum(map['accuracy']) ?? 0.0,
      restaurantLat: parseNum(map['restaurant_lat']),
      restaurantLng: parseNum(map['restaurant_lng']),
      customerLat: parseNum(map['customer_lat']),
      customerLng: parseNum(map['customer_lng']),
      polyline: map['polyline']?.toString(),
      status: map['status']?.toString(),
      lastUpdated: parseEpoch(map['last_updated']),
    );
  }
}
