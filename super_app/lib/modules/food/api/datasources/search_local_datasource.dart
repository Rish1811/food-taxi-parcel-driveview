import 'package:shared_preferences/shared_preferences.dart';

abstract class SearchLocalDataSource {
  Future<List<String>> getRecentSearches();
  Future<void> saveRecentSearch(String query);
  Future<void> removeRecentSearch(String query);
  Future<void> clearRecentSearches();
}

class SearchLocalDataSourceImpl implements SearchLocalDataSource {
  static const String _key = 'recent_searches_list';
  static const int _maxRecentCount = 8;

  @override
  Future<List<String>> getRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? const [];
  }

  @override
  Future<void> saveRecentSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getRecentSearches();
    final updated = List<String>.from(current);

    updated.removeWhere((item) => item.toLowerCase() == query.toLowerCase());
    updated.insert(0, query);

    if (updated.length > _maxRecentCount) {
      updated.removeLast();
    }

    await prefs.setStringList(_key, updated);
  }

  @override
  Future<void> removeRecentSearch(String query) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getRecentSearches();
    final updated = current.where((item) => item.toLowerCase() != query.toLowerCase()).toList();
    await prefs.setStringList(_key, updated);
  }

  @override
  Future<void> clearRecentSearches() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
