import 'package:superapp_user/core/network/api_response.dart';
import 'package:superapp_user/shared/search/data/search_result.dart';
import 'package:superapp_user/modules/food/data/contracts/search_repository.dart';
import 'package:superapp_user/modules/food/api/datasources/search_local_datasource.dart';
import 'package:superapp_user/modules/food/api/datasources/search_remote_datasource.dart';

class SearchRepositoryImpl implements SearchRepository {
  final SearchRemoteDataSource _remoteDataSource;
  final SearchLocalDataSource _localDataSource;

  SearchRepositoryImpl({
    required SearchRemoteDataSource remoteDataSource,
    required SearchLocalDataSource localDataSource,
  })  : _remoteDataSource = remoteDataSource,
        _localDataSource = localDataSource;

  @override
  Future<ApiResponse<List<SearchResult>>> searchHome(String query) async {
    try {
      final results = await _remoteDataSource.searchHome(query);
      return ApiResponse.success(results);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  @override
  Future<ApiResponse<List<SearchResult>>> searchStore99(String query) async {
    try {
      final results = await _remoteDataSource.searchStore99(query);
      final eligibleResults =
          results.where((r) => r.price == null || r.price! <= 99.0).toList();
      return ApiResponse.success(eligibleResults);
    } catch (e) {
      return ApiResponse.error(e.toString());
    }
  }

  @override
  Future<List<String>> getRecentSearches() {
    return _localDataSource.getRecentSearches();
  }

  @override
  Future<void> saveRecentSearch(String query) {
    return _localDataSource.saveRecentSearch(query);
  }

  @override
  Future<void> clearRecentSearches() {
    return _localDataSource.clearRecentSearches();
  }

  @override
  Future<void> removeRecentSearch(String query) {
    return _localDataSource.removeRecentSearch(query);
  }
}
