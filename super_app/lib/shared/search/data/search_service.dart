import 'dart:developer' as developer;
import 'package:superapp_user/core/network/api_response.dart';
import 'package:superapp_user/shared/search/data/search_result.dart';
import 'package:superapp_user/modules/food/data/contracts/search_repository.dart';

/// Business domain service for normalization, search processing, and suggestions.
class SearchService {
  final SearchRepository _repository;

  SearchService(this._repository);

  /// Cleans query text: trims leading/trailing spaces and condenses internal extra spaces.
  String sanitizeQuery(String query) {
    return query.trim().replaceAll(RegExp(r'\s+'), ' ');
  }

  static const _fillerWords = <String>{
    'and',
    'or',
    'with',
    'also',
    'plus',
    '&',
    '+',
  };

  /// Parses a spoken or typed query into individual search terms by splitting on
  /// whitespace, conjunctions, connectors, and punctuation while ignoring filler words.
  List<String> parseSearchTerms(String query) {
    final clean = sanitizeQuery(query);
    if (clean.isEmpty) return const [];

    final rawParts = clean.split(RegExp(r'\s+|\b(?:and|or|with|also|plus)\b|[,;&+]', caseSensitive: false));

    final terms = <String>[];
    final seen = <String>{};

    for (final part in rawParts) {
      final trimmed = part.trim();
      if (trimmed.length < 2) continue;
      final lower = trimmed.toLowerCase();
      if (_fillerWords.contains(lower)) continue;
      if (seen.add(lower)) {
        terms.add(trimmed);
      }
    }

    if (terms.isEmpty) return [clean];

    if (terms.length > 1 && !terms.map((t) => t.toLowerCase()).contains(clean.toLowerCase())) {
      return [clean, ...terms];
    }

    return terms;
  }

  Future<ApiResponse<List<SearchResult>>> searchHome(String rawQuery) async {
    final clean = sanitizeQuery(rawQuery);
    if (clean.isEmpty) return ApiResponse.success(const []);

    final terms = parseSearchTerms(clean);

    developer.log('[SEARCH] Original query: "$clean"', name: 'SEARCH');
    developer.log('[SEARCH] Parsed search terms: $terms', name: 'SEARCH');

    if (terms.length <= 1) {
      developer.log('[SEARCH] API request for term "$clean"', name: 'SEARCH');
      final response = await _repository.searchHome(clean);
      final count = response.data?.length ?? 0;
      developer.log('[SEARCH] API response count for term "$clean": $count', name: 'SEARCH');
      developer.log('[SEARCH] Final merged result count: $count', name: 'SEARCH');
      return response;
    }

    final responses = await Future.wait(
      terms.map((t) async {
        developer.log('[SEARCH] API request for term "$t"', name: 'SEARCH');
        final res = await _repository.searchHome(t);
        final count = res.data?.length ?? 0;
        developer.log('[SEARCH] API response count for term "$t": $count', name: 'SEARCH');
        return res;
      }),
    );

    final merged = <SearchResult>[];
    final seenKeys = <String>{};

    for (final res in responses) {
      if (res.isSuccess && res.data != null) {
        for (final item in res.data!) {
          final key = '${item.type.name}_${item.id}';
          if (seenKeys.add(key)) {
            merged.add(item);
          }
        }
      }
    }

    developer.log('[SEARCH] Final merged result count: ${merged.length}', name: 'SEARCH');
    return ApiResponse.success(merged);
  }

  Future<ApiResponse<List<SearchResult>>> searchStore99(String rawQuery) async {
    final clean = sanitizeQuery(rawQuery);
    if (clean.isEmpty) return ApiResponse.success(const []);

    final terms = parseSearchTerms(clean);

    developer.log('[SEARCH] Original query (Store99): "$clean"', name: 'SEARCH');
    developer.log('[SEARCH] Parsed search terms: $terms', name: 'SEARCH');

    if (terms.length <= 1) {
      developer.log('[SEARCH] API request for term "$clean"', name: 'SEARCH');
      final response = await _repository.searchStore99(clean);
      final count = response.data?.length ?? 0;
      developer.log('[SEARCH] API response count for term "$clean": $count', name: 'SEARCH');
      developer.log('[SEARCH] Final merged result count: $count', name: 'SEARCH');
      return response;
    }

    final responses = await Future.wait(
      terms.map((t) async {
        developer.log('[SEARCH] API request for term "$t"', name: 'SEARCH');
        final res = await _repository.searchStore99(t);
        final count = res.data?.length ?? 0;
        developer.log('[SEARCH] API response count for term "$t": $count', name: 'SEARCH');
        return res;
      }),
    );

    final merged = <SearchResult>[];
    final seenKeys = <String>{};

    for (final res in responses) {
      if (res.isSuccess && res.data != null) {
        for (final item in res.data!) {
          final key = '${item.type.name}_${item.id}';
          if (seenKeys.add(key)) {
            merged.add(item);
          }
        }
      }
    }

    developer.log('[SEARCH] Final merged result count: ${merged.length}', name: 'SEARCH');
    return ApiResponse.success(merged);
  }

  Future<List<String>> getRecentSearches() {
    return _repository.getRecentSearches();
  }

  Future<void> saveRecentSearch(String rawQuery) {
    final clean = sanitizeQuery(rawQuery);
    if (clean.length < 2) return Future.value();
    return _repository.saveRecentSearch(clean);
  }

  Future<void> clearRecentSearches() {
    return _repository.clearRecentSearches();
  }

  Future<void> removeRecentSearch(String query) {
    return _repository.removeRecentSearch(query);
  }

  /// Generate suggestions dynamically from matching keywords across parsed search terms.
  List<String> getSuggestions(String query, List<SearchResult> currentResults) {
    final clean = sanitizeQuery(query).toLowerCase();
    if (clean.isEmpty) return const [];

    final terms = parseSearchTerms(query).map((t) => t.toLowerCase()).toList();

    final set = <String>{};
    for (final res in currentResults) {
      final titleLower = res.title.toLowerCase();
      final subLower = res.subtitle.toLowerCase();

      final matches = terms.any((t) => titleLower.contains(t) || subLower.contains(t));
      if (matches) {
        set.add(res.title);
        if (subLower.length < 25 && subLower.isNotEmpty) {
          set.add(res.subtitle);
        }
      }
      if (set.length >= 6) break;
    }
    return set.toList();
  }
}
