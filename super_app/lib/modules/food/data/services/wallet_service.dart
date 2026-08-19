import 'package:superapp_user/modules/food/data/contracts/wallet_repository.dart';
import 'package:superapp_user/shared/wallet/data/wallet_model.dart';

class WalletService {
  final WalletRepository _repository;

  const WalletService(this._repository);

  /// A wallet with no top-ups/cashback yet legitimately has zero balance and
  /// no transactions — that's real data, not a loading/error state, so it's
  /// returned as-is rather than papered over with sample rows.
  Future<WalletModel> fetchWalletData() => _repository.getWallet();

  Future<CashbackHistory> fetchCashbackHistory() => _repository.getCashbackHistory();

  Future<RefundHistory> fetchRefundHistory() => _repository.getRefundHistory();

  Future<CashbackSettings> fetchCashbackSettings() => _repository.getCashbackSettings();

  /// Business validation for top up amount.
  bool isValidTopupAmount(double amount) {
    return amount >= 10 && amount <= 10000;
  }
}
