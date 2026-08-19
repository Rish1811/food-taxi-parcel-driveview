import 'package:superapp_user/modules/taxi/api/taxi_endpoints.dart';
import 'package:superapp_user/core/network/taxi_api_client.dart';
import 'package:superapp_user/modules/rental/data/models/rental_booking_model.dart';
import 'package:superapp_user/modules/rental/data/models/rental_vehicle_model.dart';

class RentalRepository {
  final TaxiApiClient api;

  RentalRepository(this.api);

  Future<List<RentalVehicleModel>> getRentalVehicles() async {
    final data = await api.get(ApiConstants.rentalVehicles);
    final results = (data['results'] as List? ?? []);
    return results.map((e) => RentalVehicleModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<Map<String, dynamic>> payAdvanceWithWallet({
    required double amount,
    required String bookingReference,
  }) async {
    final data = await api.post(ApiConstants.rentalAdvanceWallet, data: {
      'amount': amount,
      'bookingReference': bookingReference,
    });
    return Map<String, dynamic>.from(data);
  }

  Future<RentalBookingModel> createBooking({
    required String vehicleTypeId,
    required String bookingReference,
    required String packageId,
    required String packageLabel,
    required int durationHours,
    required double price,
    required double extraHourPrice,
    required DateTime pickupDateTime,
    required DateTime returnDateTime,
    required String paymentStatus,
    String paymentMethod = 'wallet',
    Map<String, dynamic>? payment,
  }) async {
    final data = await api.post(ApiConstants.rentalBookings, data: {
      'vehicleTypeId': vehicleTypeId,
      'bookingReference': bookingReference,
      'selectedPackage': {
        'id': packageId,
        'label': packageLabel,
        'durationHours': durationHours,
        'price': price,
        'extraHourPrice': extraHourPrice,
      },
      'pickupDateTime': pickupDateTime.toIso8601String(),
      'returnDateTime': returnDateTime.toIso8601String(),
      'paymentStatus': paymentStatus,
      'paymentMethod': paymentMethod,
      if (payment != null) 'payment': payment,
    });
    return RentalBookingModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<RentalBookingModel?> getActiveBooking() async {
    final data = await api.get(ApiConstants.activeRentalBooking);
    if (data == null) return null;
    return RentalBookingModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<void> endActiveBooking(String bookingId) {
    return api.post('${ApiConstants.rentalBookings}/$bookingId/end');
  }

  Future<List<RentalBookingModel>> listMyBookings() async {
    final data = await api.get(ApiConstants.rentalBookings);
    final results = (data['results'] as List? ?? []);
    return results.map((e) => RentalBookingModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }
}
