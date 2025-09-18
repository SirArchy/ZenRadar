// Test to verify free trial users get premium favorite limits

import 'package:flutter_test/flutter_test.dart';
import 'package:zenradar/models/matcha_product.dart';

void main() {
  group('Free Trial Favorite Limits', () {
    test('Free user without trial should have free limits', () {
      final settings = UserSettings(
        checkFrequencyMinutes: 360,
        startTime: "08:00",
        endTime: "20:00",
        notificationsEnabled: true,
        favoriteProductNotifications: true,
        notifyStockChanges: true,
        notifyPriceChanges: true,
        enabledSites: ['ippodo', 'marukyu'],
        itemsPerPage: 20,
        maxStorageMB: 500,
        sortBy: "name",
        sortAscending: true,
        preferredCurrency: "EUR",
        backgroundScanFavoritesOnly: false,
        hasCompletedOnboarding: true,
        hasSeenHomeScreenTutorial: true,
        fcmToken: null,
        subscriptionTier: SubscriptionTier.free,
        subscriptionExpiresAt: null,
        subscriptionId: null,
        trialUsed: false,
        trialStartedAt: null,
        trialEndsAt: null,
        lastTierCheck: DateTime.now(),
      );

      expect(settings.isPremium, false);
      expect(
        settings.maxAllowedFavorites,
        SubscriptionTierExtension.maxFavoritesForFree,
      );
      expect(settings.canAddFavorites(5), true);
      expect(settings.canAddFavorites(42), false); // At free limit
    });

    test('Free user with active trial should have premium limits', () {
      final now = DateTime.now();
      final trialEnd = now.add(Duration(days: 5)); // 5 days remaining

      final settings = UserSettings(
        checkFrequencyMinutes: 360,
        startTime: "08:00",
        endTime: "20:00",
        notificationsEnabled: true,
        favoriteProductNotifications: true,
        notifyStockChanges: true,
        notifyPriceChanges: true,
        enabledSites: ['ippodo', 'marukyu'],
        itemsPerPage: 20,
        maxStorageMB: 500,
        sortBy: "name",
        sortAscending: true,
        preferredCurrency: "EUR",
        backgroundScanFavoritesOnly: false,
        hasCompletedOnboarding: true,
        hasSeenHomeScreenTutorial: true,
        fcmToken: null,
        subscriptionTier: SubscriptionTier.free, // Still free tier during trial
        subscriptionExpiresAt: null,
        subscriptionId: null,
        trialUsed: true,
        trialStartedAt: now.subtract(Duration(days: 2)), // Started 2 days ago
        trialEndsAt: trialEnd,
        lastTierCheck: DateTime.now(),
      );

      expect(settings.isTrialActive, true);
      expect(settings.isPremium, true); // Should be true due to active trial
      expect(
        settings.maxAllowedFavorites,
        SubscriptionTierExtension.maxFavoritesForPremium,
      );
      expect(
        settings.canAddFavorites(100),
        true,
      ); // Should allow many more favorites
      expect(settings.canAddFavorites(99999), false); // At premium limit
    });

    test('Free user with expired trial should revert to free limits', () {
      final now = DateTime.now();
      final expiredTrialEnd = now.subtract(
        Duration(days: 1),
      ); // Expired yesterday

      final settings = UserSettings(
        checkFrequencyMinutes: 360,
        startTime: "08:00",
        endTime: "20:00",
        notificationsEnabled: true,
        favoriteProductNotifications: true,
        notifyStockChanges: true,
        notifyPriceChanges: true,
        enabledSites: ['ippodo', 'marukyu'],
        itemsPerPage: 20,
        maxStorageMB: 500,
        sortBy: "name",
        sortAscending: true,
        preferredCurrency: "EUR",
        backgroundScanFavoritesOnly: false,
        hasCompletedOnboarding: true,
        hasSeenHomeScreenTutorial: true,
        fcmToken: null,
        subscriptionTier: SubscriptionTier.free,
        subscriptionExpiresAt: null,
        subscriptionId: null,
        trialUsed: true,
        trialStartedAt: now.subtract(Duration(days: 8)), // Started 8 days ago
        trialEndsAt: expiredTrialEnd,
        lastTierCheck: DateTime.now(),
      );

      expect(settings.isTrialActive, false);
      expect(settings.isTrialExpired, true);
      expect(settings.isPremium, false); // Should be false due to expired trial
      expect(
        settings.maxAllowedFavorites,
        SubscriptionTierExtension.maxFavoritesForFree,
      );
      expect(settings.canAddFavorites(5), true);
      expect(settings.canAddFavorites(42), false); // Back to free limit
    });
  });
}
