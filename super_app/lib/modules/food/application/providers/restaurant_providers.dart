import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/modules/food/data/repositories/restaurant_repository_impl.dart';
import 'package:superapp_user/modules/food/data/contracts/restaurant_repository.dart';
import 'package:superapp_user/modules/food/data/services/restaurant_service.dart';
import 'package:superapp_user/modules/food/presentation/home/viewmodels/zone_viewmodel.dart';
import 'package:superapp_user/modules/food/application/providers/catalog_providers.dart';

final restaurantRepositoryProvider = Provider<RestaurantRepository>((ref) {
  return RestaurantRepositoryImpl(
    ref.watch(catalogRemoteDataSourceProvider),
    // Read (not watch) through a callback so a zone arriving later is picked up
    // on the next call without rebuilding the repository mid-flight.
    () => ref.read(currentZoneIdProvider),
  );
});

final restaurantServiceProvider = Provider<RestaurantService>((ref) {
  return RestaurantService(ref.watch(restaurantRepositoryProvider));
});
