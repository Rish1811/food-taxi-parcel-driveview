import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/core/error/failures.dart';
import 'package:superapp_user/modules/food/data/models/restaurant_model.dart';
import 'package:superapp_user/modules/food/application/providers/catalog_providers.dart';
import 'package:superapp_user/modules/food/presentation/home/viewmodels/zone_viewmodel.dart';

/// Paginated restaurant feed for infinite-scroll listings.
///
/// `GET /food/restaurant/restaurants` returns `{ restaurants, total, page,
/// limit }` — a flat envelope, unlike orders (`meta`) and notifications
/// (`pagination`). `hasMore` is derived from `total`.
class RestaurantListState {
  final List<RestaurantModel> restaurants;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int page;
  final bool hasMore;

  const RestaurantListState({
    this.restaurants = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.page = 1,
    this.hasMore = true,
  });

  bool get isEmpty => restaurants.isEmpty && !isLoading && error == null;

  /// True when the first page failed — the screen shows a retry instead of an
  /// empty list.
  bool get hasFailedInitialLoad => error != null && restaurants.isEmpty;

  RestaurantListState copyWith({
    List<RestaurantModel>? restaurants,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    int? page,
    bool? hasMore,
    bool clearError = false,
  }) {
    return RestaurantListState(
      restaurants: restaurants ?? this.restaurants,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
    );
  }
}

final restaurantListProvider =
    NotifierProvider<RestaurantListViewModel, RestaurantListState>(
  RestaurantListViewModel.new,
);

class RestaurantListViewModel extends Notifier<RestaurantListState> {
  static const _pageSize = 20;

  @override
  RestaurantListState build() {
    // Re-scope the feed when the detected zone changes.
    ref.listen(currentZoneIdProvider, (previous, next) {
      if (previous != next) unawaited(refresh());
    });
    unawaited(refresh());
    return const RestaurantListState(isLoading: true);
  }

  /// Pull-to-refresh and first load.
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final items = await ref.read(catalogRemoteDataSourceProvider).getRestaurants(
            zoneId: ref.read(currentZoneIdProvider),
            page: 1,
            limit: _pageSize,
          );
      state = RestaurantListState(
        restaurants: items,
        page: 1,
        hasMore: items.length >= _pageSize,
      );
    } on Failure catch (f) {
      state = state.copyWith(isLoading: false, error: f.message);
    } catch (_) {
      state = state.copyWith(isLoading: false, error: 'Could not load restaurants.');
    }
  }

  /// Infinite scroll. Re-entrant calls and end-of-list are no-ops.
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || state.isLoading) return;
    state = state.copyWith(isLoadingMore: true, clearError: true);
    final next = state.page + 1;
    try {
      final items = await ref.read(catalogRemoteDataSourceProvider).getRestaurants(
            zoneId: ref.read(currentZoneIdProvider),
            page: next,
            limit: _pageSize,
          );
      state = state.copyWith(
        restaurants: [...state.restaurants, ...items],
        page: next,
        hasMore: items.length >= _pageSize,
        isLoadingMore: false,
      );
    } on Failure catch (f) {
      state = state.copyWith(isLoadingMore: false, error: f.message);
    } catch (_) {
      state = state.copyWith(isLoadingMore: false, error: 'Could not load more.');
    }
  }

  /// Retry after a failed page — same as loading the next page, but clears the
  /// error first so the retry affordance disappears immediately.
  Future<void> retry() {
    state = state.copyWith(clearError: true);
    return state.restaurants.isEmpty ? refresh() : loadMore();
  }
}
