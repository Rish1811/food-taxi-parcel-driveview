import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/core/network/taxi_api_client.dart';
import 'package:superapp_user/core/location/taxi_location_service.dart';
import 'package:superapp_user/core/payment/taxi_razorpay_service.dart';
import 'package:superapp_user/core/realtime/taxi_socket_service.dart';
import 'package:superapp_user/core/network/network_providers.dart';


/// The taxi-shaped facade over the app's single HTTP client.
///
/// Deliberately *not* its own Dio: sharing the one client means the ride side
/// inherits bearer injection, single-flight 401 refresh, envelope unwrapping
/// and the response cache, and a session expiring in one module expires it
/// everywhere — which is the whole point of one account across the super app.
final taxiApiClientProvider = Provider<TaxiApiClient>((ref) {
  return TaxiApiClient(ref.watch(apiClientProvider));
});

final taxiSocketServiceProvider = Provider<TaxiSocketService>((ref) {
  final service = TaxiSocketService();
  ref.onDispose(service.disconnect);
  return service;
});

final taxiLocationServiceProvider = Provider<TaxiLocationService>((ref) {
  return TaxiLocationService();
});

/// Ride-side Razorpay checkout.
///
/// Follow-up: food has its own 272-line `payment_gateway.dart`. Two live
/// Razorpay plugin instances in one binary is a real hazard — the plugin holds
/// native listeners — so these must converge on a single gateway with per-module
/// PaymentIntents before release.
final razorpayServiceProvider = Provider<RazorpayService>((ref) {
  final service = RazorpayService();
  ref.onDispose(service.dispose);
  return service;
});
