import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../data/work_mode.dart';
import '../data/work_mode_repository.dart';

/// Owns the Food / Taxi / Both switch.
///
/// The server is the source of truth — it holds the mode across app restarts
/// and enforces it in dispatch — so this loads from the driver document rather
/// than persisting locally, and reverts on a rejected change instead of leaving
/// the UI claiming a mode the backend never accepted.
class WorkModeController extends AsyncNotifier<WorkModeStatus> {
  WorkModeRepository get _repository => ref.read(workModeRepositoryProvider);

  @override
  Future<WorkModeStatus> build() async {
    final result = await _repository.fetch();
    return result.when(
      success: (status) => status,
      // A driver who isn't on the unified roster yet still needs a working
      // food app; fall back to delivery-only rather than blocking the screen.
      failure: (_) => WorkModeStatus.fallback,
    );
  }

  WorkMode get mode => state.value?.mode ?? WorkMode.delivery;

  /// True while the current mode accepts ride requests. The incoming-ride
  /// controller gates on this so a Food-only driver is never shown a ride,
  /// even if a stale dispatch event reaches the socket.
  bool get acceptsRides => mode.acceptsRides;

  bool get acceptsFood => mode.acceptsFood;

  Future<Result<void, AppError>> select(WorkMode next) async {
    final previous = state.value;
    if (previous != null) {
      if (previous.mode == next) return const Result.success(null);
      // Optimistic: the switch should feel instant. Reverted below if refused.
      state = AsyncData(
        WorkModeStatus(mode: next, capabilities: previous.capabilities),
      );
    }

    final result = await _repository.setMode(next);
    return result.when(
      success: (status) {
        state = AsyncData(status);
        return const Result.success(null);
      },
      failure: (error) {
        if (previous != null) state = AsyncData(previous);
        return Result.failure(error);
      },
    );
  }

  Future<void> refresh() async {
    final result = await _repository.fetch();
    result.when(
      success: (status) => state = AsyncData(status),
      failure: (_) {},
    );
  }
}

final workModeControllerProvider =
    AsyncNotifierProvider<WorkModeController, WorkModeStatus>(
  WorkModeController.new,
);

/// Convenience for widgets and controllers that only care about the mode.
/// Defaults to delivery while the status is still loading so the food flow —
/// which every driver has — is never gated behind a network round trip.
final currentWorkModeProvider = Provider<WorkMode>((ref) {
  return ref.watch(workModeControllerProvider).value?.mode ?? WorkMode.delivery;
});
