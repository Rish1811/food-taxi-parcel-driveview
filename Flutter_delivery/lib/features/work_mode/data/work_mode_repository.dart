import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../core/network/api_endpoints.dart';
import '../../../core/network/dio_client.dart';
import 'work_mode.dart';

/// What the driver is set up for and what they've currently chosen.
class WorkModeStatus {
  const WorkModeStatus({required this.mode, required this.capabilities});

  final WorkMode mode;

  /// `taxi` / `delivery` — what the operator has approved this driver for.
  /// A mode outside these is rejected by the server, so the UI disables it.
  final Set<String> capabilities;

  bool get canDoFood => capabilities.contains('delivery');
  bool get canDoTaxi => capabilities.contains('taxi');

  /// True when the driver is approved for exactly one service — there is
  /// nothing to toggle, so the switcher is pointless and gets hidden.
  bool get isSingleService => capabilities.length < 2;

  static const fallback = WorkModeStatus(
    mode: WorkMode.delivery,
    capabilities: {'delivery'},
  );
}

class WorkModeRepository {
  WorkModeRepository(this._dio);

  final Dio _dio;

  /// Reads the driver document for the current work mode and capabilities.
  Future<Result<WorkModeStatus, AppError>> fetch() async {
    try {
      final res = await _dio.get(ApiEndpoints.driverMe);
      final driver = _driverOf(res.data);
      return Result.success(_statusOf(driver));
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Future<Result<WorkModeStatus, AppError>> setMode(WorkMode mode) async {
    try {
      final res = await _dio.patch(
        ApiEndpoints.workMode,
        data: {'workMode': mode.wire},
      );
      final data = res.data is Map<String, dynamic>
          ? (res.data['data'] as Map<String, dynamic>? ?? const {})
          : const <String, dynamic>{};
      return Result.success(_statusOf(data));
    } on DioException catch (e) {
      return Result.failure(_mapError(e));
    }
  }

  Map<String, dynamic> _driverOf(dynamic body) {
    final data = body is Map<String, dynamic> ? body['data'] : null;
    if (data is Map<String, dynamic>) {
      final driver = data['driver'];
      if (driver is Map<String, dynamic>) return driver;
      return data;
    }
    return const {};
  }

  WorkModeStatus _statusOf(Map<String, dynamic> json) {
    final raw = json['serviceCapabilities'];
    final caps = raw is List
        ? raw.map((e) => e.toString()).where((e) => e.isNotEmpty).toSet()
        : <String>{};
    return WorkModeStatus(
      mode: WorkMode.parse(json['workMode']?.toString()),
      // An empty list from the server means "taxi only" — that is the schema
      // default, and treating it as "no capabilities" would disable every
      // option and leave the driver stuck.
      capabilities: caps.isEmpty ? {'taxi'} : caps,
    );
  }

  AppError _mapError(DioException e) {
    final data = e.response?.data;
    final message = data is Map
        ? (data['message'] ?? data['error'])?.toString()
        : null;
    return NetworkError(message ?? e.message ?? 'Could not update work mode');
  }
}

final workModeRepositoryProvider = Provider<WorkModeRepository>((ref) {
  return WorkModeRepository(ref.read(dioProvider));
});
