import 'package:superapp_user/core/error/failures.dart';
import 'package:flutter/foundation.dart';
import 'package:superapp_user/core/config/api_config.dart';
import 'package:superapp_user/core/network/api_client.dart';
import 'package:superapp_user/modules/food/data/models/cart_item_model.dart';
import 'package:superapp_user/modules/food/data/models/food_model.dart';
import 'package:superapp_user/modules/food/data/models/order_model.dart';
import 'package:superapp_user/modules/food/data/models/order_pricing.dart';

/// Transport for cart sync and the order lifecycle.
class OrderRemoteDataSource {
  final ApiClient _client;

  const OrderRemoteDataSource(this._client);

  /// The server id of the variant the cart line named.
  ///
  /// Falls back to the name when the dish has no matching variant — the server
  /// will reject it either way, and a wrong id is no worse than the name that
  /// was being sent before, whereas an empty string would silently check out at
  /// the base price.
  static String _variantIdFor(FoodModel food, String variantName) {
    for (final v in food.variants) {
      if (v.name == variantName || v.id == variantName || v.serverId == variantName) {
        return v.id;
      }
    }
    return variantName;
  }

  /// Item payload shared by `/calculate` and `POST /orders`.
  ///
  /// `price` is the unit price *including* the chosen variant and add-ons, so
  /// the server's subtotal matches what the user was shown. Variant identity
  /// travels separately in `variantName` / `variantPrice`, which the order
  /// schema records on the line.
  static Map<String, dynamic> itemPayload(CartItemModel item) {
    final variantName =
        (item.selectedVariant != null && item.selectedVariant!.isNotEmpty)
            ? item.selectedVariant!
            : null;
    final hasVariant = variantName != null && variantName.isNotEmpty;
    final variantPrice = hasVariant
        ? (item.selectedVariantPrice > 0
            ? (item.food.price + item.selectedVariantPrice)
            : item.food.price)
        : item.food.price;

    final resolvedVariantId = hasVariant ? _variantIdFor(item.food, variantName) : null;

    return {
      'itemId': item.food.id,
      'name': item.food.name,
      // The unit price the user was actually shown/charged: base + variant +
      // add-ons. Sending the bare base price here was the bug — the server
      // bills off this field, so a base-only price silently dropped every
      // variant/add-on charge from the order regardless of what `variantPrice`
      // / `addons` below recorded for display.
      'price': item.unitPrice,
      'quantity': item.quantity,
      'itemTotal': item.totalPrice,
      'isVeg': item.food.isVeg,
      'image': item.food.imageUrl,
      if (hasVariant) ...{
        'variantId': resolvedVariantId,
        'variantName': variantName,
        'variantPrice': variantPrice,
      },
      if (item.selectedAddons.isNotEmpty) ...{
        'addons': item.selectedAddons,
        'addonsPrice': item.selectedAddonsPrice,
      },
      if (item.specialInstructions?.isNotEmpty ?? false)
        'notes': item.specialInstructions,
    };
  }

  /// `POST /food/orders/calculate` — the only source of truth for the bill.
  Future<OrderCalculation> calculate({
    required List<CartItemModel> items,
    required String restaurantId,
    String? deliveryAddressId,
    String? zoneId,
    String? couponCode,
    String deliveryMode = 'basic',
    DateTime? scheduledAt,
  }) async {
    final payload = {
      'items': items.map(itemPayload).toList(),
      'restaurantId': restaurantId,
      'deliveryAddressId': ?deliveryAddressId,
      'zoneId': ?zoneId,
      'couponCode': ?couponCode,
      'deliveryMode': deliveryMode,
      'scheduledAt': ?scheduledAt?.toUtc().toIso8601String(),
    };

    try {
      final data = await _client.post<Map<String, dynamic>>(
        ApiPaths.orderCalculate,
        body: payload,
      );
      return OrderCalculation.fromApi(data);
    } catch (e) {
      if (kDebugMode) debugPrint('[checkout] calculate failed: $e');
      rethrow;
    }
  }

  /// `POST /food/orders`. Echo back the exact `pricing` object `/calculate`
  /// returned — the server re-validates it.
  ///
  /// Returns `{ order, razorpay }`; `razorpay` is null for non-gateway methods.
  Future<Map<String, dynamic>> placeOrder({
    required List<CartItemModel> items,
    required String restaurantId,
    required String restaurantName,
    required Map<String, dynamic> address,
    required Map<String, dynamic> pricing,
    required String customerName,
    required String customerPhone,
    String paymentMethod = 'razorpay',
    String deliveryMode = 'basic',
    String? note,
    String? deliveryInstructions,
    bool sendCutlery = false,
    String? zoneId,
  }) async {
    final payload = {
      'items': items.map(itemPayload).toList(),
      'address': address,
      'restaurantId': restaurantId,
      'restaurantName': restaurantName,
      'customerName': customerName,
      'customerPhone': customerPhone,
      'pricing': pricing,
      'paymentMethod': paymentMethod,
      'deliveryMode': deliveryMode,
      'note': ?note,
      'deliveryInstructions': ?deliveryInstructions,
      'sendCutlery': sendCutlery,
      'zoneId': ?zoneId,
    };

    // Debug-only: the payload carries the customer's name, phone and full
    // address, so it must never reach a release log.
    if (kDebugMode) debugPrint('[checkout] POST ${ApiPaths.orders}');

    try {
      return await _client.post<Map<String, dynamic>>(
        ApiPaths.orders,
        body: payload,
      );
    } on Failure catch (failure) {
      // Surfaces the server's field-level reason (e.g. "address.state:
      // State required") instead of a generic placement failure.
      if (kDebugMode) debugPrint('[checkout] rejected: ${failure.message}');
      rethrow;
    }
  }

  /// `POST /food/orders/verify-payment` — all four fields required.
  ///
  /// Idempotent: an already-paid order returns success without reprocessing.
  Future<Map<String, dynamic>> verifyPayment({
    required String orderId,
    required String razorpayOrderId,
    required String razorpayPaymentId,
    required String razorpaySignature,
  }) {
    return _client.post<Map<String, dynamic>>(
      ApiPaths.verifyPayment,
      body: {
        'orderId': orderId,
        'razorpayOrderId': razorpayOrderId,
        'razorpayPaymentId': razorpayPaymentId,
        'razorpaySignature': razorpaySignature,
      },
    );
  }

  /// Call when the user dismisses the Razorpay sheet, so abandoned checkouts
  /// don't linger as ghost orders. Only valid while `pending_payment`.
  Future<void> discardPendingPayment(String orderId) async {
    await _client.delete<dynamic>(
      '${ApiPaths.orderById(orderId)}/pending-payment',
    );
  }

  Future<Map<String, dynamic>> getOrder(String orderId) =>
      _client.get<Map<String, dynamic>>(ApiPaths.orderById(orderId));

  /// Typed single order. `GET /food/orders/:orderId` → `{ order }`.
  Future<OrderModel> getOrderModel(String orderId) async {
    final data = await getOrder(orderId);
    final order = data['order'];
    return OrderModel.fromApi(
      order is Map ? order.cast<String, dynamic>() : data,
    );
  }

  /// Live route for the tracking map: `GET /food/orders/:orderId/route`.
  ///
  /// Returns `{ polyline, distanceKm, durationMins, target, origin, destination }`.
  /// The origin is the rider's last known position, resolved server-side — this
  /// endpoint takes no coordinates from us. `target` is derived from the order
  /// phase ('restaurant' before pickup, 'customer' after), so the polyline is
  /// always the leg the rider is actually on.
  Future<Map<String, dynamic>> getRoute(String orderId) =>
      _client.get<Map<String, dynamic>>('${ApiPaths.orderById(orderId)}/route');

  /// Handover OTP the customer reads to the rider at the door.
  Future<String?> getDropOtp(String orderId) async {
    final data = await _client.get<Map<String, dynamic>>(
      '${ApiPaths.orderById(orderId)}/drop-otp',
    );
    return data['otp']?.toString();
  }

  /// `PATCH /food/orders/:orderId/ratings` — restaurantRating is required 1-5.
  Future<void> rateOrder({
    required String orderId,
    required int restaurantRating,
    int? deliveryPartnerRating,
    String? restaurantComment,
    String? deliveryPartnerComment,
    List<Map<String, dynamic>>? itemRatings,
  }) async {
    await _client.patch<dynamic>(
      '${ApiPaths.orderById(orderId)}/ratings',
      body: {
        'restaurantRating': restaurantRating,
        'deliveryPartnerRating': ?deliveryPartnerRating,
        'restaurantComment': ?restaurantComment,
        'deliveryPartnerComment': ?deliveryPartnerComment,
        if (itemRatings != null && itemRatings.isNotEmpty)
          'itemRatings': itemRatings,
      },
    );
  }

  /// `GET /food/orders` — `{ data: [...], meta: {...} }`
  Future<({List<OrderModel> orders, int totalPages, int totalOrders, int? activeCount, int? pastCount})> getOrderModels({
    int page = 1,
    int limit = 50,
  }) async {
    final result = await getOrders(page: page, limit: limit);
    return (
      orders: result.orders.map(OrderModel.fromApi).toList(),
      totalPages: result.totalPages,
      totalOrders: result.totalOrders,
      activeCount: result.activeCount,
      pastCount: result.pastCount,
    );
  }

  Future<({List<Map<String, dynamic>> orders, int totalPages, int totalOrders, int? activeCount, int? pastCount})> getOrders({
    int page = 1,
    int limit = 50,
  }) async {
    final data = await _client.get<dynamic>(
      ApiPaths.orders,
      query: {'page': page, 'limit': limit},
    );
    if (data is List) {
      final list = data
          .whereType<Map>()
          .map((e) => e.cast<String, dynamic>())
          .toList();
      return (
        orders: list,
        totalPages: 1,
        totalOrders: list.length,
        activeCount: null,
        pastCount: null,
      );
    }
    final map = (data as Map).cast<String, dynamic>();
    final list = ((map['data'] as List?) ?? const [])
        .whereType<Map>()
        .map((e) => e.cast<String, dynamic>())
        .toList();
    final meta = (map['meta'] as Map?)?.cast<String, dynamic>() ?? const {};
    final totalOrders = (meta['total'] as num?)?.toInt() ??
        (meta['totalOrders'] as num?)?.toInt() ??
        (meta['count'] as num?)?.toInt() ??
        list.length;
    final activeCount = (meta['activeCount'] as num?)?.toInt();
    final pastCount = (meta['pastCount'] as num?)?.toInt();

    return (
      orders: list,
      totalPages: (meta['totalPages'] as num?)?.toInt() ?? 1,
      totalOrders: totalOrders,
      activeCount: activeCount,
      pastCount: pastCount,
    );
  }

  Future<void> cancelOrder(String orderId, {String? reason}) async {
    await _client.patch<dynamic>(
      '${ApiPaths.orderById(orderId)}/cancel',
      body: {'reason': ?reason},
    );
  }

  /// Cross-device cart continuity only — checkout reads the cart you send it,
  /// not this. Best-effort by design.
  Future<void> syncCart({
    required List<CartItemModel> items,
    String? restaurantId,
    String? restaurantName,
  }) async {
    await _client.put<dynamic>(
      ApiPaths.cart,
      body: {
        'items': items
            .map(
              (i) => {
                'itemId': i.food.id,
                'name': i.food.name,
                'price': i.food.price,
                'quantity': i.quantity,
                'restaurantId': i.food.restaurantId,
              },
            )
            .toList(),
        'restaurantId': ?restaurantId,
        'restaurantName': ?restaurantName,
      },
    );
  }
}
