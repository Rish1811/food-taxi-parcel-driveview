import 'dart:async';
import 'dart:developer' as developer;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:superapp_user/shared/search/application/search_providers.dart';
import 'package:superapp_user/shared/search/data/search_service.dart';
import 'package:superapp_user/core/speech/speech_service.dart';
import 'package:superapp_user/shared/search/presentation/viewmodels/search_state.dart';

final searchViewModelProvider =
    NotifierProvider<SearchViewModel, SearchState>(() {
  return SearchViewModel();
});

class SearchViewModel extends Notifier<SearchState> {
  late final SearchService _searchService;
  late final SpeechService _speechService;
  Timer? _debounceTimer;

  @override
  SearchState build() {
    _searchService = ref.watch(searchServiceProvider);
    _speechService = ref.watch(speechServiceProvider);
    Future.microtask(() => loadRecentSearches());
    return const SearchState();
  }

  Future<void> loadRecentSearches() async {
    final recent = await _searchService.getRecentSearches();
    state = state.copyWith(recentSearches: recent);
  }

  void setMode(SearchMode mode) {
    if (state.mode == mode) return;
    state = state.copyWith(mode: mode, results: const [], suggestions: const []);
    if (state.query.isNotEmpty) {
      onQueryChanged(state.query);
    }
  }

  void onQueryChanged(String text) {
    state = state.copyWith(query: text, speechError: null);

    _debounceTimer?.cancel();
    if (text.trim().isEmpty) {
      state = state.copyWith(
        results: const [],
        suggestions: const [],
        isSearching: false,
      );
      return;
    }

    state = state.copyWith(isSearching: true);

    _debounceTimer = Timer(const Duration(milliseconds: 300), () async {
      final response = state.mode == SearchMode.home
          ? await _searchService.searchHome(text)
          : await _searchService.searchStore99(text);

      if (response.isSuccess && response.data != null) {
        final results = response.data!;
        final suggestions = _searchService.getSuggestions(text, results);
        state = state.copyWith(
          results: results,
          suggestions: suggestions,
          isSearching: false,
        );
      } else {
        state = state.copyWith(
          results: const [],
          suggestions: const [],
          isSearching: false,
          errorMessage: response.message ?? 'Search failed.',
        );
      }
    });
  }

  Future<void> submitQuery(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return;
    await _searchService.saveRecentSearch(clean);
    await loadRecentSearches();
    onQueryChanged(clean);
  }

  Future<void> removeRecentSearch(String query) async {
    await _searchService.removeRecentSearch(query);
    await loadRecentSearches();
  }

  Future<void> clearRecentSearches() async {
    await _searchService.clearRecentSearches();
    state = state.copyWith(recentSearches: const []);
  }

  // ==================== VOICE SEARCH (MIC) ====================

  Future<void> startVoiceSearch({Function(String text)? onSpeechComplete}) async {
    developer.log('[VOICE] Listening started', name: 'VOICE');
    state = state.copyWith(
      isListening: true,
      recognizedText: '',
      speechError: null,
    );

    await _speechService.startListening(
      onResult: (text) {
        developer.log('[VOICE] Speech recognized', name: 'VOICE');
        developer.log('[VOICE] Recognized text: "$text"', name: 'VOICE');
        state = state.copyWith(recognizedText: text);
      },
      onError: (errorMsg) {
        developer.log('[VOICE] Speech recognition error: "$errorMsg"', name: 'VOICE');
        state = state.copyWith(
          isListening: false,
          speechError: errorMsg,
        );
      },
      onDone: () {
        developer.log('[VOICE] Listening stopped', name: 'VOICE');
        final recognized = state.recognizedText.trim();
        state = state.copyWith(isListening: false);
        if (recognized.isNotEmpty) {
          onSpeechComplete?.call(recognized);
        }
      },
    );
  }

  Future<void> stopVoiceSearch() async {
    developer.log('[VOICE] Listening stopped', name: 'VOICE');
    await _speechService.stopListening();
    state = state.copyWith(isListening: false);
  }

  Future<void> cancelVoiceSearch() async {
    developer.log('[VOICE] Listening stopped', name: 'VOICE');
    await _speechService.stopListening();
    state = state.copyWith(
      isListening: false,
      recognizedText: '',
      speechError: null,
    );
  }

  void clearQuery() {
    _debounceTimer?.cancel();
    state = state.copyWith(
      query: '',
      results: const [],
      suggestions: const [],
      isSearching: false,
    );
  }
}
