import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:superapp_user/core/location/location_service.dart';
import 'package:superapp_user/modules/food/application/providers/location_providers.dart';

/// The device's current location and resolved address — fetched **once** for
/// the whole app.
///
/// Before this, four call sites each ran their own GPS fix and reverse geocode
/// (`near_you_viewmodel`, `zone_viewmodel`, taxi's `home_providers`, and the
/// address screen). Switching Food -> Rides therefore re-acquired GPS and
/// re-geocoded every time, which is slow, drains battery, and bills a Google
/// Geocoding call per switch.
///
/// Deliberately **not** `autoDispose`: the whole point is that it survives
/// module switches. It is refreshed only on an explicit user action — pull to
/// refresh, or tapping the address in the header.
final currentLocationProvider =
    AsyncNotifierProvider<CurrentLocationController, UserLocationResult>(
  CurrentLocationController.new,
);

class CurrentLocationController extends AsyncNotifier<UserLocationResult> {
  @override
  Future<UserLocationResult> build() {
    return ref.read(locationServiceProvider).getCurrentLocationAndAddress();
  }

  /// Re-acquires the fix. Keeps the previous value on screen while in flight so
  /// the header does not flash empty.
  Future<void> refresh() async {
    // Keep the current value visible while refreshing — flipping to a bare
    // loading state would blank the header mid-scroll.
    final previous = state.value;
    try {
      final result =
          await ref.read(locationServiceProvider).getCurrentLocationAndAddress();
      state = AsyncValue.data(result);
    } catch (error, stack) {
      // A failed refresh must not blank out a location we already had.
      state = previous != null
          ? AsyncValue.data(previous)
          : AsyncValue.error(error, stack);
    }
  }
}

/// Short label for the header — "Office", "Home", or the locality.
final currentLocationLabelProvider = Provider<String>((ref) {
  final result = ref.watch(currentLocationProvider).value;
  if (result == null) return 'Locating…';
  final area = result.area.trim();
  if (area.isNotEmpty) return area;
  final city = result.city.trim();
  return city.isNotEmpty ? city : 'Current location';
});

/// Full line under the label.
final currentAddressLineProvider = Provider<String>((ref) {
  final async = ref.watch(currentLocationProvider);
  final result = async.value;
  if (result == null) {
    return async.isLoading ? 'Finding your location…' : '';
  }
  if (result.isServiceDisabled) return 'Turn on location services';
  if (result.isPermissionDenied || result.isPermanentlyDenied) {
    return 'Location permission needed';
  }
  final full = result.fullAddress.trim();
  return full.isNotEmpty ? full : 'Tap to set your address';
});
