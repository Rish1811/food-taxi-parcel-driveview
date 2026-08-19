import 'package:superapp_user/modules/taxi/api/taxi_endpoints.dart';
import 'package:superapp_user/core/network/taxi_api_client.dart';
import 'package:superapp_user/modules/taxi/ride/data/models/ride_model.dart';
import 'package:superapp_user/modules/taxi/home/application/booking_state.dart';

class RideRepository {
  final TaxiApiClient api;

  RideRepository(this.api);

  /// Vehicles offering a Safe Ride for this trip, with the normal and safe-ride fare.
  /// Returns an empty list when the option is not configured anywhere for this location.
  Future<List<SafeRideOption>> fetchSafeRideOptions({
    required double distanceMeters,
    required double durationMinutes,
    String? serviceLocationId,
    String transportType = 'taxi',
  }) async {
    final data = await api.get(
      ApiConstants.safeRideVehicles,
      queryParameters: {
        'distanceMeters': distanceMeters.round(),
        'durationMinutes': durationMinutes.round(),
        'transportType': transportType,
        if (serviceLocationId != null) 'serviceLocationId': serviceLocationId,
      },
    );
    final payload = (data is Map) ? (data['data'] ?? data) : data;
    final list = (payload is Map ? payload['vehicles'] : null);
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => SafeRideOption.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<RideModel> createRide({
    required List<double> pickup,
    required List<double> drop,
    required String pickupAddress,
    required String dropAddress,
    List<Map<String, dynamic>> stops = const [],
    required double fare,
    required double estimatedDistanceMeters,
    required double estimatedDurationMinutes,
    required String vehicleTypeId,
    String paymentMethod = 'cash',
    String serviceType = 'ride',
    String? promoCode,
    String? zoneId,
    String? serviceLocationId,
    DateTime? scheduledAt,
    /// Safe Ride ("I've been drinking"). Only the flag is sent — the tariff is
    /// resolved server-side from the admin config, never from the client.
    bool safeRide = false,
  }) async {
    final data = await api.post(ApiConstants.rides, data: {
      'pickup': pickup,
      'drop': drop,
      'pickupAddress': pickupAddress,
      'dropAddress': dropAddress,
      if (stops.isNotEmpty) 'stops': stops,
      'fare': fare,
      'estimatedDistanceMeters': estimatedDistanceMeters,
      'estimatedDurationMinutes': estimatedDurationMinutes,
      'vehicleTypeId': vehicleTypeId,
      'paymentMethod': paymentMethod,
      'serviceType': serviceType,
      if (safeRide) 'safeRide': true,
      if (promoCode != null && promoCode.isNotEmpty) 'promo_code': promoCode,
      ?zoneId: zoneId,
      ?serviceLocationId: serviceLocationId,
      'transport_type': 'taxi',
      if (scheduledAt != null) 'scheduledAt': scheduledAt.toIso8601String(),
    });
    return RideModel.fromJson(Map<String, dynamic>.from(data['ride'] ?? {}));
  }

  Future<RideModel?> getMyActiveRide() async {
    final data = await api.get(ApiConstants.activeRide);
    if (data == null) return null;
    return RideModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<RideModel> getRideById(String rideId) async {
    final data = await api.get('${ApiConstants.rides}/$rideId');
    return RideModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<Map<String, dynamic>> listMyRides({int page = 1, int limit = 20, String? category}) async {
    final data = await api.get(ApiConstants.rides, query: {
      'page': page,
      'limit': limit,
      ?category: category,
    });
    return Map<String, dynamic>.from(data);
  }

  Future<void> cancelRide(String rideId, {String? reason}) {
    return api.patch('${ApiConstants.rides}/$rideId/cancel', data: {
      ?reason: reason,
    });
  }

  Future<void> submitReview(String rideId, {required int rating, String? comment, double tipAmount = 0}) {
    return api.patch('${ApiConstants.rides}/$rideId/feedback', data: {
      'rating': rating,
      ?comment: comment,
      'tipAmount': tipAmount,
    });
  }

  Future<List<Map<String, dynamic>>> getAvailableDrivers({required double lat, required double lng}) async {
    final data = await api.get(ApiConstants.availableDrivers, query: {'lat': lat, 'lng': lng});
    // The endpoint returns `{ totalDrivers, drivers: [...] }` — reading
    // `results` here silently yielded an empty list.
    final results = (data is Map ? (data['drivers'] ?? data['results']) : data) as List? ?? [];
    return results.map((e) => Map<String, dynamic>.from(e)).toList();
  }

  Future<Map<String, dynamic>> createTipOrder(String rideId, double amount) async {
    final data = await api.post('${ApiConstants.rides}/$rideId/tip/razorpay/order', data: {'amount': amount});
    return Map<String, dynamic>.from(data);
  }

  Future<void> verifyTipPayment(String rideId, Map<String, dynamic> payload) {
    return api.post('${ApiConstants.rides}/$rideId/tip/razorpay/verify', data: payload);
  }

  Future<Map<String, dynamic>> createCompletionOrder(String rideId) async {
    final data = await api.post('${ApiConstants.rides}/$rideId/complete-payment/razorpay/order');
    return Map<String, dynamic>.from(data);
  }

  Future<void> verifyCompletionPayment(String rideId, Map<String, dynamic> payload) {
    return api.post('${ApiConstants.rides}/$rideId/complete-payment/razorpay/verify', data: payload);
  }

  Future<void> payCompletionWithWallet(String rideId) {
    return api.post('${ApiConstants.rides}/$rideId/complete-payment/wallet');
  }
}
