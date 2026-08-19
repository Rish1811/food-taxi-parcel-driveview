import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superapp_user/modules/taxi/application/taxi_core_providers.dart';
import 'package:superapp_user/modules/taxi/promo/data/models/promo_model.dart';
import 'package:superapp_user/modules/taxi/promo/data/promo_repository.dart';

final promoRepositoryProvider = Provider<PromoRepository>((ref) {
  return PromoRepository(ref.watch(taxiApiClientProvider));
});

final availablePromosProvider = FutureProvider<List<PromoModel>>((ref) {
  return ref.watch(promoRepositoryProvider).getAvailablePromos();
});
