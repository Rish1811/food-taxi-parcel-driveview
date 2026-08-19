import 'package:superapp_user/shared/location/application/current_location_provider.dart';
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import 'package:superapp_user/modules/food/data/models/zone_model.dart';
import 'package:superapp_user/modules/food/application/providers/catalog_providers.dart';

/// Detects the serviceable zone for the user's location.
///
/// Zone gates the home screen: `zoneId` is passed to every listing and search
/// call so results are scoped to the area we actually deliver to. When location
/// is unavailable or the point is out of coverage, we fall back to unscoped
/// (national) listings rather than showing an empty app.
final zoneViewModelProvider =
    AsyncNotifierProvider<ZoneViewModel, ZoneModel>(ZoneViewModel.new);

class ZoneViewModel extends AsyncNotifier<ZoneModel> {
  @override
  FutureOr<ZoneModel> build() => _detect();

  Future<ZoneModel> _detect() async {
    final position = await _currentPosition();
    if (position == null) return ZoneModel.unknown;

    final repo = ref.read(catalogRemoteDataSourceProvider);
    try {
      return await repo.detectZone(lat: position.latitude, lng: position.longitude);
    } catch (_) {
      // Zone detection must never hard-fail the app — unscoped listings are a
      // usable fallback.
      return ZoneModel.unknown;
    }
  }

  /// Coordinates for zone detection, taken from the one app-wide location
  /// fix rather than a third independent GPS acquisition.
  ///
  /// Returns null on any failure — zone detection must never hard-fail the
  /// app, and unscoped listings are a usable fallback.
  Future<Position?> _currentPosition() async {
    try {
      final location = await ref.read(currentLocationProvider.future);
      final lat = location.latitude;
      final lng = location.longitude;
      if (lat == null || lng == null) return null;
      return Position(
        latitude: lat,
        longitude: lng,
        timestamp: DateTime.now(),
        accuracy: 0,
        altitude: 0,
        altitudeAccuracy: 0,
        heading: 0,
        headingAccuracy: 0,
        speed: 0,
        speedAccuracy: 0,
      );
    } catch (_) {
      return null;
    }
  }


  Future<void> refresh() async {
    state = const AsyncValue.loading();
    state = AsyncValue.data(await _detect());
  }
}

/// The zone id to scope catalog calls with, or null when undetected.
final currentZoneIdProvider = Provider<String?>((ref) {
  return ref.watch(zoneViewModelProvider).value?.zoneId;
});
