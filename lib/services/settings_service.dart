import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../models/matcha_product.dart';
import 'subscription_service.dart';

/// Exception thrown when subscription limits prevent an operation
class SubscriptionLimitException implements Exception {
  final String message;
  final dynamic validationResult;

  SubscriptionLimitException(this.message, this.validationResult);

  @override
  String toString() => 'SubscriptionLimitException: $message';
}

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
    // Validate frequency against subscription limits
    final validationResult = await _validateCheckFrequency(minutes);
    if (!validationResult.canSet) {
      throw SubscriptionLimitException(
        validationResult.message,
        validationResult,
      );
    }

    await updateSettings(
      (settings) => settings.copyWith(checkFrequencyMinutes: minutes),
    );
  }

  /// Validate and update enabled sites with subscription limits
  Future<void> setEnabledSites(List<String> sites) async {
    // Validate site count against subscription limits
    final validationResult = await _validateEnabledSites(sites);
    if (!validationResult.canEnable) {
      throw SubscriptionLimitException(
        validationResult.message,
        validationResult,
      );
    }

    await updateSettings((settings) => settings.copyWith(enabledSites: sites));
  }

  /// Validate check frequency against subscription tier limits
  Future<FrequencyValidationResult> _validateCheckFrequency(int minutes) async {
    final settings = await getSettings();
    final tier = settings.subscriptionTier;
    final minAllowed = tier.minCheckFrequencyMinutes;

    return FrequencyValidationResult(
      canSet: minutes >= minAllowed,
      requestedMinutes: minutes,
      minAllowed: minAllowed,
      tier: tier,
    );
  }

  /// Validate enabled sites against subscription tier limits
  Future<VendorValidationResult> _validateEnabledSites(
    List<String> sites,
  ) async {
    final settings = await getSettings();
    final tier = settings.subscriptionTier;
    final maxAllowed = tier.maxVendors;

    return VendorValidationResult(
      canEnable: maxAllowed == -1 || sites.length <= maxAllowed,
      requestedCount: sites.length,
      maxAllowed: maxAllowed,
      tier: tier,
      recommendedSites:
          sites.take(maxAllowed == -1 ? sites.length : maxAllowed).toList(),
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

  Future<bool> getServerMode() async {
    // Always return true since the app now runs exclusively in server mode
    return true;
  }

  Future<void> setServerMode(bool enabled) async {
    // No-op since the app always runs in server mode
    // This method is kept for backward compatibility
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

  // Convenience methods for onboarding tracking
  Future<bool> hasCompletedOnboarding() async {
    final settings = await getSettings();
    return settings.hasCompletedOnboarding;
  }

  Future<void> markOnboardingCompleted() async {
    await updateSettings(
      (settings) => settings.copyWith(hasCompletedOnboarding: true),
    );
  }

  Future<void> resetOnboarding() async {
    await updateSettings(
      (settings) => settings.copyWith(hasCompletedOnboarding: false),
    );
  }

  // Convenience methods for home screen tutorial tracking
  Future<bool> hasSeenHomeScreenTutorial() async {
    final settings = await getSettings();
    return settings.hasSeenHomeScreenTutorial;
  }

  Future<void> markHomeScreenTutorialSeen() async {
    await updateSettings(
      (settings) => settings.copyWith(hasSeenHomeScreenTutorial: true),
    );
  }

  Future<void> resetHomeScreenTutorial() async {
    await updateSettings(
      (settings) => settings.copyWith(hasSeenHomeScreenTutorial: false),
    );
  }

  // Convenience methods for subscription management
  Future<SubscriptionTier> getSubscriptionTier() async {
    final settings = await getSettings();
    return settings.subscriptionTier;
  }

  Future<bool> isPremiumUser() async {
    final settings = await getSettings();
    return settings.isPremium;
  }

  Future<void> updateSubscription({
    required SubscriptionTier tier,
    DateTime? expiresAt,
    String? subscriptionId,
    bool? trialUsed,
  }) async {
    await updateSettings(
      (settings) => settings.copyWith(
        subscriptionTier: tier,
        subscriptionExpiresAt: expiresAt,
        subscriptionId: subscriptionId,
        lastTierCheck: DateTime.now(),
        trialUsed: trialUsed,
      ),
    );
  }

  Future<DateTime?> getSubscriptionExpiresAt() async {
    final settings = await getSettings();
    return settings.subscriptionExpiresAt;
  }

  Future<bool> hasTrialBeenUsed() async {
    final settings = await getSettings();
    return settings.trialUsed;
  }
}
