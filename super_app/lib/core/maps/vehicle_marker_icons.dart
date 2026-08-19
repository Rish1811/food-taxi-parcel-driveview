import 'dart:ui' as ui;
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Map markers for the vehicle families the backend reports on a driver
/// (`vehicleIconType`, falling back to `vehicleType`, `vehicleMake`, `vehicleModel`).
///
/// Decoding is done at a fixed pixel width so a marker looks the same on every
/// device instead of scaling with the asset's intrinsic size, and each family
/// is decoded once and cached for the process lifetime.
class VehicleMarkerIcons {
  VehicleMarkerIcons._();

  static const _assetsByFamily = <String, String>{
    'bike': 'assets/markers/markerbike.png',
    'auto': 'assets/markers/markerauto.webp',
    'car': 'assets/markers/markersedan.webp',
  };

  static const _defaultFamily = 'car';
  static const _markerWidthPx = 75;

  static final Map<String, BitmapDescriptor> _cache = {};

  /// Normalises the many spellings the catalog uses ('bike', '2wheeler',
  /// 'bddh', 'suv', 'Luxary', …) down to the three families we ship art for.
  static String familyFor({
    String? iconType,
    String? vehicleType,
    String? vehicleMake,
    String? vehicleModel,
    String? serviceType,
  }) {
    final combined = [
      iconType,
      vehicleType,
      vehicleMake,
      vehicleModel,
      serviceType,
    ].where((s) => s != null && s.trim().isNotEmpty).join(' ').toLowerCase();

    if (combined.contains('bike') ||
        combined.contains('2wheeler') ||
        combined.contains('moto') ||
        combined.contains('scooter') ||
        combined.contains('bddh') ||
        combined.contains('twowheeler')) {
      return 'bike';
    }
    if (combined.contains('auto') ||
        combined.contains('rickshaw') ||
        combined.contains('three') ||
        combined.contains('tuk')) {
      return 'auto';
    }
    return _defaultFamily;
  }

  static Future<BitmapDescriptor> forFamily(String family) async {
    final cached = _cache[family];
    if (cached != null) return cached;

    final assetPath = _assetsByFamily[family] ?? _assetsByFamily[_defaultFamily]!;
    final data = await rootBundle.load(assetPath);
    final codec = await ui.instantiateImageCodec(
      data.buffer.asUint8List(),
      targetWidth: _markerWidthPx,
    );
    final frame = await codec.getNextFrame();
    final bytes = await frame.image.toByteData(format: ui.ImageByteFormat.png);

    if (bytes == null) {
      return BitmapDescriptor.defaultMarker;
    }

    final descriptor = BitmapDescriptor.bytes(bytes.buffer.asUint8List());
    _cache[family] = descriptor;
    return descriptor;
  }

  /// Preloads every family so markers appear on the first frame they are needed
  /// rather than popping in one by one.
  static Future<Map<String, BitmapDescriptor>> loadAll() async {
    for (final family in _assetsByFamily.keys) {
      await forFamily(family);
    }
    return Map.unmodifiable(_cache);
  }
}
