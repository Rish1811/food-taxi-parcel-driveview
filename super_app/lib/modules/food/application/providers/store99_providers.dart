import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/modules/food/data/repositories/store99_repository_impl.dart';
import 'package:superapp_user/modules/food/data/contracts/store99_repository.dart';
import 'package:superapp_user/modules/food/data/services/store99_service.dart';
import 'package:superapp_user/modules/food/presentation/home/viewmodels/zone_viewmodel.dart';
import 'package:superapp_user/modules/food/application/providers/catalog_providers.dart';

final store99RepositoryProvider = Provider<Store99Repository>((ref) {
  return Store99RepositoryImpl(
    ref.watch(catalogRemoteDataSourceProvider),
    () => ref.read(currentZoneIdProvider),
  );
});

final store99ServiceProvider = Provider<Store99Service>((ref) {
  return Store99Service(ref.watch(store99RepositoryProvider));
});
