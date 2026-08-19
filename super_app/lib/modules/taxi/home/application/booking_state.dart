import 'package:superapp_user/modules/taxi/ride/data/models/ride_model.dart';
import 'package:superapp_user/modules/taxi/home/data/models/set_price_model.dart';
import 'package:superapp_user/modules/taxi/home/data/models/vehicle_type_model.dart';
import 'package:superapp_user/modules/taxi/home/application/fare_calculator.dart';

class BookingLocation {
  final double lat;
  final double lng;
  final String address;

  const BookingLocation({required this.lat, required this.lng, required this.address});
}

enum BookingStep { selectingLocations, selectingVehicle, confirming, findingDriver, noDriverFound, dispatched }

class BookingState {
  final BookingLocation? pickup;
  final BookingLocation? drop;
  final List<BookingLocation> stops;
  final double? distanceMeters;
  final double? durationSeconds;
  final List<VehicleTypeModel> vehicleTypes;
  final List<SetPriceModel> setPrices;
  final Map<String, int> etaMinutesByVehicle;
  final VehicleTypeModel? selectedVehicle;
  final FareBreakdown? fareBreakdown;
  final String paymentMethod;
  final String? promoCode;
  final DateTime? scheduledAt;
  final BookingStep step;
  final bool isSubmitting;
  final String? error;
  final RideModel? createdRide;

  const BookingState({
    this.pickup,
    this.drop,
    this.stops = const [],
    this.distanceMeters,
    this.durationSeconds,
    this.vehicleTypes = const [],
    this.setPrices = const [],
    this.etaMinutesByVehicle = const {},
    this.selectedVehicle,
    this.fareBreakdown,
    this.paymentMethod = 'cash',
    this.promoCode,
    this.scheduledAt,
    this.step = BookingStep.selectingLocations,
    this.isSubmitting = false,
    this.error,
    this.createdRide,
  });

  /// Returns the price configured for [vehicleTypeId]. Falls back to any
  /// other configured set-price when this vehicle type has no dedicated
  /// row yet, so the fare shown/booked is still a real distance-based
  /// estimate rather than a blank placeholder or a blocked booking.
  SetPriceModel? pricingFor(String vehicleTypeId) {
    for (final p in setPrices) {
      if (p.vehicleTypeId == vehicleTypeId) return p;
    }
    return setPrices.isNotEmpty ? setPrices.first : null;
  }

  BookingState copyWith({
    BookingLocation? pickup,
    BookingLocation? drop,
    List<BookingLocation>? stops,
    double? distanceMeters,
    double? durationSeconds,
    List<VehicleTypeModel>? vehicleTypes,
    List<SetPriceModel>? setPrices,
    Map<String, int>? etaMinutesByVehicle,
    VehicleTypeModel? selectedVehicle,
    FareBreakdown? fareBreakdown,
    String? paymentMethod,
    String? promoCode,
    DateTime? scheduledAt,
    BookingStep? step,
    bool? isSubmitting,
    String? error,
    RideModel? createdRide,
    bool clearError = false,
    bool clearScheduledAt = false,
    bool clearPromo = false,
  }) {
    return BookingState(
      pickup: pickup ?? this.pickup,
      drop: drop ?? this.drop,
      stops: stops ?? this.stops,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      vehicleTypes: vehicleTypes ?? this.vehicleTypes,
      setPrices: setPrices ?? this.setPrices,
      etaMinutesByVehicle: etaMinutesByVehicle ?? this.etaMinutesByVehicle,
      selectedVehicle: selectedVehicle ?? this.selectedVehicle,
      fareBreakdown: fareBreakdown ?? this.fareBreakdown,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      promoCode: clearPromo ? null : (promoCode ?? this.promoCode),
      scheduledAt: clearScheduledAt ? null : (scheduledAt ?? this.scheduledAt),
      step: step ?? this.step,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: clearError ? null : (error ?? this.error),
      createdRide: createdRide ?? this.createdRide,
    );
  }
}
