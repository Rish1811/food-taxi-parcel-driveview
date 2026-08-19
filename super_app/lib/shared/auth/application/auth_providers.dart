import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/modules/food/api/datasources/auth_remote_datasource.dart';
import 'package:superapp_user/modules/food/data/repositories/auth_repository_impl.dart';
import 'package:superapp_user/modules/food/data/contracts/auth_repository.dart';
import 'package:superapp_user/core/network/network_providers.dart';

final authRemoteDataSourceProvider = Provider<AuthRemoteDataSource>((ref) {
  return AuthRemoteDataSource(ref.watch(apiClientProvider));
});

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(
    ref.watch(authRemoteDataSourceProvider),
    ref.watch(tokenStorageProvider),
  );
});
