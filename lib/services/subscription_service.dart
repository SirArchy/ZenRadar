import 'package:flutter/foundation.dart';
import '../models/matcha_product.dart';
import 'settings_service.dart';
import 'database_service.dart';
import 'payment_service.dart';

/// Service to handle subscription tier validation and limits
/// Centralizes all freemium model logic
class SubscriptionService extends ChangeNotifier {
  static final SubscriptionService _instance = SubscriptionService._internal();
  factory SubscriptionService() => _instance;
  SubscriptionService._internal();

  static SubscriptionService get instance => _instance;

  // Debug mode override
  bool _debugPremiumMode = false;

  /// Get current subscription tier from settings
  Future<SubscriptionTier> getCurrentTier() async {
    final settings = await SettingsService.instance.getSettings();
    return settings.subscriptionTier;
  }

  /// Check if user has premium access (including trial)
  Future<bool> isPremiumUser() async {
    // Debug mode override
    if (kDebugMode && _debugPremiumMode) {
      return true;
    }

    final settings = await SettingsService.instance.getSettings();
    return settings.isPremium; // This now includes trial logic
  }

  /// Check if user has an active trial
  Future<bool> isTrialActive() async {
    final settings = await SettingsService.instance.getSettings();
    return settings.isTrialActive;
  }

  /// Check if user can start a trial
  Future<bool> canStartTrial() async {
    final settings = await SettingsService.instance.getSettings();
    return settings.canStartTrial;
  }

  /// Start a 7-day trial for the user
  Future<bool> startTrial() async {
    try {
      final settings = await SettingsService.instance.getSettings();

      // Check if user can start trial
      if (!settings.canStartTrial) {
        if (kDebugMode) {
          print(
            '❌ Cannot start trial: User has already used trial or has active trial',
          );
        }
        return false;
      }

      // Start the trial
      final now = DateTime.now();
      final trialEnd = now.add(const Duration(days: 7));

      await SettingsService.instance.updateSettings(
        (currentSettings) => currentSettings.copyWith(
          trialStartedAt: now,
          trialEndsAt: trialEnd,
          trialUsed: true,
        ),
      );

      if (kDebugMode) {
        print('🎉 Trial started! Expires: $trialEnd');
      }

      // Notify listeners about the change
      notifyListeners();

      return true;
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error starting trial: $e');
      }
      return false;
    }
  }

  /// Get trial status information
  Future<TrialStatus> getTrialStatus() async {
    final settings = await SettingsService.instance.getSettings();
    return TrialStatus(
      canStart: settings.canStartTrial,
      isActive: settings.isTrialActive,
      hasExpired: settings.isTrialExpired,
      daysRemaining: settings.trialDaysRemaining,
      trialStartedAt: settings.trialStartedAt,
      trialEndsAt: settings.trialEndsAt,
    );
  }

  /// Set debug premium mode (only available in debug builds)
  Future<void> setDebugPremiumMode(bool enabled) async {
    if (kDebugMode) {
      _debugPremiumMode = enabled;
      if (kDebugMode) {
        print('🐛 Debug premium mode ${enabled ? 'enabled' : 'disabled'}');
      }
      // Notify listeners about the change
      notifyListeners();
    }
  }

  /// Get debug premium mode status
  bool get isDebugPremiumMode => kDebugMode && _debugPremiumMode;

  /// Sync subscription status from payment service and update local settings
  Future<void> syncSubscriptionStatus() async {
    try {
      final paymentService = PaymentService.instance;
      final subscriptionStatus = await paymentService.getSubscriptionStatus();

      // Update local settings with the latest status
      await SettingsService.instance.updateSettings(
        (settings) => settings.copyWith(
          subscriptionTier:
              subscriptionStatus.isPremium
                  ? SubscriptionTier.premium
                  : SubscriptionTier.free,
        ),
      );

      if (kDebugMode) {
        print(
          '📱 Subscription status synced: ${subscriptionStatus.toString()}',
        );
      }

      // Notify listeners about the change
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error syncing subscription status: $e');
      }
      // Don't throw error to avoid disrupting app flow
    }
  }

  /// Check if subscription has expired
  Future<bool> isSubscriptionExpired() async {
    final settings = await SettingsService.instance.getSettings();
    return settings.isSubscriptionExpired;
  }

  /// Validate if user can add more favorites
  Future<FavoriteValidationResult> canAddMoreFavorites() async {
    try {
      final settings = await SettingsService.instance.getSettings();
      final currentFavoriteCount =
          await DatabaseService.platformService.getFavoriteProductIds();

      final canAdd = settings.canAddFavorites(currentFavoriteCount.length);

      return FavoriteValidationResult(
        canAdd: canAdd,
        currentCount: currentFavoriteCount.length,
        maxAllowed: settings.maxAllowedFavorites,
        tier: settings.subscriptionTier,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error checking favorite limits: $e');
      }
      return FavoriteValidationResult(
        canAdd: false,
        currentCount: 0,
        maxAllowed: 0,
        tier: SubscriptionTier.free,
      );
    }
  }

  /// Validate if user can enable more vendors
  Future<VendorValidationResult> canEnableMoreVendors(
    List<String> requestedSites,
  ) async {
    try {
      final settings = await SettingsService.instance.getSettings();

      final canEnable = settings.canEnableVendors(requestedSites.length);

      return VendorValidationResult(
        canEnable: canEnable,
        requestedCount: requestedSites.length,
        maxAllowed: settings.maxAllowedVendors,
        tier: settings.subscriptionTier,
        recommendedSites: settings.defaultEnabledSites,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error checking vendor limits: $e');
      }
      return VendorValidationResult(
        canEnable: false,
        requestedCount: 0,
        maxAllowed: 0,
        tier: SubscriptionTier.free,
        recommendedSites: SubscriptionTierExtension.freeEnabledSites,
      );
    }
  }

  /// Validate if user can set faster check frequency
  Future<FrequencyValidationResult> canSetCheckFrequency(
    int requestedMinutes,
  ) async {
    try {
      final settings = await SettingsService.instance.getSettings();

      final canSet = settings.canSetCheckFrequency(requestedMinutes);

      return FrequencyValidationResult(
        canSet: canSet,
        requestedMinutes: requestedMinutes,
        minAllowed: settings.minAllowedCheckFrequency,
        tier: settings.subscriptionTier,
      );
    } catch (e) {
      if (kDebugMode) {
        print('Error checking frequency limits: $e');
      }
      return FrequencyValidationResult(
        canSet: false,
        requestedMinutes: requestedMinutes,
        minAllowed: 360, // Default free tier limit
        tier: SubscriptionTier.free,
      );
    }
  }

  /// Check if user can access full analytics history
  Future<bool> canAccessFullHistory() async {
    return await isPremiumUser();
  }

  /// Get history limit days for current tier
  Future<int> getHistoryLimitDays() async {
    final settings = await SettingsService.instance.getSettings();
    return settings.historyLimitDays;
  }

  /// Check if user can use priority notifications
  Future<bool> canUsePriorityNotifications() async {
    return await isPremiumUser();
  }

  /// Update subscription status (called from payment processing)
  Future<void> updateSubscription({
    required SubscriptionTier tier,
    DateTime? expiresAt,
    String? subscriptionId,
    bool? trialUsed,
  }) async {
    try {
      await SettingsService.instance.updateSettings((settings) {
        return settings.copyWith(
          subscriptionTier: tier,
          subscriptionExpiresAt: expiresAt,
          subscriptionId: subscriptionId,
          lastTierCheck: DateTime.now(),
          trialUsed: trialUsed ?? settings.trialUsed,
        );
      });

      if (kDebugMode) {
        print('✅ Subscription updated: $tier (expires: $expiresAt)');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to update subscription: $e');
      }
      rethrow;
    }
  }

  /// Verify subscription status (for periodic checks)
  Future<void> verifySubscriptionStatus() async {
    try {
      final settings = await SettingsService.instance.getSettings();

      // Update last check time
      await SettingsService.instance.updateSettings((settings) {
        return settings.copyWith(lastTierCheck: DateTime.now());
      });

      // Check if subscription expired and downgrade if needed
      if (settings.isSubscriptionExpired &&
          settings.subscriptionTier == SubscriptionTier.premium) {
        await _downgradeToFree();
      }

      if (kDebugMode) {
        print('✅ Subscription status verified: ${settings.subscriptionTier}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to verify subscription status: $e');
      }
    }
  }

  /// Downgrade user to free tier (when subscription expires)
  Future<void> _downgradeToFree() async {
    try {
      await SettingsService.instance.updateSettings((settings) {
        return settings.copyWith(
          subscriptionTier: SubscriptionTier.free,
          subscriptionExpiresAt: null,
          subscriptionId: null,
          // Enforce free tier limits
          checkFrequencyMinutes:
              SubscriptionTierExtension.minCheckFrequencyMinutesForFree,
          enabledSites: SubscriptionTierExtension.freeEnabledSites,
        );
      });

      // For future implementation: Optionally trim favorites to free limit
      // This could be implemented as a user choice rather than automatic
      // to avoid data loss without user consent

      if (kDebugMode) {
        print('📉 User downgraded to free tier due to expired subscription');
        print('💡 Note: Existing favorites beyond free limit are preserved');
      }
    } catch (e) {
      if (kDebugMode) {
        print('❌ Failed to downgrade to free tier: $e');
      }
      rethrow;
    }
  }

  /// Get premium benefits description for upgrade prompts
  List<String> getPremiumBenefits() {
    return [
      'Monitor all ${SubscriptionTierExtension.maxVendorsForPremium}+ matcha vendors',
      'Unlimited favorite products',
      'Hourly check frequency (vs 6 hours)',
      'Full analytics history',
      'Priority notifications',
      'Custom notification rules',
      'Weekly summary reports',
    ];
  }

  /// Get tier comparison for upgrade UI
  TierComparison getTierComparison() {
    return TierComparison(
      free: TierFeatures(
        tier: SubscriptionTier.free,
        maxFavorites: SubscriptionTierExtension.maxFavoritesForFree,
        maxVendors: SubscriptionTierExtension.maxVendorsForFree,
        checkFrequencyHours:
            SubscriptionTierExtension.minCheckFrequencyMinutesForFree ~/ 60,
        historyDays: SubscriptionTierExtension.historyLimitDaysForFree,
        hasCustomNotifications: false,
        hasPriorityNotifications: false,
      ),
      premium: TierFeatures(
        tier: SubscriptionTier.premium,
        maxFavorites: 999, // Effectively unlimited
        maxVendors: 999, // Effectively unlimited
        checkFrequencyHours:
            SubscriptionTierExtension.minCheckFrequencyMinutesForPremium ~/ 60,
        historyDays: 999, // Effectively unlimited
        hasCustomNotifications: true,
        hasPriorityNotifications: true,
      ),
    );
  }
}

/// Result classes for validation operations

class FavoriteValidationResult {
  final bool canAdd;
  final int currentCount;
  final int maxAllowed;
  final SubscriptionTier tier;

  FavoriteValidationResult({
    required this.canAdd,
    required this.currentCount,
    required this.maxAllowed,
    required this.tier,
  });

  String get message {
    if (canAdd) {
      return 'You can add ${maxAllowed - currentCount} more favorites';
    } else {
      return 'You\'ve reached the limit of $maxAllowed favorites for ${tier.displayName} tier';
    }
  }
}

class VendorValidationResult {
  final bool canEnable;
  final int requestedCount;
  final int maxAllowed;
  final SubscriptionTier tier;
  final List<String> recommendedSites;

  VendorValidationResult({
    required this.canEnable,
    required this.requestedCount,
    required this.maxAllowed,
    required this.tier,
    required this.recommendedSites,
  });

  String get message {
    if (canEnable) {
      return 'You can monitor up to $maxAllowed vendors';
    } else {
      return 'You can only monitor $maxAllowed vendors with ${tier.displayName} tier';
    }
  }
}

class FrequencyValidationResult {
  final bool canSet;
  final int requestedMinutes;
  final int minAllowed;
  final SubscriptionTier tier;

  FrequencyValidationResult({
    required this.canSet,
    required this.requestedMinutes,
    required this.minAllowed,
    required this.tier,
  });

  String get message {
    if (canSet) {
      return 'Check frequency set to ${requestedMinutes ~/ 60} hours';
    } else {
      return '${tier.displayName} tier allows minimum ${minAllowed ~/ 60} hour intervals';
    }
  }
}

class TierFeatures {
  final SubscriptionTier tier;
  final int maxFavorites;
  final int maxVendors;
  final int checkFrequencyHours;
  final int historyDays;
  final bool hasCustomNotifications;
  final bool hasPriorityNotifications;

  TierFeatures({
    required this.tier,
    required this.maxFavorites,
    required this.maxVendors,
    required this.checkFrequencyHours,
    required this.historyDays,
    required this.hasCustomNotifications,
    required this.hasPriorityNotifications,
  });
}

class TierComparison {
  final TierFeatures free;
  final TierFeatures premium;

  TierComparison({required this.free, required this.premium});
}
