import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/modules/food/data/repositories/wallet_repository_impl.dart';
import 'package:superapp_user/modules/food/data/contracts/wallet_repository.dart';
import 'package:superapp_user/modules/food/data/services/wallet_service.dart';
import 'package:superapp_user/shared/profile/application/account_providers.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  final remote = ref.watch(accountRemoteDataSourceProvider);
  return WalletRepositoryImpl(remote);
});

final walletServiceProvider = Provider<WalletService>((ref) {
  final repository = ref.watch(walletRepositoryProvider);
  return WalletService(repository);
});
