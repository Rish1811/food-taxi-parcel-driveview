import 'package:superapp_user/shared/wallet/data/wallet_model.dart';

/// Domain repository abstraction for user wallet operations.
abstract class WalletRepository {
  /// Fetches the user's current wallet balance and transaction ledger.
  Future<WalletModel> getWallet();

  /// Creates a Razorpay order for wallet top-up.
  Future<Map<String, dynamic>> createTopupOrder(double amount);

  /// Verifies a Razorpay payment after a wallet top-up.
  Future<WalletModel> verifyTopup({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
    required double amount,
  });

  Future<CashbackHistory> getCashbackHistory();

  Future<RefundHistory> getRefundHistory();

  Future<CashbackSettings> getCashbackSettings();
}
