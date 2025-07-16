import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/matcha_product.dart';

class SettingsService {
  static final SettingsService _instance = SettingsService._internal();
  factory SettingsService() => _instance;
  SettingsService._internal();

  static SettingsService get instance => _instance;

  static const String _settingsKey = 'user_settings';

  Future<UserSettings> getSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = prefs.getString(_settingsKey);

    if (settingsJson != null) {
      try {
        final Map<String, dynamic> settingsMap = json.decode(settingsJson);
        return UserSettings.fromJson(settingsMap);
      } catch (e) {
        // If there's an error parsing, return default settings
        return UserSettings();
      }
    }

    return UserSettings();
  }

  Future<void> saveSettings(UserSettings settings) async {
    final prefs = await SharedPreferences.getInstance();
    final settingsJson = json.encode(settings.toJson());
    await prefs.setString(_settingsKey, settingsJson);
  }

  Future<void> updateSettings(
    UserSettings Function(UserSettings) updater,
  ) async {
    final currentSettings = await getSettings();
    final newSettings = updater(currentSettings);
    await saveSettings(newSettings);
  }

  // Convenience methods for common settings
  Future<bool> isHeadModeEnabled() async {
    final settings = await getSettings();
    return settings.headModeEnabled;
  }

  Future<void> setHeadModeEnabled(bool enabled) async {
    await updateSettings(
      (settings) => settings.copyWith(headModeEnabled: enabled),
    );
  }

  Future<int> getItemsPerPage() async {
    final settings = await getSettings();
    return settings.itemsPerPage;
  }

  Future<void> setItemsPerPage(int itemsPerPage) async {
    await updateSettings(
      (settings) => settings.copyWith(itemsPerPage: itemsPerPage),
    );
  }

  Future<int> getMaxStorageMB() async {
    final settings = await getSettings();
    return settings.maxStorageMB;
  }

  Future<void> setMaxStorageMB(int maxStorageMB) async {
    await updateSettings(
      (settings) => settings.copyWith(maxStorageMB: maxStorageMB),
    );
  }

  Future<bool> shouldShowOutOfStock() async {
    final settings = await getSettings();
    return settings.showOutOfStock;
  }

  Future<void> setShowOutOfStock(bool show) async {
    await updateSettings((settings) => settings.copyWith(showOutOfStock: show));
  }

  Future<String> getSortBy() async {
    final settings = await getSettings();
    return settings.sortBy;
  }

  Future<bool> isSortAscending() async {
    final settings = await getSettings();
    return settings.sortAscending;
  }

  Future<void> setSorting(String sortBy, bool ascending) async {
    await updateSettings(
      (settings) => settings.copyWith(sortBy: sortBy, sortAscending: ascending),
    );
  }
}
