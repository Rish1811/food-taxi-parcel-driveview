import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/error/result.dart';
import 'package:food_user_application/core/network/api_endpoints.dart';
import 'package:food_user_application/core/network/dio_client.dart';
import 'package:food_user_application/features/refer_earn/data/models/referral_stats.dart';

class ReferralRepository {
  ReferralRepository(this._dio);
  final Dio _dio;

  Future<Result<ReferralStats, AppError>> getReferralStats() async {
    try {
      final res = await _dio.get(ApiEndpoints.referralStats);
      final body = res.data['data'] as Map<String, dynamic>? ?? res.data as Map<String, dynamic>;
      final data = body['stats'] as Map<String, dynamic>;
      return Result.success(ReferralStats.fromJson(data));
    } on DioException catch (e) {
      String msg = 'Failed to fetch referral stats';
      if (e.response?.data != null && e.response?.data['message'] != null) {
        msg = e.response?.data['message'] as String;
      }
      return Result.failure(NetworkError(msg));
    } catch (e) {
      return Result.failure(UnknownError(e.toString()));
    }
  }
}

final referralRepositoryProvider = Provider<ReferralRepository>((ref) {
  return ReferralRepository(ref.read(dioProvider));
});
