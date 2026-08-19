import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/utils/polyline_decoder.dart';

/// A drawn route between two points.
class RideRoute {
  const RideRoute({required this.points, this.durationMins, this.distanceKm});

  final List<LatLng> points;
  final double? durationMins;
  final double? distanceKm;

  bool get isEmpty => points.isEmpty;
}

/// Road route for the driver's current leg.
///
/// Calls Google Directions directly rather than the backend: the food side has
/// `GET /food/delivery/orders/:id/route`, but k9 exposes no equivalent for
/// rides — the taxi module only pushes driver positions over
/// `ride:driver-route:updated`, which is for the *passenger's* map, not the
/// driver's.
class RideRouteService {
  RideRouteService(this._dio);

  final Dio _dio;

  Future<RideRoute?> fetch({required LatLng from, required LatLng to}) async {
    try {
      final res = await _dio.get(
        'https://maps.googleapis.com/maps/api/directions/json',
        queryParameters: {
          'origin': '${from.latitude},${from.longitude}',
          'destination': '${to.latitude},${to.longitude}',
          'mode': 'driving',
          'key': AppConstants.mapKey,
        },
        options: Options(
          // The shared Dio carries the app's bearer and baseUrl; neither belongs
          // on a Google request, and sending our token to a third party would
          // leak it.
          headers: const {},
          extra: const {'skipAuth': true},
        ),
      );

      final data = res.data;
      if (data is! Map || data['status'] != 'OK') return null;

      final routes = data['routes'] as List?;
      if (routes == null || routes.isEmpty) return null;

      final route = routes.first as Map;
      final encoded = (route['overview_polyline']?['points'] ?? '').toString();
      if (encoded.isEmpty) return null;

      final legs = route['legs'] as List?;
      final leg = (legs != null && legs.isNotEmpty) ? legs.first as Map : null;

      return RideRoute(
        points: decodePolyline(encoded),
        durationMins: leg == null
            ? null
            : ((leg['duration']?['value'] as num?)?.toDouble() ?? 0) / 60.0,
        distanceKm: leg == null
            ? null
            : ((leg['distance']?['value'] as num?)?.toDouble() ?? 0) / 1000.0,
      );
    } catch (_) {
      // A missing route is a cosmetic loss — the driver still has the marker,
      // the address and the Navigate button. Never let it break the trip screen.
      return null;
    }
  }
}

final rideRouteServiceProvider = Provider<RideRouteService>((ref) {
  // A bare Dio on purpose: no baseUrl, no auth interceptor, no retry policy.
  return RideRouteService(Dio());
});
