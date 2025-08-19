import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'settings_service.dart';

class SearchHistoryService {
  static const String _searchHistoryKey = 'search_history';
  static const int _maxHistoryItems = 10;

  // For server mode
  static const String _userSearchHistoryCollection = 'user_search_history';

  static final SettingsService _settingsService = SettingsService();

  /// Add a search term to history
  static Future<void> addSearchTerm(String searchTerm) async {
    if (searchTerm.trim().isEmpty) return;

    final trimmedTerm = searchTerm.trim();

    final isServerMode = await _settingsService.getServerMode();
    if (isServerMode) {
      await _addSearchTermToFirestore(trimmedTerm);
    } else {
      await _addSearchTermToLocal(trimmedTerm);
    }
  }

  /// Get search history
  static Future<List<String>> getSearchHistory() async {
    final isServerMode = await _settingsService.getServerMode();
    if (isServerMode) {
      return await _getSearchHistoryFromFirestore();
    } else {
      return await _getSearchHistoryFromLocal();
    }
  }

  /// Clear search history
  static Future<void> clearSearchHistory() async {
    final isServerMode = await _settingsService.getServerMode();
    if (isServerMode) {
      await _clearSearchHistoryFromFirestore();
    } else {
      await _clearSearchHistoryFromLocal();
    }
  }

  /// Remove a specific search term
  static Future<void> removeSearchTerm(String searchTerm) async {
    final isServerMode = await _settingsService.getServerMode();
    if (isServerMode) {
      await _removeSearchTermFromFirestore(searchTerm);
    } else {
      await _removeSearchTermFromLocal(searchTerm);
    }
  }

  // Local storage methods
  static Future<void> _addSearchTermToLocal(String searchTerm) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_searchHistoryKey) ?? [];

    // Remove if already exists
    history.remove(searchTerm);

    // Add to beginning
    history.insert(0, searchTerm);

    // Keep only max items
    if (history.length > _maxHistoryItems) {
      history = history.take(_maxHistoryItems).toList();
    }

    await prefs.setStringList(_searchHistoryKey, history);
  }

  static Future<List<String>> _getSearchHistoryFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_searchHistoryKey) ?? [];
  }

  static Future<void> _clearSearchHistoryFromLocal() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_searchHistoryKey);
  }

  static Future<void> _removeSearchTermFromLocal(String searchTerm) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> history = prefs.getStringList(_searchHistoryKey) ?? [];
    history.remove(searchTerm);
    await prefs.setStringList(_searchHistoryKey, history);
  }

  // Firestore methods
  static Future<void> _addSearchTermToFirestore(String searchTerm) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final docRef = firestore
          .collection(_userSearchHistoryCollection)
          .doc(user.uid);

      // Get current history
      final doc = await docRef.get();
      List<String> history = [];

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data.containsKey('searches')) {
          history = List<String>.from(data['searches'] ?? []);
        }
      }

      // Remove if already exists
      history.remove(searchTerm);

      // Add to beginning
      history.insert(0, searchTerm);

      // Keep only max items
      if (history.length > _maxHistoryItems) {
        history = history.take(_maxHistoryItems).toList();
      }

      // Save back to Firestore
      await docRef.set({
        'searches': history,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('Error adding search term to Firestore: $e');
    }
  }

  static Future<List<String>> _getSearchHistoryFromFirestore() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return [];

      final doc =
          await firestore
              .collection(_userSearchHistoryCollection)
              .doc(user.uid)
              .get();

      if (doc.exists) {
        final data = doc.data();
        if (data != null && data.containsKey('searches')) {
          return List<String>.from(data['searches'] ?? []);
        }
      }

      return [];
    } catch (e) {
      print('Error getting search history from Firestore: $e');
      return [];
    }
  }

  static Future<void> _clearSearchHistoryFromFirestore() async {
    try {
      final firestore = FirebaseFirestore.instance;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      await firestore
          .collection(_userSearchHistoryCollection)
          .doc(user.uid)
          .delete();
    } catch (e) {
      print('Error clearing search history from Firestore: $e');
    }
  }

  static Future<void> _removeSearchTermFromFirestore(String searchTerm) async {
    try {
      final firestore = FirebaseFirestore.instance;
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      final docRef = firestore
          .collection(_userSearchHistoryCollection)
          .doc(user.uid);

      final doc = await docRef.get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null && data.containsKey('searches')) {
          List<String> history = List<String>.from(data['searches'] ?? []);
          history.remove(searchTerm);

          await docRef.update({
            'searches': history,
            'lastUpdated': FieldValue.serverTimestamp(),
          });
        }
      }
    } catch (e) {
      print('Error removing search term from Firestore: $e');
    }
  }
}
