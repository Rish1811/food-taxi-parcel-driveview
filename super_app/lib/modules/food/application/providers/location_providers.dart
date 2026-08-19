import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superapp_user/core/location/location_service.dart';

final locationServiceProvider = Provider<LocationService>((ref) {
  return LocationService();
});
