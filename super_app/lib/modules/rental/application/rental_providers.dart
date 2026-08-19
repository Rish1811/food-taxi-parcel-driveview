import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superapp_user/modules/taxi/application/taxi_core_providers.dart';
import 'package:superapp_user/modules/rental/data/models/rental_booking_model.dart';
import 'package:superapp_user/modules/rental/data/models/rental_vehicle_model.dart';
import 'package:superapp_user/modules/rental/data/rental_repository.dart';

final rentalRepositoryProvider = Provider<RentalRepository>((ref) {
  return RentalRepository(ref.watch(taxiApiClientProvider));
});

final rentalVehiclesProvider = FutureProvider.autoDispose<List<RentalVehicleModel>>((ref) {
  return ref.watch(rentalRepositoryProvider).getRentalVehicles();
});

final activeRentalBookingProvider = FutureProvider.autoDispose<RentalBookingModel?>((ref) {
  return ref.watch(rentalRepositoryProvider).getActiveBooking();
});

final myRentalBookingsProvider = FutureProvider.autoDispose<List<RentalBookingModel>>((ref) {
  return ref.watch(rentalRepositoryProvider).listMyBookings();
});
