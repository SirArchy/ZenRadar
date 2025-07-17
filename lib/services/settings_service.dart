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

  Future<String> getStartTime() async {
    final settings = await getSettings();
    return settings.startTime;
  }

  Future<String> getEndTime() async {
    final settings = await getSettings();
    return settings.endTime;
  }

  Future<void> setActiveHours(String startTime, String endTime) async {
    await updateSettings(
      (settings) => settings.copyWith(startTime: startTime, endTime: endTime),
    );
  }

  Future<int> getCheckFrequencyMinutes() async {
    final settings = await getSettings();
    return settings.checkFrequencyMinutes;
  }

  Future<void> setCheckFrequencyMinutes(int minutes) async {
    await updateSettings(
      (settings) => settings.copyWith(checkFrequencyMinutes: minutes),
    );
  }

  Future<bool> isNotificationsEnabled() async {
    final settings = await getSettings();
    return settings.notificationsEnabled;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    await updateSettings(
      (settings) => settings.copyWith(notificationsEnabled: enabled),
    );
  }

  /// Check if current time is within active hours
  Future<bool> isWithinActiveHours() async {
    final settings = await getSettings();
    final now = DateTime.now();

    try {
      // Parse start and end times
      final startParts = settings.startTime.split(':');
      final endParts = settings.endTime.split(':');

      if (startParts.length != 2 || endParts.length != 2) {
        return true; // Default to allowing if time format is invalid
      }

      final startHour = int.parse(startParts[0]);
      final startMinute = int.parse(startParts[1]);
      final endHour = int.parse(endParts[0]);
      final endMinute = int.parse(endParts[1]);

      // Validate hour and minute ranges
      if (startHour < 0 ||
          startHour > 23 ||
          endHour < 0 ||
          endHour > 23 ||
          startMinute < 0 ||
          startMinute > 59 ||
          endMinute < 0 ||
          endMinute > 59) {
        return true;
      }

      // Create DateTime objects for today's start and end times
      final today = DateTime(now.year, now.month, now.day);
      final startTime = today.add(
        Duration(hours: startHour, minutes: startMinute),
      );
      var endTime = today.add(Duration(hours: endHour, minutes: endMinute));

      // Handle overnight periods (e.g., 22:00 to 06:00)
      if (endTime.isBefore(startTime) || endTime.isAtSameMomentAs(startTime)) {
        // End time is next day
        endTime = endTime.add(const Duration(days: 1));
      }

      // Check if current time is within the active period
      return now.isAfter(startTime) && now.isBefore(endTime);
    } catch (e) {
      return true; // Default to allowing if parsing fails
    }
  }
}
