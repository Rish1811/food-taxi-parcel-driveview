import 'package:superapp_user/shared/search/data/search_result.dart';

enum SearchMode {
  home,
  store99,
}

class SearchState {
  final String query;
  final SearchMode mode;
  final List<SearchResult> results;
  final List<String> suggestions;
  final List<String> recentSearches;
  final bool isSearching;
  final bool isListening;
  final String recognizedText;
  final String? errorMessage;
  final String? speechError;

  const SearchState({
    this.query = '',
    this.mode = SearchMode.home,
    this.results = const [],
    this.suggestions = const [],
    this.recentSearches = const [],
    this.isSearching = false,
    this.isListening = false,
    this.recognizedText = '',
    this.errorMessage,
    this.speechError,
  });

  SearchState copyWith({
    String? query,
    SearchMode? mode,
    List<SearchResult>? results,
    List<String>? suggestions,
    List<String>? recentSearches,
    bool? isSearching,
    bool? isListening,
    String? recognizedText,
    String? errorMessage,
    String? speechError,
  }) {
    return SearchState(
      query: query ?? this.query,
      mode: mode ?? this.mode,
      results: results ?? this.results,
      suggestions: suggestions ?? this.suggestions,
      recentSearches: recentSearches ?? this.recentSearches,
      isSearching: isSearching ?? this.isSearching,
      isListening: isListening ?? this.isListening,
      recognizedText: recognizedText ?? this.recognizedText,
      errorMessage: errorMessage,
      speechError: speechError,
    );
  }
}
