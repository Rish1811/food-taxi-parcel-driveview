import 'dart:async';

import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superapp_user/modules/taxi/application/taxi_core_providers.dart';
import 'package:superapp_user/modules/taxi/ride/application/ride_providers.dart';
import 'package:superapp_user/modules/taxi/home/data/models/vehicle_type_model.dart';
import 'package:superapp_user/modules/taxi/home/application/booking_state.dart';
import 'package:superapp_user/modules/taxi/home/application/fare_calculator.dart';
import 'package:superapp_user/modules/taxi/home/application/home_providers.dart';
import 'package:superapp_user/modules/taxi/home/application/ride_search_controller.dart';

/// Average city-traffic speed assumed for client-side ETA estimation only.
const double _assumedSpeedKmph = 25;

class BookingController extends Notifier<BookingState> {

  @override
  BookingState build() => const BookingState();

  Future<void> loadCatalog() async {
    final repo = ref.read(homeRepositoryProvider);
    state = state.copyWith(clearError: true);

    // Fetched independently, NOT with Future.wait. A single Future.wait rejects
    // as soon as either call throws, so a missing fare table took the vehicle
    // list down with it — and because the screen shows a spinner whenever the
    // list is empty, that surfaced as an endless loader with no error.
    //
    // The vehicle list is the screen's reason to exist; prices are an
    // enrichment. Losing the enrichment must not lose the screen.
    final vehicleTypes = await _guard(repo.getVehicleTypes, 'vehicle types');
    if (vehicleTypes == null) {
      state = state.copyWith(
        error: 'Could not load vehicles. Check your connection and try again.',
      );
      return;
    }

    state = state.copyWith(
      vehicleTypes: vehicleTypes,
      selectedVehicle: vehicleTypes.isNotEmpty ? vehicleTypes.first : null,
    );

    final setPrices = await _guard(repo.getSetPrices, 'fare table');
    if (setPrices != null) {
      state = state.copyWith(setPrices: setPrices);
    }

    _recalculateFare();
    unawaited(_loadDriverEtas());
  }

  /// Runs [fetch], returning null instead of throwing so one failed call
  /// cannot abort the rest of the catalogue load.
  Future<T?> _guard<T>(Future<T> Function() fetch, String label) async {
    try {
      return await fetch();
    } catch (e) {
      if (kDebugMode) debugPrint('[booking] $label failed: $e');
      return null;
    }
  }

  /// Fetches the closest available driver's ETA per vehicle type in
  /// parallel so the ride-type list can show a real "X mins away" instead
  /// of a hardcoded placeholder. Best-effort: failures are swallowed per
  /// vehicle type so one missing driver pool doesn't block the others.
  Future<void> _loadDriverEtas() async {
    final pickup = state.pickup;
    if (pickup == null || state.vehicleTypes.isEmpty) return;

    final repo = ref.read(homeRepositoryProvider);
    final entries = await Future.wait(state.vehicleTypes.map((vehicle) async {
      try {
        final eta = await repo.getClosestDriverEtaMinutes(
          lat: pickup.lat,
          lng: pickup.lng,
          vehicleTypeId: vehicle.id,
        );
        return MapEntry(vehicle.id, eta);
      } catch (_) {
        return MapEntry(vehicle.id, null);
      }
    }));

    final etaMap = <String, int>{
      for (final e in entries)
        if (e.value != null) e.key: e.value!,
    };
    state = state.copyWith(etaMinutesByVehicle: etaMap);
  }

  void setPickup(BookingLocation location) {
    state = state.copyWith(pickup: location, clearError: true);
    _recalculateRoute();
    unawaited(_loadDriverEtas());
  }

  void setDrop(BookingLocation location) {
    state = state.copyWith(drop: location, clearError: true);
    _recalculateRoute();
  }

  void setStops(List<BookingLocation> stops) {
    state = state.copyWith(stops: stops, clearError: true);
    _recalculateRoute();
  }

  void selectVehicle(VehicleTypeModel vehicle) {
    state = state.copyWith(selectedVehicle: vehicle);
    _recalculateFare();
    // Availability is per vehicle, so re-check whenever the selection changes.
    loadSafeRideOptions();
  }

  void setPaymentMethod(String method) {
    state = state.copyWith(paymentMethod: method);
  }

  /// Safe Ride ("I've been drinking"): opt in/out. The dedicated tariff is applied by the
  /// backend at booking time; this only records the rider's choice and refreshes the fare
  /// preview so the surcharge is visible before they confirm.
  void setSafeRide(bool value) {
    if (value && !state.canUseSafeRide) return;
    state = state.copyWith(safeRide: value);
  }

  /// Loads which vehicles offer a Safe Ride for the current route, with both fares.
  /// Failure is non-fatal — the option simply stays hidden rather than blocking booking.
  Future<void> loadSafeRideOptions() async {
    final distance = state.distanceMeters ?? 0;
    final duration = (state.durationSeconds ?? 0) / 60;
    if (distance <= 0) return;
    try {
      final options = await ref.read(rideRepositoryProvider).fetchSafeRideOptions(
            distanceMeters: distance,
            durationMinutes: duration,
          );
      final map = {for (final o in options) o.vehicleTypeId: o};
      // If the chosen vehicle stops offering it, drop the opt-in rather than
      // letting a stale toggle send safeRide:true and get rejected at booking.
      final stillValid = state.selectedVehicle != null && map.containsKey(state.selectedVehicle!.id);
      state = state.copyWith(
        safeRideOptions: map,
        safeRide: state.safeRide && stillValid,
      );
    } catch (_) {
      state = state.copyWith(safeRideOptions: const {}, safeRide: false);
    }
  }

  void applyPromoCode(String? code) {
    if (code == null || code.trim().isEmpty) {
      state = state.copyWith(clearPromo: true);
    } else {
      state = state.copyWith(promoCode: code.trim());
    }
  }

  void setScheduledAt(DateTime? time) {
    if (time == null) {
      state = state.copyWith(clearScheduledAt: true);
    } else {
      state = state.copyWith(scheduledAt: time);
    }
  }

  void goToStep(BookingStep step) {
    state = state.copyWith(step: step);
  }

  void _recalculateRoute() {
    final pickup = state.pickup;
    final drop = state.drop;
    if (pickup == null || drop == null) return;

    final locationService = ref.read(taxiLocationServiceProvider);
    double totalDistanceMeters = 0;
    BookingLocation current = pickup;

    for (final stop in state.stops) {
      totalDistanceMeters += locationService.distanceMeters(
        current.lat,
        current.lng,
        stop.lat,
        stop.lng,
      );
      current = stop;
    }

    totalDistanceMeters += locationService.distanceMeters(
      current.lat,
      current.lng,
      drop.lat,
      drop.lng,
    );

    final durationSeconds = (totalDistanceMeters / 1000) / _assumedSpeedKmph * 3600;

    state = state.copyWith(
      distanceMeters: totalDistanceMeters,
      durationSeconds: durationSeconds,
    );
    _recalculateFare();
  }

  void _recalculateFare() {
    final vehicle = state.selectedVehicle;
    if (vehicle == null) return;
    final breakdown = fareForVehicle(vehicle);
    if (breakdown == null) return;
    state = state.copyWith(fareBreakdown: breakdown);
  }

  FareBreakdown? fareForVehicle(VehicleTypeModel vehicle) {
    final distanceMeters = state.distanceMeters;
    final durationSeconds = state.durationSeconds;
    if (distanceMeters == null || durationSeconds == null) return null;

    final pricing = state.pricingFor(vehicle.id);
    if (pricing == null) return null;

    return FareCalculator.estimate(
      pricing: pricing,
      distanceMeters: distanceMeters,
      durationSeconds: durationSeconds,
    );
  }

  Future<bool> confirmBooking() async {
    final pickup = state.pickup;
    final drop = state.drop;
    final vehicle = state.selectedVehicle;
    final fare = state.fareBreakdown;
    if (pickup == null || drop == null || vehicle == null || fare == null) {
      state = state.copyWith(error: 'Please select pickup, drop and a ride type');
      return false;
    }

    state = state.copyWith(isSubmitting: true, clearError: true, step: BookingStep.findingDriver);

    // Armed before the POST so a driver who accepts immediately can't beat us
    // to the `rideAccepted` event.
    final search = ref.read(rideSearchControllerProvider.notifier);
    search.beginCreating();

    try {
      final ride = await ref.read(rideRepositoryProvider).createRide(
            pickup: [pickup.lng, pickup.lat],
            drop: [drop.lng, drop.lat],
            pickupAddress: pickup.address,
            dropAddress: drop.address,
            stops: state.stops
                .map((s) => {
                      'lat': s.lat,
                      'lng': s.lng,
                      'address': s.address,
                    })
                .toList(),
            fare: fare.total,
            estimatedDistanceMeters: state.distanceMeters ?? 0,
            estimatedDurationMinutes: (state.durationSeconds ?? 0) / 60,
            vehicleTypeId: vehicle.id,
            paymentMethod: state.paymentMethod,
            promoCode: state.promoCode,
            scheduledAt: state.scheduledAt,
            safeRide: state.safeRide,
          );
      search.attachRide(ride);
      state = state.copyWith(
        isSubmitting: false,
        createdRide: ride,
        step: BookingStep.dispatched,
      );
      return true;
    } catch (e) {
      search.failCreate(e.toString());
      state = state.copyWith(
        isSubmitting: false,
        error: e.toString(),
        step: BookingStep.noDriverFound,
      );
      return false;
    }
  }

  void reset() {
    ref.read(rideSearchControllerProvider.notifier).reset();
    state = const BookingState();
  }
}

final bookingControllerProvider =
    NotifierProvider<BookingController, BookingState>(BookingController.new);
