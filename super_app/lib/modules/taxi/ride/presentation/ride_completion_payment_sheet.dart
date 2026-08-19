import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';

import 'package:superapp_user/core/error/taxi_api_exception.dart';
import 'package:superapp_user/modules/taxi/application/taxi_core_providers.dart';
import 'package:superapp_user/core/payment/taxi_razorpay_service.dart';
import 'package:superapp_user/design_system/tokens/taxi_colors.dart';
import 'package:superapp_user/design_system/components/feedback/taxi_snackbar_utils.dart';
import 'package:superapp_user/modules/taxi/auth/application/auth_providers.dart';
import 'package:superapp_user/modules/taxi/ride/application/ride_providers.dart';

/// Collects the fare for a completed ride booked as `online`.
///
/// Without this the rider was never asked to pay — the backend's
/// `complete-payment` endpoints existed but nothing in the app called them, so
/// an online ride finished with the fare uncollected.
///
/// Offers both routes the backend supports: the wallet (instant, no gateway)
/// and Razorpay checkout.
class RideCompletionPaymentSheet extends ConsumerStatefulWidget {
  final String rideId;
  final double amount;

  const RideCompletionPaymentSheet({
    super.key,
    required this.rideId,
    required this.amount,
  });

  /// Returns true once the fare is settled.
  static Future<bool> show(
    BuildContext context, {
    required String rideId,
    required double amount,
  }) async {
    final paid = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      // The fare is due — dismissing by tapping away would silently skip it.
      isDismissible: false,
      enableDrag: false,
      builder: (_) => RideCompletionPaymentSheet(rideId: rideId, amount: amount),
    );
    return paid ?? false;
  }

  @override
  ConsumerState<RideCompletionPaymentSheet> createState() =>
      _RideCompletionPaymentSheetState();
}

class _RideCompletionPaymentSheetState
    extends ConsumerState<RideCompletionPaymentSheet> {
  bool _busy = false;

  void _setBusy(bool value) {
    if (mounted) setState(() => _busy = value);
  }

  Future<void> _payWithWallet() async {
    if (_busy) return;
    _setBusy(true);
    try {
      await ref.read(rideRepositoryProvider).payCompletionWithWallet(widget.rideId);
      if (!mounted) return;
      SnackbarUtils.success(context, 'Paid from wallet');
      Navigator.of(context).pop(true);
    } on TaxiApiException catch (e) {
      // Most often an insufficient balance — the rider can still use the card.
      if (mounted) SnackbarUtils.error(context, e.message);
      _setBusy(false);
    }
  }

  Future<void> _payWithRazorpay() async {
    if (_busy) return;
    _setBusy(true);
    try {
      final order = await ref
          .read(rideRepositoryProvider)
          .createCompletionOrder(widget.rideId);
      final user = ref.read(authControllerProvider).user;

      final keyId = (order['keyId'] ?? order['key_id'] ?? order['key'] ?? '').toString();
      final orderId = (order['orderId'] ?? order['order_id'] ?? order['id'] ?? '').toString();
      if (keyId.isEmpty || orderId.isEmpty) {
        throw TaxiApiException('Could not start the payment. Please try again.');
      }

      ref.read(razorpayServiceProvider).open(
            request: RazorpayCheckoutRequest(
              keyId: keyId,
              orderId: orderId,
              // Rupees — the service converts to paise. The order's own
              // `amount` is already in paise and would charge 100x.
              amount: widget.amount,
              name: 'Ride payment',
              description: 'Fare for your trip',
              contact: user?.phone,
              email: user?.email,
            ),
            onSuccess: (PaymentSuccessResponse response) async {
              try {
                // Settled only once the server verifies the signature.
                await ref.read(rideRepositoryProvider).verifyCompletionPayment(
                  widget.rideId,
                  {
                    'razorpay_payment_id': response.paymentId,
                    'razorpay_order_id': response.orderId,
                    'razorpay_signature': response.signature,
                  },
                );
                if (!mounted) return;
                SnackbarUtils.success(context, 'Payment successful');
                Navigator.of(context).pop(true);
              } on TaxiApiException catch (e) {
                if (mounted) {
                  SnackbarUtils.error(context, 'Paid but not confirmed: ${e.message}');
                }
                _setBusy(false);
              }
            },
            onError: (PaymentFailureResponse response) {
              if (mounted) {
                SnackbarUtils.error(context, response.message ?? 'Payment failed or cancelled');
              }
              _setBusy(false);
            },
          );
    } on TaxiApiException catch (e) {
      if (mounted) SnackbarUtils.error(context, e.message);
      _setBusy(false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 24,
        bottom: 24 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Pay for your ride',
            style: Theme.of(context).textTheme.titleLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '₹${widget.amount.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w600,
              color: TaxiColors.primary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: _busy ? null : _payWithRazorpay,
            icon: const Icon(Icons.credit_card),
            label: const Text('Pay online'),
          ),
          const SizedBox(height: 10),
          OutlinedButton.icon(
            onPressed: _busy ? null : _payWithWallet,
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: const Text('Pay from wallet'),
          ),
          if (_busy) ...[
            const SizedBox(height: 18),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }
}
