import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:superapp_user/core/config/app_constants.dart';
import 'package:superapp_user/core/error/failures.dart';
import 'package:superapp_user/shared/profile/data/account_remote_datasource.dart';
import 'package:superapp_user/core/payment/payment_verifier.dart';

/// Outcome of a gateway attempt.
enum PaymentOutcome { success, failed, cancelled, pending }

class PaymentResult {
  final PaymentOutcome outcome;
  final String message;

  /// The order as the server sees it after verification.
  final Map<String, dynamic>? order;

  const PaymentResult(this.outcome, this.message, {this.order});

  bool get isSuccess => outcome == PaymentOutcome.success;
}

/// Razorpay checkout wrapper.
///
/// The flow the backend expects:
///   1. `POST /food/orders` → `{ order, razorpay }`
///   2. open Razorpay with `razorpay.orderId` / `key` / `amount` (paise)
///   3. `POST /food/orders/verify-payment` with the signature triple
///
/// The Razorpay webhook is the real source of truth — if client verification
/// fails but the webhook lands, the order still succeeds. So a verify failure
/// re-reads the order and reports `pending` rather than a hard failure.
class PaymentGateway {
  final PaymentVerifier _verifier;
  final AccountRemoteDataSource _account;

  PaymentGateway(this._verifier, this._account);

  /// Completes when the gateway sheet closes and verification settles.
  Completer<PaymentResult>? _pending;
  Razorpay? _razorpay;

  /// Context for the in-flight attempt, so we can settle after verification.
  String? _orderId;
  double? _topUpAmount;

  /// Logo shown on the checkout sheet. Razorpay fetches it over the network, so
  /// this must be a hosted URL — a bundled asset will not render.
  String _brandLogoUrl = AppConstants.brandLogoUrl;

  /// Lets the app supply the backend's configured business logo at runtime.
  set brandLogoUrl(String url) {
    if (url.isNotEmpty) _brandLogoUrl = url;
  }

  void _attach() {
    _razorpay?.clear();
    final rz = Razorpay();
    rz.on(Razorpay.EVENT_PAYMENT_SUCCESS, _onSuccess);
    rz.on(Razorpay.EVENT_PAYMENT_ERROR, _onError);
    rz.on(Razorpay.EVENT_EXTERNAL_WALLET, _onExternalWallet);
    _razorpay = rz;
  }

  void dispose() {
    _razorpay?.clear();
    _razorpay = null;
  }

  /// Opens Razorpay for an order that has already been created server-side.
  ///
  /// [razorpay] is the object returned alongside the order; when it's null the
  /// gateway isn't configured and the caller should treat the order as pending.
  Future<PaymentResult> payForOrder({
    required String orderId,
    required Map<String, dynamic>? razorpay,
    required String customerName,
    required String customerPhone,
    String? customerEmail,
  }) async {
    final key = (razorpay?['key'] ?? AppConstants.razorpayKey).toString();
    if (razorpay == null || razorpay['orderId'] == null || key.isEmpty) {
      // The keys are set on the deployment but the pair is rejected by
      // Razorpay with 401 Authentication failed, so order creation cannot
      // produce a real gateway order and the API returns `razorpay: null`.
      // Until valid credentials are installed the order stays in
      // `pending_payment` and is swept by the expiry job. Reaching this branch
      // is the correct outcome — it is the fabricated `mock_order_*` id that
      // used to get through here that made the checkout fail confusingly.
      return const PaymentResult(
        PaymentOutcome.pending,
        'Online payment is not available right now. Your order was not charged.',
      );
    }

    _orderId = orderId;
    _topUpAmount = null;
    return _open(
      razorpay: razorpay,
      description: 'Order payment',
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
    );
  }

  /// Wallet top-up: creates the Razorpay order, opens the sheet, verifies.
  Future<PaymentResult> topUp({
    required double amount,
    required String customerName,
    required String customerPhone,
    String? customerEmail,
  }) async {
    final Map<String, dynamic> razorpay;
    try {
      razorpay = await _account.createTopupOrder(amount);
    } on Failure catch (f) {
      return PaymentResult(PaymentOutcome.failed, f.message);
    }

    final key = (razorpay['key'] ?? AppConstants.razorpayKey).toString();
    if (razorpay['orderId'] == null || key.isEmpty) {
      return const PaymentResult(
        PaymentOutcome.pending,
        'Wallet top-up is unavailable right now.',
      );
    }

    _orderId = null;
    _topUpAmount = amount;
    return _open(
      razorpay: razorpay,
      description: 'Wallet top-up',
      customerName: customerName,
      customerPhone: customerPhone,
      customerEmail: customerEmail,
    );
  }

  Future<PaymentResult> _open({
    required Map<String, dynamic> razorpay,
    required String description,
    required String customerName,
    required String customerPhone,
    String? customerEmail,
  }) {
    _attach();
    _pending = Completer<PaymentResult>();

    final key = (razorpay['key'] ?? AppConstants.razorpayKey).toString();

    try {
      _razorpay!.open({
        'key': key,
        // Our consumer brand, not the legal entity registered on the Razorpay
        // account — without this the sheet reads "SWITCHEATS PRIVATE LIMITED".
        'name': AppConstants.brandName,
        if (_brandLogoUrl.isNotEmpty) 'image': _brandLogoUrl,
        'theme': {'color': '#FF7A00'},
        'order_id': razorpay['orderId'],
        // Already paise from the backend — never re-multiply.
        'amount': int.tryParse(razorpay['amount'].toString()) ?? 0,
        'currency': razorpay['currency'] ?? 'INR',
        'description': description,
        'prefill': {
          if (customerPhone.isNotEmpty) 'contact': customerPhone,
          if (customerEmail != null && customerEmail.isNotEmpty) 'email': customerEmail,
          if (customerName.isNotEmpty) 'name': customerName,
        },
        'retry': {'enabled': true, 'max_count': 3},
      });
    } catch (e) {
      _settle(const PaymentResult(PaymentOutcome.failed, 'Could not open the payment screen.'));
    }

    return _pending!.future;
  }

  Future<void> _onSuccess(PaymentSuccessResponse response) async {
    final orderId = _orderId;
    final topUp = _topUpAmount;

    try {
      if (topUp != null) {
        await _account.verifyTopup(
          razorpayOrderId: response.orderId ?? '',
          razorpayPaymentId: response.paymentId ?? '',
          razorpaySignature: response.signature ?? '',
          amount: topUp,
        );
        _settle(const PaymentResult(PaymentOutcome.success, 'Wallet topped up successfully.'));
        return;
      }

      if (orderId == null) {
        _settle(const PaymentResult(PaymentOutcome.failed, 'Missing order reference.'));
        return;
      }

      final verified = await _verifier.verify(
        jobId: orderId,
        gatewayOrderId: response.orderId ?? '',
        gatewayPaymentId: response.paymentId ?? '',
        gatewaySignature: response.signature ?? '',
      );
      _settle(PaymentResult(
        PaymentOutcome.success,
        'Payment successful.',
        order: verified,
      ));
    } catch (_) {
      // The webhook is authoritative — re-read the order instead of declaring
      // failure on a client-side verification hiccup.
      if (orderId != null) {
        try {
          final order = await _verifier.fetchJob(orderId);
          if (_verifier.isPaid(order)) {
            _settle(PaymentResult(PaymentOutcome.success, 'Payment successful.', order: order));
            return;
          }
        } catch (_) {
          // fall through to pending
        }
      }
      _settle(const PaymentResult(
        PaymentOutcome.pending,
        'We are confirming your payment. This can take a moment.',
      ));
    }
  }

  void _onError(PaymentFailureResponse response) {
    // Razorpay reports a user-dismissed sheet as an error with this code.
    final cancelled = response.code == Razorpay.PAYMENT_CANCELLED;
    _settle(PaymentResult(
      cancelled ? PaymentOutcome.cancelled : PaymentOutcome.failed,
      cancelled ? 'Payment cancelled.' : (response.message ?? 'Payment failed.'),
    ));
  }

  void _onExternalWallet(ExternalWalletResponse response) {
    _settle(const PaymentResult(
      PaymentOutcome.pending,
      'Completing payment in your wallet app.',
    ));
  }

  void _settle(PaymentResult result) {
    final pending = _pending;
    _pending = null;
    _orderId = null;
    _topUpAmount = null;
    dispose();
    if (pending != null && !pending.isCompleted) pending.complete(result);
  }

  /// Convenience used by the profile wallet sheet.
  Future<void> topUpWallet({
    required BuildContext context,
    required double amount,
    required void Function(String message) onResult,
    String customerName = '',
    String customerPhone = '',
  }) async {
    final result = await topUp(
      amount: amount,
      customerName: customerName,
      customerPhone: customerPhone,
    );
    onResult(result.message);
  }
}
