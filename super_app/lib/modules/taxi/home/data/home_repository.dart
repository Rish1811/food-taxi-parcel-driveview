import 'package:superapp_user/modules/taxi/api/taxi_endpoints.dart';
import 'package:superapp_user/core/network/taxi_api_client.dart';
import 'package:superapp_user/modules/taxi/home/data/models/app_module_model.dart';
import 'package:superapp_user/modules/taxi/home/data/models/set_price_model.dart';
import 'package:superapp_user/modules/taxi/home/data/models/vehicle_type_model.dart';

class HomeRepository {
  final TaxiApiClient api;

  HomeRepository(this.api);

  Future<Map<String, dynamic>> getBootstrap() async {
    final data = await api.get(ApiConstants.bootstrap);
    return Map<String, dynamic>.from(data ?? {});
  }

  Future<List<AppModuleModel>> getAppModules() async {
    final data = await api.get(ApiConstants.appModules, query: {'per_page': 50});
    final results = (data['results'] as List? ?? []);
    final modules = results
        .map((e) => AppModuleModel.fromJson(Map<String, dynamic>.from(e)))
        .where((m) => m.active)
        .toList();
    modules.sort((a, b) => a.orderBy.compareTo(b.orderBy));
    return modules;
  }

  /// The full vehicle catalog, every transport type.
  ///
  /// This used to filter to `taxi` here, which meant delivery vehicles never
  /// reached the app at all and the parcel flow always looked empty. Filtering
  /// now happens per-caller so ride and delivery can share one fetch.
  Future<List<VehicleTypeModel>> getVehicleTypes() async {
    final data = await api.get(ApiConstants.vehicleTypes);
    final results = (data['results'] as List? ?? []);
    return results
        .map((e) => VehicleTypeModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
  }

  Future<List<SetPriceModel>> getSetPrices() async {
    final data = await api.get(ApiConstants.setPrices, query: {'scope': 'ride'});
    final results = (data['results'] as List? ?? []);
    return results.map((e) => SetPriceModel.fromJson(Map<String, dynamic>.from(e))).toList();
  }

  /// Active promo banners for the home strip, newest first.
  Future<List<Map<String, dynamic>>> getBanners() async {
    final data = await api.get(ApiConstants.banners);
    final map = data is Map ? Map<String, dynamic>.from(data) : const <String, dynamic>{};
    final results = map['results'] as List? ?? const [];
    return results.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Marker art per vehicle type, as `{ vehicleTypeId, icon_types, map_icon }`.
  Future<List<Map<String, dynamic>>> getVehicleMapIcons() async {
    final data = await api.get(ApiConstants.vehicleMapIcons);
    final map = data is Map ? Map<String, dynamic>.from(data) : const <String, dynamic>{};
    final results = map['results'] as List? ?? const [];
    return results.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// Returns the ETA (in minutes) of the closest available driver for a given
  /// vehicle type near [lat]/[lng], or null if none are currently available.
  Future<int?> getClosestDriverEtaMinutes({
    required double lat,
    required double lng,
    required String vehicleTypeId,
  }) async {
    final data = await api.get(ApiConstants.availableDrivers, query: {
      'lat': lat,
      'lng': lng,
      'vehicleTypeId': vehicleTypeId,
    });
    final map = Map<String, dynamic>.from(data ?? {});
    final eta = map['closestDriverEtaMinutes'];
    if (eta == null) return null;
    return int.tryParse('$eta') ?? double.tryParse('$eta')?.round();
  }
}
