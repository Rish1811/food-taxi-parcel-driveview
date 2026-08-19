import 'package:superapp_user/core/network/api_response.dart';
import 'package:superapp_user/shared/search/data/search_result.dart';

/// Contract for search data access and persistence operations.
abstract class SearchRepository {
  Future<ApiResponse<List<SearchResult>>> searchHome(String query);
  Future<ApiResponse<List<SearchResult>>> searchStore99(String query);
  Future<List<String>> getRecentSearches();
  Future<void> saveRecentSearch(String query);
  Future<void> clearRecentSearches();
  Future<void> removeRecentSearch(String query);
}
