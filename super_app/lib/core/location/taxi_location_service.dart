import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationPermissionResult {
  final bool granted;
  final bool serviceEnabled;
  final bool permanentlyDenied;

  LocationPermissionResult({
    required this.granted,
    required this.serviceEnabled,
    required this.permanentlyDenied,
  });
}

class TaxiLocationService {
  // ~50m Grid Memory Cache & Throttling/Skip State
  final Map<String, String> _gridCache = {};
  double? _lastGeocodedLat;
  double? _lastGeocodedLng;
  String? _lastGeocodedAddress;
  DateTime? _lastGeocodeTime;

  Future<LocationPermissionResult> ensurePermission() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationPermissionResult(
        granted: false,
        serviceEnabled: false,
        permanentlyDenied: false,
      );
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    if (permission == LocationPermission.deniedForever) {
      return LocationPermissionResult(
        granted: false,
        serviceEnabled: true,
        permanentlyDenied: true,
      );
    }

    final granted = permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;

    return LocationPermissionResult(
      granted: granted,
      serviceEnabled: true,
      permanentlyDenied: false,
    );
  }

  Future<Position> getCurrentPosition() {
    return Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    );
  }

  // 1) GPS stream pe geocode mat chalao - Returns raw positions only
  Stream<Position> watchPosition() {
    return Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 20,
      ),
    );
  }

  double distanceMeters(double lat1, double lng1, double lat2, double lng2) {
    return Geolocator.distanceBetween(lat1, lng1, lat2, lng2);
  }

  String _gridKey(double lat, double lng) {
    // 2000 units per degree yields ~55m grid resolution
    final latGrid = (lat * 2000).round();
    final lngGrid = (lng * 2000).round();
    return '${latGrid}_$lngGrid';
  }

  Future<String> getAddressFromCoordinates(double lat, double lng) async {
    // 5) ~50m grid memory cache
    final key = _gridKey(lat, lng);
    if (_gridCache.containsKey(key)) {
      return _gridCache[key]!;
    }

    // 3) <50m move skip
    if (_lastGeocodedLat != null &&
        _lastGeocodedLng != null &&
        _lastGeocodedAddress != null &&
        _lastGeocodedAddress!.isNotEmpty) {
      final distance = distanceMeters(lat, lng, _lastGeocodedLat!, _lastGeocodedLng!);
      if (distance < 50) {
        _gridCache[key] = _lastGeocodedAddress!;
        return _lastGeocodedAddress!;
      }
    }

    // 4) 3s throttle
    if (_lastGeocodeTime != null &&
        _lastGeocodedAddress != null &&
        _lastGeocodedAddress!.isNotEmpty) {
      final elapsed = DateTime.now().difference(_lastGeocodeTime!);
      if (elapsed.inSeconds < 3) {
        return _lastGeocodedAddress!;
      }
    }

    try {
      final placemarks = await placemarkFromCoordinates(lat, lng);
      if (placemarks.isNotEmpty) {
        final p = placemarks.first;
        final parts = [p.name, p.subLocality, p.locality]
            .where((e) => e != null && e.isNotEmpty)
            .toSet();
        final addr = parts.join(', ');

        if (addr.isNotEmpty) {
          _lastGeocodedLat = lat;
          _lastGeocodedLng = lng;
          _lastGeocodedAddress = addr;
          _lastGeocodeTime = DateTime.now();
          _gridCache[key] = addr;
          return addr;
        }
      }
    } catch (_) {}

    return _lastGeocodedAddress ?? '';
  }
}
