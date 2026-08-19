import 'package:superapp_user/modules/food/data/contracts/wallet_repository.dart';
import 'package:superapp_user/shared/profile/data/account_remote_datasource.dart';
import 'package:superapp_user/shared/wallet/data/wallet_model.dart';

class WalletRepositoryImpl implements WalletRepository {
  final AccountRemoteDataSource _remoteDataSource;

  const WalletRepositoryImpl(this._remoteDataSource);

  @override
  Future<WalletModel> getWallet() async {
    return await _remoteDataSource.getWallet();
  }

  @override
  Future<Map<String, dynamic>> createTopupOrder(double amount) async {
    return await _remoteDataSource.createTopupOrder(amount);
  }

  @override
  Future<WalletModel> verifyTopup({
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
    required double amount,
  }) async {
    return await _remoteDataSource.verifyTopup(
      razorpayOrderId: razorpayOrderId,
      razorpayPaymentId: razorpayPaymentId,
      razorpaySignature: razorpaySignature,
      amount: amount,
    );
  }

  @override
  Future<CashbackHistory> getCashbackHistory() => _remoteDataSource.getCashbackHistory();

  @override
  Future<RefundHistory> getRefundHistory() => _remoteDataSource.getRefundHistory();

  @override
  Future<CashbackSettings> getCashbackSettings() => _remoteDataSource.getCashbackSettings();
}
