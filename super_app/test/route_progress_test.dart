import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'package:superapp_user/modules/food/presentation/orders/widgets/live_tracking_map.dart';

void main() {
  group('nearestRouteIndexAhead', () {
    // A straight run north along one longitude.
    final straight = [
      for (var i = 0; i < 10; i++) LatLng(20.0 + i * 0.001, 78.0),
    ];

    test('picks the vertex the rider is sitting on', () {
      expect(nearestRouteIndexAhead(straight, const LatLng(20.003, 78.0), 0), 3);
    });

    test('advances as the rider moves along the route', () {
      var idx = 0;
      for (var i = 0; i < 10; i++) {
        idx = nearestRouteIndexAhead(straight, LatLng(20.0 + i * 0.001, 78.0), idx);
        expect(idx, i);
      }
    });

    test('never moves backwards, even if the rider drifts back', () {
      final idx = nearestRouteIndexAhead(straight, const LatLng(20.001, 78.0), 6);
      expect(idx, greaterThanOrEqualTo(6),
          reason: 'progress must be monotonic so the trimmed line cannot regrow');
    });

    test('a route that doubles back does not snap the line backwards', () {
      // Out and back: vertices 0..4 north, 5..9 retracing south.
      final loop = [
        for (var i = 0; i < 5; i++) LatLng(20.0 + i * 0.001, 78.0),
        for (var i = 4; i >= 0; i--) LatLng(20.0 + i * 0.001, 78.0005),
      ];
      // Rider is on the return leg, physically next to vertex 1 as well as 8.
      final idx = nearestRouteIndexAhead(loop, const LatLng(20.001, 78.0005), 5);
      expect(idx, 8);
    });

    test('empty route and out-of-range start are safe', () {
      expect(nearestRouteIndexAhead(const [], const LatLng(20, 78), 3), 0);
      expect(nearestRouteIndexAhead(straight, const LatLng(20, 78), 99), 9);
    });
  });
}
