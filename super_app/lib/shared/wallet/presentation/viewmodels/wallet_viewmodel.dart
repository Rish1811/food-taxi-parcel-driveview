import 'dart:async';
import 'dart:developer' as developer;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/modules/food/application/providers/payment_providers.dart';
import 'package:superapp_user/shared/wallet/application/wallet_providers.dart';
import 'package:superapp_user/shared/auth/presentation/viewmodels/auth_viewmodel.dart';
import 'package:superapp_user/core/payment/payment_gateway.dart';
import 'package:superapp_user/shared/wallet/presentation/viewmodels/wallet_state.dart';

final walletViewModelProvider = NotifierProvider<WalletViewModel, WalletState>(
  () {
    return WalletViewModel();
  },
);

class WalletViewModel extends Notifier<WalletState> {
  @override
  WalletState build() {
    unawaited(Future.microtask(_loadAll));
    return const WalletState(status: WalletStatus.loading);
  }

  Future<void> _loadAll() async {
    await Future.wait([
      loadWallet(),
      _loadCashbackSummary(),
      _loadRefundSummary(),
      _loadCashbackSettings(),
    ]);
  }

  Future<void> loadWallet({bool isRefresh = false}) async {
    if (!isRefresh) {
      state = state.copyWith(status: WalletStatus.loading, errorMessage: null);
    } else {
      state = state.copyWith(errorMessage: null);
    }
    try {
      final service = ref.read(walletServiceProvider);
      final wallet = await service.fetchWalletData();
      state = state.copyWith(status: WalletStatus.success, wallet: wallet);
    } catch (e) {
      _log('loadWallet() failed: $e');
      state = state.copyWith(
        status: WalletStatus.error,
        errorMessage:
            'Failed to load wallet information. Please check your connection.',
      );
    }
  }

  Future<void> _loadCashbackSummary() async {
    try {
      final history = await ref
          .read(walletServiceProvider)
          .fetchCashbackHistory();
      state = state.copyWith(totalCashbackEarned: history.totalEarned);
    } catch (e) {
      // Non-fatal — the balance card and transaction list still work.
      _log('_loadCashbackSummary() failed: $e');
    }
  }

  Future<void> _loadRefundSummary() async {
    try {
      final history = await ref
          .read(walletServiceProvider)
          .fetchRefundHistory();
      state = state.copyWith(totalRefunded: history.totalRefunded);
    } catch (e) {
      // Non-fatal.
      _log('_loadRefundSummary() failed: $e');
    }
  }

  Future<void> _loadCashbackSettings() async {
    try {
      final settings = await ref
          .read(walletServiceProvider)
          .fetchCashbackSettings();
      state = state.copyWith(cashbackSettings: settings);
    } catch (e) {
      // Banner just doesn't show.
      _log('_loadCashbackSettings() failed: $e');
    }
  }

  void _log(String msg) {
    if (kDebugMode) developer.log(msg, name: 'Wallet');
  }

  void setFilterTab(WalletFilterTab tab) {
    state = state.copyWith(selectedTab: tab);
  }

  /// Real Razorpay top-up: creates the order, opens the sheet, verifies, then
  /// reloads the wallet from the server so the balance shown is never a
  /// locally-guessed number.
  Future<String> addMoney(double amount) async {
    final service = ref.read(walletServiceProvider);
    if (!service.isValidTopupAmount(amount)) {
      return 'Enter an amount between ₹10 and ₹10,000.';
    }

    final user = ref.read(authViewModelProvider).value;
    state = state.copyWith(isToppingUp: true);
    try {
      final result = await ref
          .read(paymentGatewayProvider)
          .topUp(
            amount: amount,
            customerName: user?.name ?? '',
            customerPhone: user?.phone ?? '',
            customerEmail: user?.email,
          );
      if (result.outcome == PaymentOutcome.success) {
        await loadWallet();
      }
      return result.message;
    } finally {
      state = state.copyWith(isToppingUp: false);
    }
  }
}
