import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/core/error/failures.dart';
import 'package:superapp_user/modules/food/data/models/order_pricing.dart';
import 'package:superapp_user/modules/food/application/providers/order_providers.dart';
import 'package:superapp_user/modules/food/application/providers/payment_providers.dart';
import 'package:superapp_user/core/payment/payment_gateway.dart';
import 'package:superapp_user/shared/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:superapp_user/modules/food/presentation/cart/viewmodels/cart_viewmodel.dart';
import 'package:superapp_user/modules/food/presentation/home/viewmodels/zone_viewmodel.dart';

import 'package:superapp_user/modules/food/presentation/orders/viewmodels/active_order_viewmodel.dart';

class CheckoutState {
  final OrderCalculation? calculation;
  final bool isCalculating;
  final String? error;

  /// Coupon the user typed. Echoed back by the server even when rejected, so
  /// [OrderPricing.hasCouponApplied] is what decides whether it actually landed.
  final String? couponCode;
  final String deliveryMode;
  final String? addressId;
  final bool priceChangesAccepted;

  const CheckoutState({
    this.calculation,
    this.isCalculating = false,
    this.error,
    this.couponCode,
    this.deliveryMode = 'basic',
    this.addressId,
    this.priceChangesAccepted = false,
  });

  OrderPricing? get pricing => calculation?.pricing;

  /// Blocks order submission until the user acknowledges menu price drift.
  bool get needsPriceConfirmation =>
      (calculation?.hasPriceChanges ?? false) && !priceChangesAccepted;

  bool get couponRejected =>
      (couponCode?.isNotEmpty ?? false) && !(pricing?.hasCouponApplied ?? false);

  CheckoutState copyWith({
    OrderCalculation? calculation,
    bool? isCalculating,
    String? error,
    String? couponCode,
    String? deliveryMode,
    String? addressId,
    bool? priceChangesAccepted,
    bool clearError = false,
    bool clearCoupon = false,
  }) {
    return CheckoutState(
      calculation: calculation ?? this.calculation,
      isCalculating: isCalculating ?? this.isCalculating,
      error: clearError ? null : (error ?? this.error),
      couponCode: clearCoupon ? null : (couponCode ?? this.couponCode),
      deliveryMode: deliveryMode ?? this.deliveryMode,
      addressId: addressId ?? this.addressId,
      priceChangesAccepted: priceChangesAccepted ?? this.priceChangesAccepted,
    );
  }
}

final checkoutViewModelProvider =
    NotifierProvider<CheckoutViewModel, CheckoutState>(CheckoutViewModel.new);

/// Owns the bill.
///
/// Every figure shown at checkout comes from `POST /food/orders/calculate` —
/// nothing is summed client-side. Recalculates whenever the cart, coupon,
/// address or delivery mode changes.
class CheckoutViewModel extends Notifier<CheckoutState> {
  @override
  CheckoutState build() {
    // Any cart mutation invalidates the server bill.
    ref.listen(cartViewModelProvider, (previous, next) {
      if (previous?.items.length != next.items.length ||
          previous?.totalQuantity != next.totalQuantity) {
        unawaited(recalculate());
      }
    });

    // Schedule initial recalculation on build if cart is not empty.
    Future.microtask(() {
      final cart = ref.read(cartViewModelProvider);
      if (cart.items.isNotEmpty) {
        unawaited(recalculate());
      }
    });

    return const CheckoutState();
  }

  Future<void> setAddress(String? addressId) async {
    state = state.copyWith(addressId: addressId);
    await recalculate();
  }

  Future<void> setDeliveryMode(String mode) async {
    state = state.copyWith(deliveryMode: mode);
    await recalculate();
  }

  Future<void> applyCoupon(String code) async {
    state = state.copyWith(couponCode: code.trim().toUpperCase());
    await recalculate();
    // ignore: avoid_print
    print(
      '[COUPON] code=${state.couponCode} '
      'applied=${state.pricing?.hasCouponApplied} '
      'discount=${state.pricing?.discount} '
      'total=${state.pricing?.total}',
    );
  }

  Future<void> removeCoupon() async {
    state = state.copyWith(clearCoupon: true);
    await recalculate();
    // ignore: avoid_print
    print('[COUPON] removed, total=${state.pricing?.total}');
  }

  /// Re-fetches the server bill for the current cart and options.
  Future<void> recalculate() async {
    final cart = ref.read(cartViewModelProvider);
    if (cart.items.isEmpty) {
      state = state.copyWith(calculation: null, isCalculating: false, clearError: true);
      return;
    }

    final restaurantId = cart.items.first.food.restaurantId;
    if (restaurantId.isEmpty) {
      state = state.copyWith(
        isCalculating: false,
        error: 'This item is missing its restaurant. Please re-add it to the cart.',
      );
      return;
    }

    state = state.copyWith(isCalculating: true, clearError: true);

    try {
      final calculation = await ref.read(orderRemoteDataSourceProvider).calculate(
            items: cart.items,
            restaurantId: restaurantId,
            deliveryAddressId: state.addressId,
            zoneId: ref.read(currentZoneIdProvider),
            couponCode: state.couponCode,
            deliveryMode: state.deliveryMode,
          );
      state = state.copyWith(
        calculation: calculation,
        isCalculating: false,
        priceChangesAccepted: false,
      );
    } on Failure catch (f) {
      state = state.copyWith(isCalculating: false, error: f.message);
    } catch (_) {
      state = state.copyWith(isCalculating: false, error: 'Could not calculate your bill.');
    }
  }

  /// Accepts updated prices after the user confirms.
  Future<void> acceptPriceChanges() async {
    state = state.copyWith(priceChangesAccepted: true);
  }

  /// Places the order. Returns `{ order, razorpay }` on success.
  ///
  /// Refuses to submit while price drift is unacknowledged.
  Future<({Map<String, dynamic>? result, String? error})> placeOrder({
    required Map<String, dynamic> address,
    required String customerName,
    required String customerPhone,
    required String restaurantName,
    String paymentMethod = 'razorpay',
    String? note,
    String? deliveryInstructions,
    bool sendCutlery = false,
  }) async {
    final cart = ref.read(cartViewModelProvider);
    final pricing = state.pricing;

    if (cart.items.isEmpty) return (result: null, error: 'Your cart is empty.');
    if (pricing == null) return (result: null, error: 'Bill not ready. Please try again.');
    if (state.needsPriceConfirmation) {
      return (result: null, error: 'Item prices changed. Please review before ordering.');
    }

    try {
      final result = await ref.read(orderRemoteDataSourceProvider).placeOrder(
            items: cart.items,
            restaurantId: cart.items.first.food.restaurantId,
            restaurantName: restaurantName,
            address: address,
            // Echo the server's own pricing object back verbatim.
            pricing: pricing.raw,
            customerName: customerName,
            customerPhone: customerPhone,
            paymentMethod: paymentMethod,
            deliveryMode: state.deliveryMode,
            note: note,
            deliveryInstructions: deliveryInstructions,
            sendCutlery: sendCutlery,
            zoneId: ref.read(currentZoneIdProvider),
          );
      return (result: result, error: null);
    } on Failure catch (f) {
      return (result: null, error: f.message);
    } catch (_) {
      return (result: null, error: 'Could not place your order. Please try again.');
    }
  }

  /// Places the order and drives payment to completion in one call.
  ///
  /// This is the whole checkout tail: `POST /orders` → Razorpay sheet →
  /// `verify-payment`. There is no intermediate in-app payment page; Razorpay's
  /// own sheet is the single payment surface, so it is opened directly from
  /// "Proceed to Payment".
  ///
  /// Clears the cart only once the payment has actually settled (success or
  /// webhook-pending), never on a cancellation or a hard failure.
  Future<PaymentFlowResult> payAndPlaceOrder({
    required Map<String, dynamic> address,
    required String restaurantName,
    String paymentMethod = 'razorpay',
    String? note,
    String? deliveryInstructions,
    bool sendCutlery = false,
  }) async {
    final user = ref.read(authViewModelProvider).value;
    final customerName = user?.displayName ?? 'Customer';
    final customerPhone = user?.phone ?? '';

    final placed = await placeOrder(
      address: address,
      customerName: customerName,
      customerPhone: customerPhone,
      restaurantName: restaurantName,
      paymentMethod: paymentMethod,
      note: note,
      deliveryInstructions: deliveryInstructions,
      sendCutlery: sendCutlery,
    );

    if (placed.error != null) {
      return PaymentFlowResult(outcome: PaymentOutcome.failed, message: placed.error!);
    }

    final order = placed.result?['order'] as Map<String, dynamic>?;
    final orderId = (order?['_id'] ?? order?['orderMongoId'] ?? '').toString();

    // For non-gateway payment methods (Cash on Delivery & K9 Wallet)
    if (paymentMethod == 'cash' || paymentMethod == 'wallet') {
      ref.read(cartViewModelProvider.notifier).clearCart();
      unawaited(
        ref.read(activeOrderViewModelProvider.notifier).fetchActiveOrder(isRefresh: true),
      );
      return PaymentFlowResult(
        outcome: PaymentOutcome.success,
        message: paymentMethod == 'cash'
            ? 'Order placed with Cash on Delivery 🎉'
            : 'Order paid successfully using K9 Wallet 🎉',
        orderId: orderId,
      );
    }

    final razorpay = placed.result?['razorpay'] as Map<String, dynamic>?;

    final payment = await ref.read(paymentGatewayProvider).payForOrder(
          orderId: orderId,
          razorpay: razorpay,
          customerName: customerName,
          customerPhone: customerPhone,
          customerEmail: user?.email,
        );

    final settled = payment.isSuccess || payment.outcome == PaymentOutcome.pending;
    if (settled) {
      ref.read(cartViewModelProvider.notifier).clearCart();
      unawaited(
        ref.read(activeOrderViewModelProvider.notifier).fetchActiveOrder(isRefresh: true),
      );
    } else if (payment.outcome == PaymentOutcome.cancelled && orderId.isNotEmpty) {
      // Don't leave a ghost `pending_payment` order behind when the user backs
      // out of the sheet.
      unawaited(
        ref.read(orderRemoteDataSourceProvider).discardPendingPayment(orderId).catchError((_) {}),
      );
    }

    return PaymentFlowResult(
      outcome: payment.outcome,
      message: payment.message,
      orderId: orderId,
    );
  }
}

/// Outcome of the combined place-order + pay sequence.
class PaymentFlowResult {
  final PaymentOutcome outcome;
  final String message;
  final String? orderId;

  const PaymentFlowResult({
    required this.outcome,
    required this.message,
    this.orderId,
  });

  /// True when the order exists and payment either succeeded or is awaiting the
  /// webhook — both cases should land the user on order tracking.
  bool get isPlaced =>
      outcome == PaymentOutcome.success || outcome == PaymentOutcome.pending;

  bool get isCancelled => outcome == PaymentOutcome.cancelled;
}
