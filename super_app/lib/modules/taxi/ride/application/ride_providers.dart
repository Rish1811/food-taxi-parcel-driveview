import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superapp_user/modules/taxi/application/taxi_core_providers.dart';
import 'package:superapp_user/modules/taxi/ride/data/models/ride_model.dart';
import 'package:superapp_user/modules/taxi/ride/data/ride_repository.dart';

final rideRepositoryProvider = Provider<RideRepository>((ref) {
  return RideRepository(ref.watch(taxiApiClientProvider));
});

/// The rider's in-progress ride, so any screen can surface an "ongoing ride"
/// entry point. Yields null once the trip ends.
///
/// Polled rather than fetched once: a ride can finish or be cancelled while the
/// rider sits on another screen, and a one-shot fetch would leave a stale entry
/// point on screen indefinitely. `autoDispose` stops the polling as soon as
/// nothing is listening.
final myActiveRideProvider = StreamProvider.autoDispose<RideModel?>((ref) async* {
  final repository = ref.watch(rideRepositoryProvider);

  Future<RideModel?> fetch() async {
    try {
      return await repository.getMyActiveRide();
    } catch (_) {
      // A failed poll should never break the screen hosting this.
      return null;
    }
  }

  yield await fetch();

  await for (final _ in Stream<void>.periodic(const Duration(seconds: 15))) {
    yield await fetch();
  }
});
