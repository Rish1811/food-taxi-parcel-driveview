import 'package:superapp_user/modules/taxi/ride/data/models/ride_model.dart';

class RideHistoryState {
  final List<RideModel> rides;
  final int page;
  final bool hasMore;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final String category;

  const RideHistoryState({
    this.rides = const [],
    this.page = 1,
    this.hasMore = true,
    this.isLoading = true,
    this.isLoadingMore = false,
    this.error,
    this.category = 'all',
  });

  RideHistoryState copyWith({
    List<RideModel>? rides,
    int? page,
    bool? hasMore,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    String? category,
    bool clearError = false,
  }) {
    return RideHistoryState(
      rides: rides ?? this.rides,
      page: page ?? this.page,
      hasMore: hasMore ?? this.hasMore,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      error: clearError ? null : (error ?? this.error),
      category: category ?? this.category,
    );
  }
}
