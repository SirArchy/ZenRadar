// ignore_for_file: avoid_print

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models/matcha_product.dart';
import '../services/settings_service.dart';
import '../services/background_service.dart';
import '../services/notification_service.dart';
import '../services/payment_service.dart';
import 'auth_screen.dart';
import 'main_screen.dart';

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
                  _buildPremiumUpgradePage(),
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
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
            'Welcome to ZenRadar',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Your premium matcha stock monitoring companion',
            style: Theme.of(context).textTheme.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 40),
          _buildFeature(
            Icons.cloud_sync,
            'Cloud Monitoring',
            'Reliable 24/7 stock tracking',
          ),
          const SizedBox(height: 16),
          _buildFeature(
            Icons.notifications_active,
            'Instant Alerts',
            'Get notified when items are back in stock',
          ),
          const SizedBox(height: 16),
          _buildFeature(
            Icons.battery_saver,
            'Zero Battery Usage',
            'Cloud processing means no device drain',
          ),
        ],
      ),
    );
  }

  Widget _buildServerModeExplanationPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
            'Cloud-Powered Monitoring',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'ZenRadar uses advanced cloud services to monitor matcha stock across multiple websites.',
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
                  'Why Cloud Monitoring?',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 16),
                _buildBenefit('Always online, even when your device sleeps'),
                _buildBenefit('No battery drain on your device'),
                _buildBenefit('Faster updates and better reliability'),
                _buildBenefit('Shared improvements benefit everyone'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumUpgradePage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Premium star icon
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset(
                  'lib/assets/diamond_19001693.gif',
                  fit: BoxFit.cover,
                ),
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Choose Your ZenRadar Experience',
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'ZenRadar offers both free and premium options to track your favorite matcha products',
              style: Theme.of(context).textTheme.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 40),

            // Free vs Premium comparison
            Row(
              children: [
                // Free column
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withAlpha(75),
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.person,
                          size: 32,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Free',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 16),
                        _buildFeatureBullet('3 favorite products'),
                        _buildFeatureBullet('Basic notifications'),
                        _buildFeatureBullet('2 matcha vendors'),
                        _buildFeatureBullet('24h check frequency'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Premium column
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.amber.shade50, Colors.orange.shade50],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.amber.shade300,
                        width: 2,
                      ),
                    ),
                    child: Column(
                      children: [
                        Icon(
                          Icons.star,
                          size: 32,
                          color: Colors.amber.shade700,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Premium',
                          style: Theme.of(
                            context,
                          ).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade700,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _buildFeatureBullet(
                          'Unlimited favorites',
                          isPremium: true,
                        ),
                        _buildFeatureBullet(
                          'Priority notifications',
                          isPremium: true,
                        ),
                        _buildFeatureBullet(
                          'All matcha vendors',
                          isPremium: true,
                        ),
                        _buildFeatureBullet(
                          '1h check frequency',
                          isPremium: true,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 32),

            // Why Premium section
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
                  Icon(
                    Icons.support,
                    color: Theme.of(context).colorScheme.primary,
                    size: 28,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Support ZenRadar Development',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Premium subscriptions help us maintain servers, add new features, and keep ZenRadar running smoothly for everyone.',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Trial option
            FutureBuilder<TrialStatus>(
              future: PaymentService.instance.getTrialStatus(),
              builder: (context, snapshot) {
                final canStartTrial = snapshot.data?.canStart ?? false;

                if (canStartTrial) {
                  return Column(
                    children: [
                      SizedBox(
                        width: double.infinity,
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: _startFreeTrial,
                          icon: const Icon(Icons.play_arrow),
                          label: const Text('Start 7-Day Free Trial'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Full premium features. No credit card required.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.green.shade700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () => _nextPage(),
                        child: const Text('Continue with Free Version'),
                      ),
                    ],
                  );
                }

                return TextButton(
                  onPressed: () => _nextPage(),
                  child: const Text('Continue with Free Version'),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureBullet(String text, {bool isPremium = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            Icons.check_circle,
            size: 16,
            color:
                isPremium
                    ? Colors.amber.shade700
                    : Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isPremium ? Colors.amber.shade800 : null,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationPage() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
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
            'Stay Informed',
            style: Theme.of(
              context,
            ).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          Text(
            'Get instant notifications when your favorite matcha products come back in stock.',
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
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          TextButton(onPressed: _skipOnboarding, child: const Text('Skip')),
          Row(
            children: List.generate(4, (index) {
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
            onPressed: _currentPage == 3 ? _completeOnboarding : _nextPage,
            child: Text(_currentPage == 3 ? 'Get Started' : 'Next'),
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

  Future<void> _startFreeTrial() async {
    try {
      await PaymentService.instance.startFreeTrial();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              '🎉 7-day free trial started! Enjoy premium features!',
            ),
            backgroundColor: Colors.green,
            duration: Duration(seconds: 3),
          ),
        );
        // Continue to next page
        _nextPage();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error starting trial: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
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

        // Continue regardless of auth result
        if (authResult == false && mounted) {
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
