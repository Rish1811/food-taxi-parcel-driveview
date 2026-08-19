import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:razorpay_flutter/razorpay_flutter.dart';
import 'package:superapp_user/modules/taxi/application/taxi_core_providers.dart';
import 'package:superapp_user/core/payment/taxi_razorpay_service.dart';
import 'package:superapp_user/design_system/components/feedback/taxi_snackbar_utils.dart';
import 'package:superapp_user/design_system/components/ride/app_text_field.dart';
import 'package:superapp_user/design_system/components/ride/primary_button.dart';
import 'package:superapp_user/modules/taxi/auth/application/auth_providers.dart';
import 'package:superapp_user/modules/taxi/wallet/application/wallet_providers.dart';

const _quickAmounts = [100.0, 200.0, 500.0, 1000.0];

class TopupSheet extends ConsumerStatefulWidget {
  const TopupSheet({super.key});

  @override
  ConsumerState<TopupSheet> createState() => _TopupSheetState();
}

class _TopupSheetState extends ConsumerState<TopupSheet> {
  final _amountController = TextEditingController();
  bool _processing = false;

  @override
  void dispose() {
    _amountController.dispose();
    super.dispose();
  }

  Future<void> _startTopup() async {
    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount < 10) {
      SnackbarUtils.error(context, 'Enter a valid amount (min ₹10)');
      return;
    }

    setState(() => _processing = true);
    try {
      final order = await ref.read(taxiWalletRepositoryProvider).createTopupOrder(amount);
      final user = ref.read(authControllerProvider).user;

      ref.read(razorpayServiceProvider).open(
            request: RazorpayCheckoutRequest(
              keyId: order.keyId,
              orderId: order.orderId,
              amount: amount,
              name: 'Wallet top-up',
              description: 'Add money to wallet',
              contact: user?.phone,
              email: user?.email,
            ),
            onSuccess: (PaymentSuccessResponse response) async {
              try {
                await ref.read(taxiWalletRepositoryProvider).verifyTopupPayment({
                  'razorpay_payment_id': response.paymentId,
                  'razorpay_order_id': response.orderId,
                  'razorpay_signature': response.signature,
                });
                ref.invalidate(walletBalanceProvider);
                ref.invalidate(walletTransactionsProvider);
                if (mounted) {
                  Navigator.of(context).pop();
                  SnackbarUtils.success(context, 'Wallet topped up successfully');
                }
              } catch (e) {
                if (mounted) SnackbarUtils.error(context, 'Payment verification failed');
              }
            },
            onError: (PaymentFailureResponse response) {
              if (mounted) SnackbarUtils.error(context, response.message ?? 'Payment failed');
            },
          );
    } catch (e) {
      if (mounted) SnackbarUtils.error(context, 'Could not start payment');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Add money', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        AppTextField(
          controller: _amountController,
          label: 'Amount',
          hint: 'Enter amount',
          prefixIcon: Icons.currency_rupee_rounded,
          keyboardType: TextInputType.number,
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          children: _quickAmounts
              .map(
                (amount) => ActionChip(
                  label: Text('₹${amount.toInt()}'),
                  onPressed: () => _amountController.text = amount.toInt().toString(),
                ),
              )
              .toList(),
        ),
        const SizedBox(height: 24),
        TaxiPrimaryButton(label: 'Proceed to pay', isLoading: _processing, onPressed: _startTopup),
      ],
    );
  }
}
