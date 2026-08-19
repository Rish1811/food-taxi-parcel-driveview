import 'package:superapp_user/modules/taxi/api/taxi_endpoints.dart';
import 'package:superapp_user/core/network/taxi_api_client.dart';
import 'package:superapp_user/modules/taxi/promo/data/models/promo_model.dart';

class PromoRepository {
  final TaxiApiClient api;

  PromoRepository(this.api);

  Future<List<PromoModel>> getAvailablePromos() async {
    final data = await api.get(ApiConstants.promoAvailable);
    final results = (data is Map ? (data['results'] ?? data['promos']) : data) as List? ?? [];
    return results.map((e) => PromoModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  Future<Map<String, dynamic>> validatePromo({required String code, required double fare}) async {
    final data = await api.post(ApiConstants.promoValidate, data: {'code': code, 'fare': fare});
    return Map<String, dynamic>.from(data);
  }
}
