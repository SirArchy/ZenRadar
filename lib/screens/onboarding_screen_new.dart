// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import '../services/settings_service.dart';
import '../services/background_service.dart';
import '../services/notification_service.dart';
import '../services/subscription_service.dart';
import 'auth_screen.dart';
import 'main_screen.dart';
import 'premium_upgrade_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  bool _notificationPermissionAsked = false;
  bool _notificationPermissionGranted = false;
  int _currentPage = 0;
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    // App now runs exclusively in server mode
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: PageView(
                controller: _pageController,
                onPageChanged: (page) => setState(() => _currentPage = page),
                children: [
                  _buildWelcomePage(),
                  _buildServerModeExplanationPage(),
                  _buildNotificationPage(),
                ],
              ),
            ),
            _buildBottomBar(),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomePage() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          // Animated GIF instead of static radar icon
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset('lib/assets/animation.gif', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            l10n.welcomeToZenRadar,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.premiumMatchaMonitoring,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          _buildFeature(
            Icons.cloud_sync,
            l10n.cloudMonitoring,
            l10n.reliable247Tracking,
          ),
          const SizedBox(height: 16),
          _buildFeature(
            Icons.notifications_active,
            l10n.instantAlerts,
            l10n.notifyBackInStock,
          ),
          const SizedBox(height: 16),
          _buildFeature(
            Icons.battery_saver,
            l10n.zeroBatteryUsage,
            l10n.cloudProcessingNoDrain,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildServerModeExplanationPage() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          // Cloud animated GIF for server explanation
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'lib/assets/cloud_17905309.gif',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            l10n.cloudPoweredMonitoring,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.cloudServicesDescription,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withAlpha(75),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  l10n.whyCloudMonitoring,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildBenefit(l10n.alwaysOnline),
                _buildBenefit(l10n.noBatteryDrain),
                _buildBenefit(l10n.fasterUpdates),
                _buildBenefit(l10n.sharedImprovements),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildNotificationPage() {
    final l10n = AppLocalizations.of(context)!;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 32),
          // Notifications animated GIF
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(16),
              child: Image.asset(
                'lib/assets/bell_14642663.gif',
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Text(
            l10n.stayInformed,
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.instantStockNotifications,
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          if (!kIsWeb) ...[
            ElevatedButton.icon(
              onPressed:
                  _notificationPermissionAsked
                      ? null
                      : _requestNotificationPermission,
              icon: Icon(
                _notificationPermissionAsked
                    ? (_notificationPermissionGranted
                        ? Icons.check
                        : Icons.block)
                    : Icons.notifications,
              ),
              label: Text(
                _notificationPermissionAsked
                    ? (_notificationPermissionGranted
                        ? 'Notifications Enabled'
                        : 'Permission Denied')
                    : 'Enable Notifications',
              ),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                backgroundColor:
                    _notificationPermissionAsked
                        ? (_notificationPermissionGranted
                            ? Colors.green
                            : Theme.of(context).colorScheme.error)
                        : null,
              ),
            ),
            const SizedBox(height: 16),
          ],
          Text(
            kIsWeb
                ? 'Web notifications will be enabled automatically.'
                : _notificationPermissionAsked
                ? (_notificationPermissionGranted
                    ? 'Great! You\'ll receive notifications when your favorite matcha is back in stock.'
                    : 'You can enable notifications later in Settings if you change your mind.')
                : 'We recommend enabling notifications for the best experience.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildFeature(IconData icon, String title, String description) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.primaryContainer.withAlpha(100),
            borderRadius: BorderRadius.circular(12),
          ),
          child: SizedBox(
            width: 28,
            height: 28,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                // choose a small GIF based on the requested icon
                icon == Icons.cloud_sync
                    ? 'lib/assets/clouds_17102874.gif'
                    : icon == Icons.notifications_active
                    ? 'lib/assets/bell_14642663.gif'
                    : icon == Icons.battery_saver
                    ? 'lib/assets/evolution_17091777.gif'
                    : 'lib/assets/animation.gif',
                fit: BoxFit.cover,
              ),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              Text(description, style: Theme.of(context).textTheme.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBenefit(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            color: Theme.of(context).colorScheme.primary,
            size: 20,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(onPressed: _skipOnboarding, child: Text(l10n.skip)),
          Row(
            children: List.generate(3, (index) {
              return Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color:
                      _currentPage == index
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.outline,
                ),
              );
            }),
          ),
          ElevatedButton(
            onPressed: _currentPage == 2 ? _completeOnboarding : _nextPage,
            child: Text(_currentPage == 2 ? l10n.getStarted : l10n.next),
          ),
        ],
      ),
    );
  }

  Future<void> _requestNotificationPermission() async {
    if (!kIsWeb) {
      try {
        final granted =
            await NotificationService.instance.requestNotificationPermission();
        setState(() {
          _notificationPermissionAsked = true;
          _notificationPermissionGranted = granted;
        });

        // Show a brief feedback message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                granted
                    ? 'Notifications enabled successfully!'
                    : 'Notification permission denied. You can enable it later in Settings.',
              ),
              backgroundColor: granted ? Colors.green : Colors.orange,
              duration: const Duration(seconds: 3),
            ),
          );
        }
      } catch (e) {
        setState(() {
          _notificationPermissionAsked = true;
          _notificationPermissionGranted = false;
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error requesting notification permission: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  void _nextPage() {
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  void _skipOnboarding() {
    _completeOnboarding();
  }

  Future<void> _completeOnboarding() async {
    try {
      // Show authentication screen for server mode
      if (mounted) {
        final authResult = await Navigator.of(context).push<bool>(
          MaterialPageRoute(
            builder:
                (context) => AuthScreen(
                  isOnboarding: true,
                  onAuthSuccess: () {
                    Navigator.of(context).pop(true);
                  },
                  onSkip: () {
                    Navigator.of(context).pop(false);
                  },
                ),
          ),
        );

        // If user successfully authenticated, show premium upgrade screen only for free users
        if (authResult == true && mounted) {
          // Check if user needs to see upgrade screen (only free users without trial)
          final subscriptionService = SubscriptionService.instance;
          final isPremium = await subscriptionService.isPremiumUser();
          final isTrialActive = await subscriptionService.isTrialActive();

          // Only show upgrade screen to users who are not premium and don't have active trial
          if (!isPremium && !isTrialActive) {
            await Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder:
                    (context) => PremiumUpgradeScreen(
                      onContinue: () {
                        Navigator.of(context).pop();
                      },
                      onUpgrade: () {
                        Navigator.of(context).pop();
                      },
                    ),
              ),
            );
          }
        } else if (authResult == false && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'You can sign in later in settings to sync your data',
              ),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }

      // Save default settings and mark onboarding as completed
      final settings = await SettingsService.instance.getSettings();
      await SettingsService.instance.saveSettings(settings);
      await SettingsService.instance.markOnboardingCompleted();

      // Request notification permission if not already asked during onboarding
      if (!kIsWeb && !_notificationPermissionAsked) {
        await _requestNotificationPermission();
      }

      // Initialize service (no-op for server mode)
      try {
        await initializeService();
        print('✅ Server mode initialized');
      } catch (e) {
        print('❌ Failed to initialize service: $e');
      }

      if (mounted) {
        // Navigate to main screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const MainScreen()),
        );
      }
    } catch (e) {
      print('Error completing onboarding: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Setup error: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
