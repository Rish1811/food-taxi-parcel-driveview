import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/core/error/taxi_api_exception.dart';
import 'package:superapp_user/modules/taxi/home/application/booking_state.dart';
import 'package:superapp_user/modules/taxi/home/application/home_providers.dart';
import 'package:superapp_user/modules/parcel/data/delivery_repository.dart';
import 'package:superapp_user/modules/parcel/data/models/parcel_model.dart';
import 'package:superapp_user/modules/parcel/application/delivery_providers.dart';

/// Everything gathered across the delivery booking screens.
///
/// Held in one place so the vehicle picker, address screen and contact sheet
/// can each contribute a piece without passing arguments down a route chain —
/// and so a back-navigation keeps what was already entered.
class DeliveryBookingState {
  final String vehicleTypeId;
  final String vehicleName;
  final BookingLocation? pickup;
  final BookingLocation? drop;
  final String senderName;
  final String senderMobile;
  final String receiverName;
  final String receiverMobile;
  final String category;
  /// The delivery card the rider picked ('trucks' | '2wheeler' | 'auto' | 'movers').
  final String deliveryCategoryId;
  final DeliveryQuote? quote;
  final bool quoting;
  final String? error;

  const DeliveryBookingState({
    this.vehicleTypeId = '',
    this.vehicleName = '',
    this.pickup,
    this.drop,
    this.senderName = '',
    this.senderMobile = '',
    this.receiverName = '',
    this.receiverMobile = '',
    this.category = '',
    this.deliveryCategoryId = '',
    this.quote,
    this.quoting = false,
    this.error,
  });

  bool get hasSender => senderName.trim().isNotEmpty && senderMobile.trim().length >= 10;
  bool get hasReceiver => receiverName.trim().isNotEmpty && receiverMobile.trim().length >= 10;

  /// Booking needs a route, a vehicle, both contacts and a server quote.
  bool get canConfirm =>
      pickup != null && drop != null && vehicleTypeId.isNotEmpty && hasSender && hasReceiver && quote != null;

  DeliveryBookingState copyWith({
    String? vehicleTypeId,
    String? vehicleName,
    BookingLocation? pickup,
    BookingLocation? drop,
    String? senderName,
    String? senderMobile,
    String? receiverName,
    String? receiverMobile,
    String? category,
    String? deliveryCategoryId,
    DeliveryQuote? quote,
    bool clearQuote = false,
    bool? quoting,
    String? error,
    bool clearError = false,
  }) {
    return DeliveryBookingState(
      vehicleTypeId: vehicleTypeId ?? this.vehicleTypeId,
      vehicleName: vehicleName ?? this.vehicleName,
      pickup: pickup ?? this.pickup,
      drop: drop ?? this.drop,
      senderName: senderName ?? this.senderName,
      senderMobile: senderMobile ?? this.senderMobile,
      receiverName: receiverName ?? this.receiverName,
      receiverMobile: receiverMobile ?? this.receiverMobile,
      category: category ?? this.category,
      deliveryCategoryId: deliveryCategoryId ?? this.deliveryCategoryId,
      quote: clearQuote ? null : (quote ?? this.quote),
      quoting: quoting ?? this.quoting,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class DeliveryBookingController extends Notifier<DeliveryBookingState> {

  @override
  DeliveryBookingState build() => const DeliveryBookingState();

  void selectDeliveryCategory(String categoryId) {
    // Switching card invalidates the chosen vehicle — its pricing belongs to a
    // different class of service.
    state = state.copyWith(
      deliveryCategoryId: categoryId,
      vehicleTypeId: '',
      vehicleName: '',
      clearQuote: true,
    );
  }

  void selectVehicle({required String id, required String name}) {
    // Pricing is per vehicle type, so an existing quote is stale the moment
    // the rider switches vehicle.
    state = state.copyWith(vehicleTypeId: id, vehicleName: name, clearQuote: true);
    _refreshQuote();
  }

  void setPickup(BookingLocation location) {
    state = state.copyWith(pickup: location, clearQuote: true);
    _refreshQuote();
  }

  void setDrop(BookingLocation location) {
    state = state.copyWith(drop: location, clearQuote: true);
    _refreshQuote();
  }

  void clearDrop() {
    state = DeliveryBookingState(
      vehicleTypeId: state.vehicleTypeId,
      vehicleName: state.vehicleName,
      pickup: state.pickup,
      drop: null,
      senderName: state.senderName,
      senderMobile: state.senderMobile,
      receiverName: state.receiverName,
      receiverMobile: state.receiverMobile,
      category: state.category,
      deliveryCategoryId: state.deliveryCategoryId,
      quote: null,
      quoting: false,
      error: null,
    );
  }

  void setContacts({
    required String senderName,
    required String senderMobile,
    required String receiverName,
    required String receiverMobile,
  }) {
    state = state.copyWith(
      senderName: senderName,
      senderMobile: senderMobile,
      receiverName: receiverName,
      receiverMobile: receiverMobile,
    );
  }

  void setCategory(String category) {
    state = state.copyWith(category: category, clearQuote: true);
    _refreshQuote();
  }

  /// Prefills the sender from the signed-in profile — the rider is almost
  /// always the sender, and re-typing their own details is friction.
  void prefillSenderFrom({String? name, String? phone}) {
    if (state.senderName.isNotEmpty) return;
    state = state.copyWith(
      senderName: name ?? '',
      senderMobile: phone ?? '',
    );
  }

  Future<void> _refreshQuote() async {
    final pickup = state.pickup;
    final drop = state.drop;
    if (pickup == null || drop == null) return;

    // The quote endpoint prices per vehicle type, so without one there is
    // nothing to ask for. This used to return silently, leaving the fare card
    // stuck on a generic failure with no hint of the real cause.
    if (state.vehicleTypeId.isEmpty) {
      state = state.copyWith(
        quoting: false,
        clearQuote: true,
        error: 'Choose a delivery vehicle to see the fare.',
      );
      return;
    }

    state = state.copyWith(quoting: true, clearError: true);
    try {
      final quote = await ref.read(deliveryRepositoryProvider).getQuote(
            vehicleTypeId: state.vehicleTypeId,
            pickup: [pickup.lng, pickup.lat],
            drop: [drop.lng, drop.lat],
            category: state.category,
          );
      state = state.copyWith(quote: quote, quoting: false);
    } on TaxiApiException catch (e) {
      // The server's own reason (unpriced vehicle, goods type not allowed, …)
      // is far more actionable than a generic failure.
      state = state.copyWith(quoting: false, error: e.message, clearQuote: true);
    } catch (e) {
      state = state.copyWith(quoting: false, error: e.toString(), clearQuote: true);
    }
  }

  Future<void> retryQuote() => _refreshQuote();

  /// Creates the booking and returns its ride id for the search screen.
  Future<String> confirm() async {
    final pickup = state.pickup!;
    final drop = state.drop!;
    final quote = state.quote!;

    final delivery = await ref.read(deliveryRepositoryProvider).createDelivery(
          pickup: [pickup.lng, pickup.lat],
          drop: [drop.lng, drop.lat],
          pickupAddress: pickup.address,
          dropAddress: drop.address,
          fare: quote.total,
          vehicleTypeId: state.vehicleTypeId,
          parcel: ParcelModel(
            category: state.category,
            senderName: state.senderName,
            senderMobile: state.senderMobile,
            receiverName: state.receiverName,
            receiverMobile: state.receiverMobile,
          ),
        );

    // A delivery is a ride with `serviceType: parcel`, so tracking and the
    // dispatch search both key off the ride id.
    return delivery.ride.rideId;
  }

  void reset() => state = const DeliveryBookingState();
}

final deliveryBookingProvider =
    NotifierProvider<DeliveryBookingController, DeliveryBookingState>(DeliveryBookingController.new);

/// Only the vehicle types the admin marked as delivery vehicles.
final deliveryVehicleTypesProvider = FutureProvider((ref) async {
  final all = await ref.watch(allVehicleTypesProvider.future);
  return all
      .where((v) => v.transportType.toLowerCase() == 'delivery')
      .toList();
});

/// Delivery vehicles filed under one category card.
///
/// A vehicle whose `delivery_category` the admin never set comes back empty and
/// would belong to no card at all, so it is deliberately excluded rather than
/// shown under an arbitrary one.
final deliveryVehiclesByCategoryProvider =
    FutureProvider.family((ref, String categoryId) async {
  final vehicles = await ref.watch(deliveryVehicleTypesProvider.future);
  return vehicles
      .where((v) => v.deliveryCategory.toLowerCase() == categoryId.toLowerCase())
      .toList();
});
