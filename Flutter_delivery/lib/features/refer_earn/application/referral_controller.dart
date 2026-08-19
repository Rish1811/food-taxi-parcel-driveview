import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:food_user_application/core/error/result.dart';
import 'package:food_user_application/features/refer_earn/data/models/referral_stats.dart';
import 'package:food_user_application/features/refer_earn/data/referral_repository.dart';
class ReferralController extends AsyncNotifier<ReferralStats?> {
  @override
  Future<ReferralStats?> build() async {
    return _fetchStats();
  }

  Future<ReferralStats?> _fetchStats() async {
    final repo = ref.read(referralRepositoryProvider);
    final result = await repo.getReferralStats();
    
    return result.when(
      success: (stats) => stats,
      failure: (err) => throw Exception(err.message),
    );
  }

  Future<void> refreshStats() async {
    state = const AsyncLoading();
    try {
      final stats = await _fetchStats();
      state = AsyncData(stats);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final referralControllerProvider = AsyncNotifierProvider<ReferralController, ReferralStats?>(
  () => ReferralController(),
);
