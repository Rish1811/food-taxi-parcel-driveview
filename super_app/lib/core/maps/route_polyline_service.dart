import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:superapp_user/core/maps/polyline_decoder.dart';

class RoutePolylineService {
  RoutePolylineService._();

  static final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 5),
      receiveTimeout: const Duration(seconds: 5),
    ),
  );

  /// Cache for decoded route polylines to prevent re-fetching the same route
  static final Map<String, List<LatLng>> _cache = {};

  /// Fetches an accurate road-following polyline for the given pickup, dropoff,
  /// and optional intermediate stops.
  static Future<List<LatLng>> getRoutePoints({
    required LatLng pickup,
    required LatLng drop,
    List<LatLng> stops = const [],
  }) async {
    final cacheKey =
        '${pickup.latitude},${pickup.longitude}_${stops.map((s) => '${s.latitude},${s.longitude}').join('_')}_${drop.latitude},${drop.longitude}';

    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }

    // Build OSRM coordinates path: "lng1,lat1;lng2,lat2;..."
    final waypoints = [
      '${pickup.longitude},${pickup.latitude}',
      ...stops.map((s) => '${s.longitude},${s.latitude}'),
      '${drop.longitude},${drop.latitude}',
    ].join(';');

    final url =
        'https://router.project-osrm.org/route/v1/driving/$waypoints?overview=full&geometries=polyline';

    try {
      final response = await _dio.get(url);
      if (response.statusCode == 200 && response.data != null) {
        final routes = response.data['routes'] as List?;
        if (routes != null && routes.isNotEmpty) {
          final encodedGeometry = routes.first['geometry']?.toString();
          if (encodedGeometry != null && encodedGeometry.isNotEmpty) {
            final points = PolylineDecoder.decode(encodedGeometry);
            if (points.isNotEmpty) {
              _cache[cacheKey] = points;
              return points;
            }
          }
        }
      }
    } catch (e) {
      developer.log('RoutePolylineService OSRM error: $e');
    }

    // Fallback: Generate a smooth, road-curved path if OSRM is unreachable
    final fallbackPoints = _generateFallbackRoadPath(pickup, drop, stops);
    _cache[cacheKey] = fallbackPoints;
    return fallbackPoints;
  }

  /// Synchronous version that returns cached points if available or generates
  /// a road-style curved path instantly.
  static List<LatLng> getRoutePointsSync(LatLng pickup, LatLng drop, [List<LatLng> stops = const []]) {
    final cacheKey =
        '${pickup.latitude},${pickup.longitude}_${stops.map((s) => '${s.latitude},${s.longitude}').join('_')}_${drop.latitude},${drop.longitude}';
    if (_cache.containsKey(cacheKey)) {
      return _cache[cacheKey]!;
    }
    return _generateFallbackRoadPath(pickup, drop, stops);
  }

  /// Generates a multi-point road-style curved path following grid turns
  /// so it never displays a harsh straight line.
  static List<LatLng> _generateFallbackRoadPath(
    LatLng pickup,
    LatLng drop,
    List<LatLng> stops,
  ) {
    final points = <LatLng>[pickup];
    final allWaypoints = [...stops, drop];

    LatLng current = pickup;
    for (final next in allWaypoints) {
      final midLat = current.latitude;
      final midLng = next.longitude;
      
      // Interpolate horizontal segment
      for (int i = 1; i <= 5; i++) {
        final ratio = i / 6.0;
        points.add(LatLng(
          current.latitude,
          current.longitude + (midLng - current.longitude) * ratio,
        ));
      }

      // Interpolate vertical segment
      for (int i = 1; i <= 6; i++) {
        final ratio = i / 6.0;
        points.add(LatLng(
          midLat + (next.latitude - midLat) * ratio,
          next.longitude,
        ));
      }

      current = next;
    }

    return points;
  }
}

