import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';

/// Whether the driver still owes today's selfie before they can go online for
/// rides.
class SelfieRequirement {
  const SelfieRequirement({required this.needed});

  final bool needed;

  static const notNeeded = SelfieRequirement(needed: false);
}

/// The **taxi** side of going online.
///
/// Deliberately separate from `ProfileRepository.updateAvailability`, which
/// writes the food delivery-partner document. Taxi dispatch
/// (`matchingService.js:79`) and ride acceptance (`rideService.js:1739`) both
/// filter on `Driver.isOnline`, a different field on a different collection —
/// so a driver who only calls the food endpoint is online for food orders and
/// permanently invisible to ride dispatch.
class DriverAvailabilityRepository {
  DriverAvailabilityRepository(this._dio);

  final Dio _dio;

  /// Does the driver need to take a selfie before going online today?
  ///
  /// The server keys it on the calendar date (`onlineSelfie.forDate`), so this
  /// asks rather than assuming — otherwise every shift would open with a
  /// camera the driver doesn't need.
  Future<Result<SelfieRequirement, AppError>> selfieStatus() async {
    try {
      final res = await _dio.get(ApiEndpoints.driverMe);
      final data = res.data is Map<String, dynamic>
          ? (res.data['data'] as Map<String, dynamic>? ?? const {})
          : const <String, dynamic>{};
      final driver = data['driver'] is Map<String, dynamic>
          ? data['driver'] as Map<String, dynamic>
          : data;
      final selfie = driver['onlineSelfie'];
      if (selfie is! Map) return const Result.success(SelfieRequirement(needed: true));

      final url = (selfie['imageUrl'] ?? '').toString().trim();
      final forDate = (selfie['forDate'] ?? '').toString();
      final today = DateTime.now().toUtc().toIso8601String().substring(0, 10);
      return Result.success(
        SelfieRequirement(needed: url.isEmpty || forDate != today),
      );
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<String, AppError>> uploadSelfie(String filePath) async {
    try {
      final form = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath),
        'folder': 'driver-selfies',
      });
      final res = await _dio.post(ApiEndpoints.uploadImage, data: form);
      final url = res.data is Map
          ? (res.data['data']?['url'] ?? '').toString()
          : '';
      if (url.isEmpty) {
        return Result.failure(UnknownError('Upload did not return an image'));
      }
      return Result.success(url);
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// [selfieImageUrl] may be omitted once the driver already has one on file
  /// for today; the server keeps the existing one in that case.
  Future<Result<void, AppError>> goOnline({
    required double lat,
    required double lng,
    String? selfieImageUrl,
  }) async {
    try {
      await _dio.patch(
        ApiEndpoints.driverOnline,
        data: {
          // GeoJSON order. The server validates the ranges, so a swapped pair
          // is accepted anywhere both values are plausible — which is most of
          // India — and silently mislocates the driver.
          'location': [lng, lat],
          if (selfieImageUrl != null && selfieImageUrl.isNotEmpty)
            'selfieImageUrl': selfieImageUrl,
        },
      );
      return const Result.success(null);
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<void, AppError>> goOffline() async {
    try {
      await _dio.patch(ApiEndpoints.driverOffline);
      return const Result.success(null);
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  AppError _mapError(DioException e) {
    final data = e.response?.data;
    final message = data is Map
        ? (data['message'] ?? data['error'])?.toString()
        : null;
    return NetworkError(message ?? e.message ?? 'Could not update ride status');
  }
}

final driverAvailabilityRepositoryProvider =
    Provider<DriverAvailabilityRepository>((ref) {
  return DriverAvailabilityRepository(ref.read(dioProvider));
});
