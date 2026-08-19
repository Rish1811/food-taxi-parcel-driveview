import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superapp_user/modules/taxi/application/taxi_core_providers.dart';
import 'package:superapp_user/modules/taxi/subscription/data/models/subscription_plan_model.dart';
import 'package:superapp_user/modules/taxi/subscription/data/subscription_repository.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(ref.watch(taxiApiClientProvider));
});

final subscriptionPlansProvider = FutureProvider.autoDispose<List<SubscriptionPlanModel>>((ref) {
  return ref.watch(subscriptionRepositoryProvider).getPlans();
});

final mySubscriptionSummaryProvider = FutureProvider.autoDispose<SubscriptionSummaryModel>((ref) {
  return ref.watch(subscriptionRepositoryProvider).getMySummary();
});
