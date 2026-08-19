import 'package:superapp_user/modules/taxi/api/taxi_endpoints.dart';
import 'package:superapp_user/core/network/taxi_api_client.dart';
import 'package:superapp_user/modules/taxi/subscription/data/models/subscription_plan_model.dart';

class SubscriptionRepository {
  final TaxiApiClient api;

  SubscriptionRepository(this.api);

  Future<List<SubscriptionPlanModel>> getPlans() async {
    final data = await api.get(ApiConstants.subscriptionPlans);
    final results = (data['results'] as List? ?? []);
    return results.map((e) => SubscriptionPlanModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<SubscriptionSummaryModel> getMySummary() async {
    final data = await api.get(ApiConstants.mySubscriptions);
    return SubscriptionSummaryModel.fromJson(Map<String, dynamic>.from(data));
  }

  Future<UserSubscriptionModel> purchase(String planId) async {
    final data = await api.post(ApiConstants.buySubscription, data: {'planId': planId});
    return UserSubscriptionModel.fromJson(Map<String, dynamic>.from(data['subscription'] ?? {}));
  }
}
