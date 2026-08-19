import 'package:superapp_user/core/error/failures.dart';
import 'package:superapp_user/core/network/api_client.dart';
import 'package:superapp_user/core/error/taxi_api_exception.dart';

/// Adapter that lets the taxi/parcel/rental repositories keep their original
/// call style (`await api.get(path)` returning `dynamic`) while actually
/// running on the app's single [ApiClient].
///
/// That client brings things taxi never had: bearer injection, single-flight
/// 401 refresh with replay, `{success, message, data}` unwrapping, the disk
/// backed GET cache, and typed [Failure]s.
///
/// Failures are re-thrown as [TaxiApiException] so the ~20 existing
/// `on TaxiApiException catch (e)` sites keep working unchanged. Migrating
/// those to typed [Failure] handling is worthwhile but is deliberately a
/// separate change — doing it here would have meant rewriting 10 repositories
/// and every controller that catches from them in the same commit.
class TaxiApiClient {
  const TaxiApiClient(this._api);

  final ApiClient _api;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _guard(() => _api.get<dynamic>(path, query: query));

  Future<dynamic> post(String path, {Object? data, Map<String, dynamic>? query}) =>
      _guard(() => _api.post<dynamic>(path, body: data, query: query));

  Future<dynamic> patch(String path, {Object? data, Map<String, dynamic>? query}) =>
      _guard(() => _api.patch<dynamic>(path, body: data));

  Future<dynamic> put(String path, {Object? data, Map<String, dynamic>? query}) =>
      _guard(() => _api.put<dynamic>(path, body: data));

  Future<dynamic> delete(String path, {Object? data, Map<String, dynamic>? query}) =>
      _guard(() => _api.delete<dynamic>(path, body: data));

  Future<dynamic> _guard(Future<dynamic> Function() call) async {
    try {
      return await call();
    } on Failure catch (failure) {
      throw TaxiApiException(failure.message, failure: failure);
    }
  }
}
