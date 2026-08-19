import 'package:superapp_user/shared/location/application/current_location_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:superapp_user/modules/taxi/application/taxi_core_providers.dart';
import 'package:superapp_user/core/maps/marker_icon_loader.dart';
import 'package:superapp_user/core/maps/vehicle_marker_icons.dart';
import 'package:superapp_user/modules/taxi/ride/application/ride_providers.dart';
import 'package:superapp_user/modules/taxi/home/data/home_repository.dart';
import 'package:superapp_user/modules/taxi/home/data/models/app_module_model.dart';
import 'package:superapp_user/modules/taxi/home/data/models/set_price_model.dart';
import 'package:superapp_user/modules/taxi/home/data/models/vehicle_type_model.dart';

final homeRepositoryProvider = Provider<HomeRepository>((ref) {
  return HomeRepository(ref.watch(taxiApiClientProvider));
});

final appModulesProvider = FutureProvider<List<AppModuleModel>>((ref) {
  return ref.watch(homeRepositoryProvider).getAppModules();
});

/// The whole catalog, fetched once and shared by every booking flow.
final allVehicleTypesProvider = FutureProvider<List<VehicleTypeModel>>((ref) {
  return ref.watch(homeRepositoryProvider).getVehicleTypes();
});

/// Ride booking — taxi tiers only.
final vehicleTypesProvider = FutureProvider<List<VehicleTypeModel>>((ref) async {
  final all = await ref.watch(allVehicleTypesProvider.future);
  return all.where((v) => v.transportType.toLowerCase() == 'taxi').toList();
});

/// Promo banners uploaded by the admin. Empty on failure so the home screen
/// simply falls back to its bundled artwork rather than showing an error.
final bannersProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    return await ref.watch(homeRepositoryProvider).getBanners();
  } catch (_) {
    return const [];
  }
});

final setPricesProvider = FutureProvider<List<SetPriceModel>>((ref) {
  return ref.watch(homeRepositoryProvider).getSetPrices();
});

final bootstrapProvider = FutureProvider<Map<String, dynamic>>((ref) {
  return ref.watch(homeRepositoryProvider).getBootstrap();
});

/// The rider's position, derived from the one app-wide location fix.
///
/// Previously acquired its own GPS lock, which meant switching Food -> Rides
/// re-located the device every time. Falls back to the last known position so
/// the map still centres somewhere sensible if the shared fix failed.
final currentPositionProvider = FutureProvider<Position?>((ref) async {
  final location = await ref.watch(currentLocationProvider.future);
  final lat = location.latitude;
  final lng = location.longitude;
  if (lat != null && lng != null) {
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
  }
  return Geolocator.getLastKnownPosition();
});

/// One online driver near the rider, reduced to what the map needs.
class NearbyDriver {
  final String id;
  final double lat;
  final double lng;

  /// 'bike' | 'auto' | 'car' — the fallback key when this driver's exact
  /// vehicle type has no art of its own.
  final String iconFamily;

  /// Catalog id of the driver's vehicle type, used to look up that type's
  /// specific marker before falling back to [iconFamily].
  final String vehicleTypeId;

  const NearbyDriver({
    required this.id,
    required this.lat,
    required this.lng,
    required this.iconFamily,
    this.vehicleTypeId = '',
  });

  static NearbyDriver? fromJson(Map<String, dynamic> json) {
    final coordinates = (json['location'] as Map?)?['coordinates'] as List?;
    if (coordinates == null || coordinates.length < 2) return null;

    final lng = double.tryParse(coordinates[0].toString());
    final lat = double.tryParse(coordinates[1].toString());
    if (lat == null || lng == null) return null;

    return NearbyDriver(
      id: (json['id'] ?? '').toString(),
      lat: lat,
      lng: lng,
      iconFamily: VehicleMarkerIcons.familyFor(
        iconType: json['vehicleIconType']?.toString(),
        vehicleType: json['vehicleType']?.toString(),
      ),
      vehicleTypeId: (json['vehicleTypeId'] ?? '').toString(),
    );
  }
}

const _nearbyDriversRefreshInterval = Duration(seconds: 20);

/// Polls for online drivers around the rider so the home map can show live
/// vehicles. Interval stays well inside the endpoint's 60-req/min IP limit,
/// and `autoDispose` stops the polling as soon as the map is torn down.
final nearbyDriversProvider = StreamProvider.autoDispose<List<NearbyDriver>>((ref) async* {
  final position = await ref.watch(currentPositionProvider.future);
  if (position == null) {
    yield const [];
    return;
  }

  final repository = ref.watch(rideRepositoryProvider);

  Future<List<NearbyDriver>> fetch() async {
    try {
      final raw = await repository.getAvailableDrivers(
        lat: position.latitude,
        lng: position.longitude,
      );
      return raw.map(NearbyDriver.fromJson).whereType<NearbyDriver>().toList();
    } catch (_) {
      // A failed poll should leave the last known markers on screen rather
      // than blanking the map.
      return const [];
    }
  }

  yield await fetch();

  await for (final _ in Stream<void>.periodic(_nearbyDriversRefreshInterval)) {
    yield await fetch();
  }
});

/// Marker bitmaps served by the backend, decoded once and reused for every
/// driver.
///
/// Keyed twice for each vehicle type: by its catalog id (exact art for the
/// vehicle actually assigned) and by its `icon_types` family (`bike`/`auto`/
/// `car`), which is all the nearby-driver feed carries for some drivers.
/// Admins can change the art without shipping an app build.
///
/// The bundled assets remain only as a last resort — one live vehicle type has
/// no `map_icon` at all, and a blank map is worse than a generic pin.
final vehicleMarkerIconsProvider = FutureProvider<Map<String, BitmapDescriptor>>((ref) async {
  final icons = <String, BitmapDescriptor>{};

  try {
    final rows = await ref.watch(homeRepositoryProvider).getVehicleMapIcons();
    for (final row in rows) {
      final descriptor = await MarkerIconLoader.fromSource(row['map_icon']?.toString());
      if (descriptor == null) continue;

      final id = (row['id'] ?? '').toString();
      if (id.isNotEmpty) icons[id] = descriptor;

      // First type of a family wins; they are all the same silhouette.
      final family = VehicleMarkerIcons.familyFor(
        iconType: row['icon_types']?.toString(),
      );
      icons.putIfAbsent(family, () => descriptor);
    }
  } catch (_) {
    // Offline or endpoint failure — fall through to the bundled art below.
  }

  // Backfill any family the backend did not supply.
  final fallback = await VehicleMarkerIcons.loadAll();
  for (final entry in fallback.entries) {
    icons.putIfAbsent(entry.key, () => entry.value);
  }

  return icons;
});

final currentAddressProvider = FutureProvider<String>((ref) async {
  final pos = await ref.watch(currentPositionProvider.future);
  if (pos == null) return 'Fetching location...';
  final service = ref.watch(taxiLocationServiceProvider);
  final addr = await service.getAddressFromCoordinates(pos.latitude, pos.longitude);
  return addr.isNotEmpty ? addr : 'Current Location';
});

