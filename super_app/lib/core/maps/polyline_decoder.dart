import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Decodes Google's encoded-polyline format into map points.
///
/// The backend resolves the route once per leg and ships the encoded string on
/// the ride payload, so the apps never call the Directions API themselves.
/// Results are memoised against the encoded string: redrawing on every driver
/// location update would otherwise re-decode hundreds of points per second.
class PolylineDecoder {
  PolylineDecoder._();

  static String? _lastEncoded;
  static List<LatLng> _lastPoints = const [];

  static List<LatLng> decode(String? encoded) {
    if (encoded == null || encoded.isEmpty) return const [];
    if (encoded == _lastEncoded) return _lastPoints;

    final points = <LatLng>[];
    int index = 0;
    int lat = 0;
    int lng = 0;

    while (index < encoded.length) {
      int result = 0;
      int shift = 0;
      int byte;

      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);
      lat += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      result = 0;
      shift = 0;
      do {
        byte = encoded.codeUnitAt(index++) - 63;
        result |= (byte & 0x1f) << shift;
        shift += 5;
      } while (byte >= 0x20 && index < encoded.length);
      lng += (result & 1) != 0 ? ~(result >> 1) : result >> 1;

      points.add(LatLng(lat / 1e5, lng / 1e5));
    }

    _lastEncoded = encoded;
    _lastPoints = List.unmodifiable(points);
    return _lastPoints;
  }
}
