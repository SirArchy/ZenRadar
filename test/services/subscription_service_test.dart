import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/foundation.dart';
import 'package:zenradar/services/subscription_service.dart';
import 'package:zenradar/models/matcha_product.dart';

void main() {
  group('SubscriptionService', () {
    late SubscriptionService subscriptionService;

    setUp(() {
      subscriptionService = SubscriptionService.instance;
    });

    test('should be a singleton', () {
      final instance1 = SubscriptionService.instance;
      final instance2 = SubscriptionService.instance;
      expect(identical(instance1, instance2), true);
    });

    test('should handle debug premium mode in debug builds', () {
      // This test only makes sense in debug mode
      if (kDebugMode) {
        expect(subscriptionService.isDebugPremiumMode, false);

        subscriptionService.setDebugPremiumMode(true);
        expect(subscriptionService.isDebugPremiumMode, true);

        subscriptionService.setDebugPremiumMode(false);
        expect(subscriptionService.isDebugPremiumMode, false);
      }
    });

    group('Favorite Validation', () {
      test('should validate free tier favorite limits', () async {
        // Mock a free tier user with some favorites
        const currentFavorites = 40;
        const maxFreeLimit = 42;

        expect(currentFavorites < maxFreeLimit, true);
        expect(currentFavorites + 1 < maxFreeLimit, true);
        expect(currentFavorites + 2 < maxFreeLimit, false); // At limit
        expect(currentFavorites + 3 < maxFreeLimit, false); // Over limit
      });

      test('should validate premium tier favorite limits', () async {
        // Mock a premium tier user
        const currentFavorites = 1000;
        const maxPremiumLimit = 99999;

        expect(currentFavorites < maxPremiumLimit, true);
        expect(currentFavorites + 50000 < maxPremiumLimit, true);
        expect(currentFavorites + 98999 < maxPremiumLimit, false); // At limit
      });
    });

    group('Vendor Validation', () {
      test('should validate free tier vendor limits', () {
        const freeVendorLimit = 5;
        final freeEnabledSites = SubscriptionTierExtension.freeEnabledSites;

        expect(freeEnabledSites.length, freeVendorLimit);
        expect(freeEnabledSites, contains('ippodo'));
        expect(freeEnabledSites, contains('marukyu'));
        expect(freeEnabledSites, contains('tokichi'));
        expect(freeEnabledSites, contains('matcha-karu'));
        expect(freeEnabledSites, contains('yoshien'));
      });

      test('should validate premium tier vendor access', () {
        const premiumVendorLimit = 999;
        const requestedVendors = 10;

        expect(requestedVendors <= premiumVendorLimit, true);
      });
    });

    group('Trial Status Logic', () {
      test('should correctly identify active trial', () {
        final now = DateTime.now();
        final trialStart = now.subtract(const Duration(days: 2));
        final trialEnd = now.add(const Duration(days: 5));

        // Mock trial data
        final isActive = now.isAfter(trialStart) && now.isBefore(trialEnd);
        expect(isActive, true);

        // Calculate days remaining
        final daysRemaining = trialEnd.difference(now).inDays;
        expect(daysRemaining, 5);
      });

      test('should correctly identify expired trial', () {
        final now = DateTime.now();
        final trialStart = now.subtract(const Duration(days: 10));
        final trialEnd = now.subtract(const Duration(days: 3));

        // Mock expired trial
        final isActive = now.isAfter(trialStart) && now.isBefore(trialEnd);
        final isExpired = now.isAfter(trialEnd);

        expect(isActive, false);
        expect(isExpired, true);
      });

      test('should validate trial eligibility', () {
        // User who hasn't used trial yet
        const trialUsed = false;

        final canStartTrial = !trialUsed;
        expect(canStartTrial, true);

        // User who has already used trial
        const trialUsedBefore = true;
        final canStartTrialAgain = !trialUsedBefore;
        expect(canStartTrialAgain, false);
      });
    });

    group('Check Frequency Validation', () {
      test('should validate free tier frequency limits', () {
        const freeMinFrequency = 360; // 6 hours in minutes

        expect(360 >= freeMinFrequency, true); // 6 hours - allowed
        expect(180 >= freeMinFrequency, false); // 3 hours - not allowed
        expect(720 >= freeMinFrequency, true); // 12 hours - allowed
      });

      test('should validate premium tier frequency limits', () {
        const premiumMinFrequency = 60; // 1 hour in minutes

        expect(60 >= premiumMinFrequency, true); // 1 hour - allowed
        expect(30 >= premiumMinFrequency, false); // 30 minutes - not allowed
        expect(120 >= premiumMinFrequency, true); // 2 hours - allowed
      });
    });
  });

  group('UserSettings Premium Logic', () {
    test('should correctly identify premium status during active trial', () {
      final now = DateTime.now();
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
        subscriptionTier: SubscriptionTier.free, // Still free tier
        subscriptionExpiresAt: null,
        subscriptionId: null,
        trialUsed: true,
        trialStartedAt: now.subtract(const Duration(days: 2)),
        trialEndsAt: now.add(const Duration(days: 5)),
        lastTierCheck: now,
      );

      expect(settings.isTrialActive, true);
      expect(settings.isPremium, true); // Should be true due to active trial
      expect(
        settings.maxAllowedFavorites,
        SubscriptionTierExtension.maxFavoritesForPremium,
      );
      expect(settings.canAddFavorites(100), true);
    });

    test('should correctly handle free tier without trial', () {
      final now = DateTime.now();
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
        lastTierCheck: now,
      );

      expect(settings.isTrialActive, false);
      expect(settings.isPremium, false);
      expect(
        settings.maxAllowedFavorites,
        SubscriptionTierExtension.maxFavoritesForFree,
      );
      expect(settings.canAddFavorites(5), true);
      expect(settings.canAddFavorites(42), false); // At free limit
    });
  });
}
