import 'dart:ui' show Offset;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:superapp_user/modules/taxi/home/application/home_providers.dart';

/// Live vehicles around the rider, each drawn with its own vehicle-type art.
///
/// Shared by the home map and the finding-driver map so both show the same
/// fleet — the rider should not watch vehicles vanish the moment they start
/// searching for one.
///
/// Renders nothing until both the drivers and the bitmaps have resolved, so a
/// slow icon decode never leaves default red pins on the map.
Set<Marker> buildNearbyDriverMarkers(WidgetRef ref) {
  final drivers =
      ref.watch(nearbyDriversProvider).value ?? const <NearbyDriver>[];
  final icons = ref.watch(vehicleMarkerIconsProvider).value;
  if (drivers.isEmpty || icons == null) return const {};

  return drivers
      .map((driver) {
        // Exact art for this driver's vehicle type when the backend has it,
        // otherwise the family silhouette.
        final icon = icons[driver.vehicleTypeId] ?? icons[driver.iconFamily];
        if (icon == null) return null;
        return Marker(
          markerId: MarkerId('nearby_driver_${driver.id}'),
          position: LatLng(driver.lat, driver.lng),
          icon: icon,
          anchor: const Offset(0.5, 0.5),
          flat: true,
          zIndexInt: 1,
        );
      })
      .whereType<Marker>()
      .toSet();
}
