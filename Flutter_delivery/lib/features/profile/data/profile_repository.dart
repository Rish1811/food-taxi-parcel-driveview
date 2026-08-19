import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import '../../auth/data/models/delivery_partner.dart';

class ProfileRepository {
  ProfileRepository(this._dio);

  final Dio _dio;

  Future<Result<DeliveryPartner, AppError>> updateProfile(
    Map<String, dynamic> fields,
  ) => _patch(ApiEndpoints.profile, fields);

  Future<Result<DeliveryPartner, AppError>> updateProfileDetails(
    Map<String, dynamic> fields,
  ) => _patch(ApiEndpoints.profileDetails, fields);

  Future<Result<DeliveryPartner, AppError>> updateBankDetails({
    required String accountHolderName,
    required String accountNumber,
    required String ifscCode,
    required String bankName,
    String? upiId,
  }) => _patch(ApiEndpoints.profileBankDetails, {
    'bankAccountHolderName': accountHolderName,
    'bankAccountNumber': accountNumber,
    'bankIfscCode': ifscCode,
    'bankName': bankName,
    if (upiId != null) 'upiId': upiId,
  });

  Future<Result<DeliveryPartner, AppError>> uploadProfilePhotoBase64(
    String base64Image,
  ) => _patch(ApiEndpoints.profilePhotoBase64, {'photo': base64Image});

  Future<Result<DeliveryPartner, AppError>> updateAvailability(
    bool isOnline, {
    double? lat,
    double? lng,
  }) => _patch(ApiEndpoints.availability, {
    'status': isOnline ? 'online' : 'offline',
    // Backend reads `latitude`/`longitude` (DELIVERY_API_SPEC.md §3) — `lat`/`lng`
    // are silently ignored, leaving lastLat/lastLng unset and the partner
    // invisible to dispatch's nearby-partner radius search.
    if (lat != null) 'latitude': lat,
    if (lng != null) 'longitude': lng,
  });

  Future<Result<void, AppError>> deleteAccount() async {
    try {
      await _dio.delete(ApiEndpoints.deleteAccount);
      return const Result.success(null);
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<DeliveryPartner, AppError>> reverify(
    FormData formData,
  ) async {
    try {
      final res = await _dio.post(ApiEndpoints.reverify, data: formData);
      final data = res.data['data'] as Map<String, dynamic>;
      return Result.success(DeliveryPartner.fromJson(data));
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<DeliveryPartner, AppError>> _patch(
    String path,
    Map<String, dynamic> data,
  ) async {
    try {
      final res = await _dio.patch(path, data: data);
      final body = res.data['data'] as Map<String, dynamic>;
      final user = body['user'] ?? body;
      return Result.success(DeliveryPartner.fromJson(user as Map<String, dynamic>));
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  AppError _mapError(DioException e) {
    final responseData = e.response?.data;
    final message = responseData is Map<String, dynamic>
        ? (responseData['message'] as String? ??
              responseData['error'] as String? ??
              e.message ??
              'Something went wrong')
        : (e.message ?? 'Something went wrong');
    return NetworkError(message);
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.read(dioProvider));
});
