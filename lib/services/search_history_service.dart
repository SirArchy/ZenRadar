// ignore_for_file: avoid_print

import 'package:shared_preferences/shared_preferences.dart';

class SearchHistoryService {
  static const String _searchHistoryKey = 'search_history';
  static const int _maxHistoryItems = 10;

  /// Add a search term to the local search history
  static Future<void> addSearchTerm(String term) async {
    if (term.trim().isEmpty) return;

    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> searchHistory = prefs.getStringList(_searchHistoryKey) ?? [];

      // Remove if already exists to avoid duplicates
      searchHistory.remove(term.trim());

      // Add to the beginning
      searchHistory.insert(0, term.trim());

      // Keep only the most recent items
      if (searchHistory.length > _maxHistoryItems) {
        searchHistory = searchHistory.sublist(0, _maxHistoryItems);
      }

      await prefs.setStringList(_searchHistoryKey, searchHistory);
    } catch (e) {
      print('Error adding search term to local storage: $e');
    }
  }

  /// Get search history from local storage
  static Future<List<String>> getSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getStringList(_searchHistoryKey) ?? [];
    } catch (e) {
      print('Error getting search history from local storage: $e');
      return [];
    }
  }

  /// Remove a specific search term from history
  static Future<void> removeSearchTerm(String term) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> searchHistory = prefs.getStringList(_searchHistoryKey) ?? [];
      searchHistory.remove(term);
      await prefs.setStringList(_searchHistoryKey, searchHistory);
    } catch (e) {
      print('Error removing search term from local storage: $e');
    }
  }

  /// Clear all search history
  static Future<void> clearSearchHistory() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_searchHistoryKey);
    } catch (e) {
      print('Error clearing search history from local storage: $e');
    }
  }
}
