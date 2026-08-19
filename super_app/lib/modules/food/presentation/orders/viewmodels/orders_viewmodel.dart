import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/core/error/failures.dart';
import 'package:superapp_user/modules/food/data/models/order_model.dart';
import 'package:superapp_user/modules/food/application/providers/order_providers.dart';
import 'package:superapp_user/modules/food/application/providers/socket_providers.dart';
import 'package:superapp_user/shared/auth/presentation/viewmodels/auth_viewmodel.dart';

void _orderLog(String message) {
  if (kDebugMode) debugPrint('[ORDER] $message');
}

/// Paginated order history and backend count tracking.
class OrdersState {
  final List<OrderModel> orders;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int page;
  final int totalPages;
  final int totalOrders;
  final int? serverActiveCount;
  final int? serverPastCount;

  const OrdersState({
    this.orders = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.page = 1,
    this.totalPages = 1,
    this.totalOrders = 0,
    this.serverActiveCount,
    this.serverPastCount,
  });

  bool get hasMore => page < totalPages;
  bool get isEmpty => orders.isEmpty && !isLoading && error == null;

  List<OrderModel> get active => orders.where((o) => o.isActive).toList();
  List<OrderModel> get past => orders.where((o) => !o.isActive).toList();

  int get activeCount => serverActiveCount ?? active.length;
  int get pastCount => serverPastCount ?? past.length;

  // ── Summary counts used by the Profile "My Orders" card ──────────────────
  /// Orders that are still in progress (active / upcoming).
  int get upcomingCount => activeCount;

  /// Orders successfully delivered.
  int get completedCount => orders.where((o) => o.isDelivered).length;

  /// Cancelled orders (by user, restaurant, or admin).
  int get cancelledCount => orders.where((o) => o.isCancelled).length;

  /// Orders that have a completed or pending refund.
  int get refundedCount => orders
      .where((o) => o.refundStatus != 'none' && o.refundStatus.isNotEmpty)
      .length;

  OrdersState copyWith({
    List<OrderModel>? orders,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? page,
    int? totalPages,
    int? totalOrders,
    int? serverActiveCount,
    int? serverPastCount,
    bool clearError = false,
  }) {
    return OrdersState(
      orders: orders ?? this.orders,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      page: page ?? this.page,
      totalPages: totalPages ?? this.totalPages,
      totalOrders: totalOrders ?? this.totalOrders,
      serverActiveCount: serverActiveCount ?? this.serverActiveCount,
      serverPastCount: serverPastCount ?? this.serverPastCount,
    );
  }
}

final ordersViewModelProvider = NotifierProvider<OrdersViewModel, OrdersState>(
  OrdersViewModel.new,
);

class OrdersViewModel extends Notifier<OrdersState> {
  StreamSubscription? _socketSub;

  @override
  OrdersState build() {
    ref.onDispose(() {
      _socketSub?.cancel();
    });

    // Orders are per-account: reload on login, clear on logout.
    ref.listen(authViewModelProvider, (previous, next) {
      if (previous?.value?.id == next.value?.id) return;
      if (next.value == null) {
        state = const OrdersState();
      } else {
        unawaited(refresh());
      }
    });

    // Real-time socket events for status changes (placed, accepted, delivered, cancelled, etc.)
    _socketSub ??= ref.read(socketServiceProvider).orderEvents.listen((message) {
      _orderLog('Socket order event received: ${message.event} -> refreshing order list');
      unawaited(refresh(isRefresh: true));
    });

    if (ref.read(authViewModelProvider).value != null) {
      unawaited(Future.microtask(refresh));
    } else {
      _orderLog('build() — no user yet, waiting for auth listener');
    }
    return const OrdersState(isLoading: true);
  }

  Future<void> refresh({bool isRefresh = false}) async {
    if (!isRefresh) {
      state = state.copyWith(isLoading: true, clearError: true);
    } else {
      state = state.copyWith(clearError: true);
    }
    try {
      final result = await ref
          .read(orderRemoteDataSourceProvider)
          .getOrderModels(page: 1, limit: 50);
      state = OrdersState(
        orders: result.orders,
        totalPages: result.totalPages,
        totalOrders: result.totalOrders,
        serverActiveCount: result.activeCount,
        serverPastCount: result.pastCount,
        page: 1,
        isLoading: false,
      );
      _orderLog('Active Orders Count: ${state.activeCount}');
      _orderLog('Past Orders Count: ${state.pastCount}');
    } on Failure catch (f) {
      _orderLog('Refresh failed: ${f.message}');
      state = state.copyWith(isLoading: false, error: f.message);
    } catch (e) {
      _orderLog('Refresh failed (unexpected): $e');
      state = state.copyWith(
        isLoading: false,
        error: 'Could not load your orders.',
      );
    }
  }

  /// Infinite scroll. Ignores re-entrant calls and no-ops at the last page.
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    final next = state.page + 1;
    try {
      final result = await ref
          .read(orderRemoteDataSourceProvider)
          .getOrderModels(page: next);
      state = state.copyWith(
        orders: [...state.orders, ...result.orders],
        page: next,
        totalPages: result.totalPages,
        isLoadingMore: false,
      );
    } on Failure catch (f) {
      state = state.copyWith(isLoadingMore: false, error: f.message);
    } catch (_) {
      state = state.copyWith(
        isLoadingMore: false,
        error: 'Could not load more orders.',
      );
    }
  }

  /// Cancels, then refreshes so the resulting `cancelledBy` / reason come from
  /// the server rather than being guessed locally.
  Future<String?> cancelOrder(String orderId, {String? reason}) async {
    try {
      await ref
          .read(orderRemoteDataSourceProvider)
          .cancelOrder(orderId, reason: reason);
      await refresh();
      return null;
    } on Failure catch (f) {
      return f.message;
    } catch (_) {
      return 'Could not cancel this order.';
    }
  }

  /// Submits, then refreshes so the card reflects the server's stored ratings
  /// rather than an optimistic guess (the ratings endpoint doesn't echo the
  /// updated order back).
  Future<String?> submitRating(
    String orderId, {
    required int restaurantRating,
    int? deliveryPartnerRating,
    String? restaurantComment,
    String? deliveryPartnerComment,
    List<Map<String, dynamic>>? itemRatings,
  }) async {
    try {
      await ref
          .read(orderRemoteDataSourceProvider)
          .rateOrder(
            orderId: orderId,
            restaurantRating: restaurantRating,
            deliveryPartnerRating: deliveryPartnerRating,
            restaurantComment: restaurantComment,
            deliveryPartnerComment: deliveryPartnerComment,
            itemRatings: itemRatings,
          );
      await refresh();
      return null;
    } on Failure catch (f) {
      return f.message;
    } catch (_) {
      return 'Could not submit your rating.';
    }
  }
}

/// A single order, polled while a tracking screen is open.
final orderDetailProvider = FutureProvider.autoDispose
    .family<OrderModel, String>((ref, orderId) async {
      return ref.watch(orderRemoteDataSourceProvider).getOrderModel(orderId);
    });
