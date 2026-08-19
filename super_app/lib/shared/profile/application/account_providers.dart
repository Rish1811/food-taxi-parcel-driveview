import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/shared/profile/data/account_remote_datasource.dart';
import 'package:superapp_user/core/network/network_providers.dart';

final accountRemoteDataSourceProvider = Provider<AccountRemoteDataSource>((ref) {
  return AccountRemoteDataSource(ref.watch(apiClientProvider));
});
