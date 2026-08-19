import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/modules/taxi/application/taxi_core_providers.dart';
import 'package:superapp_user/modules/taxi/wallet/data/models/wallet_transaction_model.dart';
import 'package:superapp_user/modules/taxi/wallet/data/wallet_repository.dart';

/// Ride-side wallet reads, backed by `/api/v1/taxi/users/wallet`.
///
/// Follow-up — this is the one place where getting the merge wrong costs real
/// money. Food reads its balance from `/food/user/wallet`, this reads from the
/// ride side, and the two must never be summed and shown as one figure: the
/// user cannot spend the total on either side, and concurrent debits against
/// two ledgers cannot be reconciled. The shared-wallet pass reads a single
/// authoritative balance; per-module history stays a read-only merged view.
final taxiWalletRepositoryProvider = Provider<TaxiWalletRepository>((ref) {
  return TaxiWalletRepository(ref.watch(taxiApiClientProvider));
});

final walletBalanceProvider = FutureProvider<double>((ref) {
  return ref.watch(taxiWalletRepositoryProvider).getBalance();
});

final walletTransactionsProvider =
    FutureProvider<List<WalletTransactionModel>>((ref) {
  return ref.watch(taxiWalletRepositoryProvider).getTransactions();
});
