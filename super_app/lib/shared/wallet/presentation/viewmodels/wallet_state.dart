import 'package:superapp_user/shared/wallet/data/wallet_model.dart';

enum WalletStatus { initial, loading, success, error }

enum WalletFilterTab { all, creditsAndCashback, refunds }

class WalletState {
  final WalletStatus status;
  final WalletModel wallet;
  final WalletFilterTab selectedTab;
  final String? errorMessage;

  /// From `GET /food/user/cashback` — richer per-order total than what can be
  /// derived from the plain wallet ledger alone.
  final double totalCashbackEarned;

  /// From `GET /food/user/refunds`.
  final double totalRefunded;

  /// From `GET /food/admin/cashback-settings/public`. Null while loading/on
  /// failure — the banner simply doesn't render rather than guessing values.
  final CashbackSettings? cashbackSettings;

  final bool isToppingUp;

  const WalletState({
    this.status = WalletStatus.initial,
    this.wallet = const WalletModel(),
    this.selectedTab = WalletFilterTab.all,
    this.errorMessage,
    this.totalCashbackEarned = 0,
    this.totalRefunded = 0,
    this.cashbackSettings,
    this.isToppingUp = false,
  });

  List<WalletTransaction> get filteredTransactions {
    switch (selectedTab) {
      case WalletFilterTab.creditsAndCashback:
        return wallet.credits;
      case WalletFilterTab.refunds:
        return wallet.refunds;
      case WalletFilterTab.all:
        return wallet.transactions;
    }
  }

  WalletState copyWith({
    WalletStatus? status,
    WalletModel? wallet,
    WalletFilterTab? selectedTab,
    String? errorMessage,
    double? totalCashbackEarned,
    double? totalRefunded,
    CashbackSettings? cashbackSettings,
    bool? isToppingUp,
  }) {
    return WalletState(
      status: status ?? this.status,
      wallet: wallet ?? this.wallet,
      selectedTab: selectedTab ?? this.selectedTab,
      errorMessage: errorMessage ?? this.errorMessage,
      totalCashbackEarned: totalCashbackEarned ?? this.totalCashbackEarned,
      totalRefunded: totalRefunded ?? this.totalRefunded,
      cashbackSettings: cashbackSettings ?? this.cashbackSettings,
      isToppingUp: isToppingUp ?? this.isToppingUp,
    );
  }
}
