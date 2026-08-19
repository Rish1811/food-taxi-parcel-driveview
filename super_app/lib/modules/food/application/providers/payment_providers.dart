import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/core/payment/payment_gateway.dart';
import 'package:superapp_user/core/payment/payment_verifier.dart';
import 'package:superapp_user/modules/food/application/providers/order_providers.dart';
import 'package:superapp_user/modules/food/data/food_payment_verifier.dart';
import 'package:superapp_user/shared/profile/application/account_providers.dart';

/// Food's payment verifier — confirms the Razorpay signature triple against
/// `POST /food/orders/verify-payment`.
final foodPaymentVerifierProvider = Provider<PaymentVerifier>((ref) {
  return FoodPaymentVerifier(ref.watch(orderRemoteDataSourceProvider));
});

/// Razorpay checkout, currently wired to food's verifier.
///
/// Disposed with the container so the plugin's native listeners are always
/// cleared — two live Razorpay instances in one process is a real hazard, and
/// the ride module still has its own service. Converging both onto this gateway
/// (with a per-module PaymentIntent selecting the verifier) is required before
/// release; see docs/superapp Ch. 6.6.
final paymentGatewayProvider = Provider<PaymentGateway>((ref) {
  final gateway = PaymentGateway(
    ref.watch(foodPaymentVerifierProvider),
    ref.watch(accountRemoteDataSourceProvider),
  );
  ref.onDispose(gateway.dispose);
  return gateway;
});
