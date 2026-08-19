import 'package:superapp_user/modules/taxi/ride/data/models/ride_model.dart';

class RideTrackingState {
  final RideModel? ride;
  final bool isLoading;
  final String? error;
  final bool isCancelling;

  const RideTrackingState({
    this.ride,
    this.isLoading = true,
    this.error,
    this.isCancelling = false,
  });

  RideTrackingState copyWith({
    RideModel? ride,
    bool? isLoading,
    String? error,
    bool? isCancelling,
    bool clearError = false,
  }) {
    return RideTrackingState(
      ride: ride ?? this.ride,
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      isCancelling: isCancelling ?? this.isCancelling,
    );
  }
}
