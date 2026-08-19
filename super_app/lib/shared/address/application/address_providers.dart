import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/modules/food/api/datasources/address_remote_datasource.dart';
import 'package:superapp_user/core/network/network_providers.dart';

final addressRemoteDataSourceProvider = Provider<AddressRemoteDataSource>((ref) {
  return AddressRemoteDataSource(ref.watch(apiClientProvider));
});
