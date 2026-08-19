import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import 'models/delivery_order.dart';

class OrdersRepository {
  OrdersRepository(this._dio);

  final Dio _dio;

  Future<Result<List<DeliveryOrder>, AppError>> getAvailableOrders({
    int page = 1,
    int limit = 20,
  }) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.ordersAvailable,
        queryParameters: {'page': page, 'limit': limit},
      );
      final data = res.data['data'];
      final list = (data is Map<String, dynamic> ? data['data'] : data)
          as List<dynamic>?;
      final orders = (list ?? [])
          .whereType<Map<String, dynamic>>()
          .map(DeliveryOrder.fromJson)
          .toList();
      return Result.success(orders);
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<DeliveryOrder?, AppError>> getCurrentOrder() async {
    try {
      final res = await _dio.get(ApiEndpoints.ordersCurrent);
      final data = res.data['data'] as Map<String, dynamic>?;
      final activeOrder = data?['activeOrder'];
      if (activeOrder == null) return const Result.success(null);
      return Result.success(
        DeliveryOrder.fromJson(activeOrder as Map<String, dynamic>),
      );
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<DeliveryOrder, AppError>> getOrderDetails(
    String orderId,
  ) async {
    try {
      final res = await _dio.get(ApiEndpoints.orderDetails(orderId));
      final data = res.data['data'] as Map<String, dynamic>;
      final order = data['order'] ?? data;
      return Result.success(DeliveryOrder.fromJson(order as Map<String, dynamic>));
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<DeliveryOrder, AppError>> accept(String orderId) =>
      _patchOrder(ApiEndpoints.orderAccept(orderId));

  Future<Result<DeliveryOrder, AppError>> reject(String orderId) =>
      _patchOrder(ApiEndpoints.orderReject(orderId));

  Future<Result<DeliveryOrder, AppError>> reachedPickup(String orderId) =>
      _patchOrder(ApiEndpoints.orderReachedPickup(orderId));

  Future<Result<DeliveryOrder, AppError>> confirmPickup(
    String orderId, {
    String? billImageUrl,
  }) => _patchOrder(
    ApiEndpoints.orderConfirmPickup(orderId),
    data: billImageUrl != null ? {'billImageUrl': billImageUrl} : null,
  );

  Future<Result<DeliveryOrder, AppError>> reachedDrop(String orderId) =>
      _patchOrder(ApiEndpoints.orderReachedDrop(orderId));

  Future<Result<DeliveryOrder, AppError>> verifyDropOtp(
    String orderId,
    String otp,
  ) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.orderVerifyDropOtp(orderId),
        data: {'otp': otp},
      );
      final data = res.data['data'] as Map<String, dynamic>;
      final order = data['order'] ?? data;
      return Result.success(DeliveryOrder.fromJson(order as Map<String, dynamic>));
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<DeliveryOrder, AppError>> complete(String orderId) =>
      _patchOrder(ApiEndpoints.orderComplete(orderId));

  Future<Result<Map<String, dynamic>, AppError>> collectQr(
    String orderId, {
    String? name,
    String? email,
    String? phone,
  }) async {
    try {
      final res = await _dio.post(
        ApiEndpoints.collectQr(orderId),
        data: {
          if (name != null) 'name': name,
          if (email != null) 'email': email,
          if (phone != null) 'phone': phone,
        },
      );
      return Result.success(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<Map<String, dynamic>, AppError>> paymentStatus(
    String orderId,
  ) async {
    try {
      final res = await _dio.get(ApiEndpoints.paymentStatus(orderId));
      return Result.success(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<Map<String, dynamic>, AppError>> getRoute(
    String orderId, {
    required double lat,
    required double lng,
    required String target,
  }) async {
    try {
      final res = await _dio.get(
        ApiEndpoints.orderRoute(orderId),
        queryParameters: {'lat': lat, 'lng': lng, 'target': target},
      );
      return Result.success(res.data['data'] as Map<String, dynamic>);
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<bool, AppError>> collectCash(String orderId) async {
    try {
      final res = await _dio.post(ApiEndpoints.collectCash(orderId));
      final data = res.data['data'] as Map<String, dynamic>?;
      return Result.success(data?['success'] as bool? ?? true);
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<bool, AppError>> rateCustomer(
    String orderId, {
    required int rating,
    String? comment,
  }) async {
    try {
      final res = await _dio.patch(
        ApiEndpoints.orderRateCustomer(orderId),
        data: {
          'rating': rating,
          if (comment != null && comment.isNotEmpty) 'comment': comment,
        },
      );
      return Result.success(res.data['success'] as bool? ?? true);
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<DeliveryOrder, AppError>> _patchOrder(
    String path, {
    Object? data,
  }) async {
    try {
      final res = await _dio.patch(path, data: data);
      final body = res.data['data'] as Map<String, dynamic>;
      final order = body['order'] ?? body;
      return Result.success(DeliveryOrder.fromJson(order as Map<String, dynamic>));
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  AppError _mapError(DioException e) {
    final responseData = e.response?.data;

    // The server's own message when it sends one — that is always the most
    // useful thing to show.
    final serverMessage = responseData is Map<String, dynamic>
        ? (responseData['message'] as String? ??
            responseData['error'] as String?)
        : null;
    if (serverMessage != null && serverMessage.isNotEmpty) {
      return NetworkError(serverMessage);
    }

    // Never fall back to DioException.message. For a bad status code Dio
    // returns a multi-paragraph explanation of HTTP semantics and a link to
    // MDN — which ended up rendered inside the rating dialog, in red, as if it
    // were advice for the rider.
    final status = e.response?.statusCode;
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return NetworkError('No connection. Check your network and try again.');
      default:
        if (status == null) return NetworkError('Something went wrong. Please try again.');
        if (status == 401 || status == 403) {
          return NetworkError('You are not allowed to do that.');
        }
        if (status == 404) {
          return NetworkError('That is not available right now.');
        }
        if (status >= 500) {
          return NetworkError('The server had a problem. Please try again.');
        }
        return NetworkError('Request failed ($status). Please try again.');
    }
  }
}

final ordersRepositoryProvider = Provider<OrdersRepository>((ref) {
  return OrdersRepository(ref.read(dioProvider));
});
