import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import 'models/taxi_ride.dart';

/// Driver-side taxi API.
///
/// Mirrors `OrdersRepository` on the food side: takes the shared [Dio] (which
/// already carries the bearer via the auth interceptor) and returns [Result]
/// rather than throwing, so controllers never need try/catch.
class RidesRepository {
  RidesRepository(this._dio);

  final Dio _dio;

  /// The ride this driver is currently on, or null.
  ///
  /// This is the recovery path: a socket cannot replay events missed while the
  /// app was killed, so the active trip is always re-read from here on launch.
  Future<Result<TaxiRide?, AppError>> getActiveRide() async {
    try {
      final res = await _dio.get(ApiEndpoints.rideActive);
      final payload = _unwrap(res.data);
      final ride = payload is Map<String, dynamic>
          ? (payload['ride'] ?? payload['activeRide'] ?? payload)
          : null;
      if (ride is! Map<String, dynamic> || ride.isEmpty) {
        return const Result.success(null);
      }
      final parsed = TaxiRide.fromJson(ride);
      // A finished ride is not an active one; the endpoint occasionally
      // returns the last ride rather than null.
      return Result.success(parsed.stage.isFinished ? null : parsed);
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<TaxiRide, AppError>> getRide(String rideId) async {
    try {
      final res = await _dio.get(ApiEndpoints.rideById(rideId));
      final payload = _unwrap(res.data);
      final ride = payload is Map<String, dynamic>
          ? (payload['ride'] ?? payload)
          : payload;
      return Result.success(TaxiRide.fromJson(ride as Map<String, dynamic>));
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Advances a ride this driver already holds.
  ///
  /// Only accepted / arriving / started / arrived / completed are accepted, and
  /// the server rejects out-of-order moves with 409, so callers move one
  /// [RideStage] at a time. It also looks the ride up by `{_id, driverId}` — so
  /// this cannot be used to *claim* an offer; that goes over the socket.
  ///
  /// [otp] is mandatory for [RideStage.started]; [fare] and [paymentMethod]
  /// matter on [RideStage.completed], where the server records what the driver
  /// actually collected.
  /// Cash-in-hand is NOT reported here. `driverPaymentCollection` on the ride
  /// is the Razorpay collection-link record (provider, providerId, linkUrl,
  /// status) — an object, not a flag. Sending a boolean into it made
  /// `ride.save()` throw
  /// `Cast to Object failed for value "true" at path "driverPaymentCollection"`
  /// at the exact moment the driver took the money, so the trip could not be
  /// completed. The server settles cash from `paymentMethod` alone
  /// (`settleCompletedRideWallet`), so that field is all it needs.
  Future<Result<TaxiRide, AppError>> setStage(
    String rideId,
    RideStage stage, {
    String? otp,
    String? paymentMethod,
    double? fare,
  }) async {
    try {
      final res = await _dio.patch(
        ApiEndpoints.rideStatus(rideId),
        data: {
          'status': stage.wire,
          if (otp != null && otp.isNotEmpty) 'otp': otp,
          if (paymentMethod != null) 'paymentMethod': paymentMethod,
          if (fare != null) 'fare': fare,
        },
      );
      final payload = _unwrap(res.data);
      final ride = payload is Map<String, dynamic>
          ? (payload['ride'] ?? payload)
          : payload;
      if (ride is Map<String, dynamic> && ride.isNotEmpty) {
        return Result.success(TaxiRide.fromJson(ride));
      }
      // Some transitions return only an acknowledgement — re-read rather than
      // guessing the resulting state.
      return getRide(rideId);
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// Completed and cancelled rides for this driver, newest first.
  ///
  /// Returned as raw maps rather than [TaxiRide]: the history screen renders
  /// food orders and rides through one card, and normalising both into the
  /// same shape is what lets a driver see one chronological day rather than
  /// two lists they have to interleave in their head.
  Future<Result<List<Map<String, dynamic>>, AppError>> getRideHistory({
    int limit = 100,
    int page = 1,
  }) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.rides,
        queryParameters: {'limit': limit, 'page': page},
      );
      final payload = _unwrap(res.data);
      final list = payload is Map<String, dynamic> ? payload['results'] : payload;
      final rides = (list as List<dynamic>? ?? const [])
          .whereType<Map<String, dynamic>>()
          .toList();
      return Result.success(rides);
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<void, AppError>> cancel(String rideId, {String? reason}) async {
    try {
      await _dio.patch(
        ApiEndpoints.rideCancel(rideId),
        data: {if (reason != null && reason.isNotEmpty) 'reason': reason},
      );
      return const Result.success(null);
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  /// k9 wraps most responses as `{ success, message, data }`, but a few return
  /// the body directly. Unwrap once here so no call site has to care.
  static dynamic _unwrap(dynamic body) {
    if (body is Map<String, dynamic> && body.containsKey('data')) {
      return body['data'];
    }
    return body;
  }

  AppError _mapError(DioException e) {
    final data = e.response?.data;
    final message = data is Map
        ? (data['message'] ?? data['error'])?.toString()
        : null;
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return NetworkError(message ?? 'No connection. Check your network.');
    }
    return UnknownError(message ?? 'Something went wrong. Please try again.');
  }
}

final ridesRepositoryProvider = Provider<RidesRepository>((ref) {
  return RidesRepository(ref.read(dioProvider));
});
