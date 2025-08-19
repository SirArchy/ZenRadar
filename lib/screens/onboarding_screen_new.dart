import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:onboarding/onboarding.dart';
import 'package:permission_handler/permission_handler.dart';
import '../services/settings_service.dart';
import '../services/background_service.dart';
import '../widgets/matcha_icon.dart';
import 'home_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  String? _selectedMode;
  bool _notificationPermissionAsked = false;
  List<Widget>? _pages;

  @override
  void initState() {
    super.initState();
    // Auto-select server mode for web users
    if (kIsWeb) {
      _selectedMode = 'server';
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Build pages here where Theme.of(context) is available
    _pages ??= _buildOnboardingPages();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    // Ensure pages are built with current theme
    _pages = _buildOnboardingPages(colorScheme);

    return Scaffold(
      body: Onboarding(
        swipeableBody: _pages!,
        startIndex: 0,
        onPageChanges: (
          netDragDistance,
          pagesLength,
          currentIndex,
          slideDirection,
        ) {
          setState(() {
            // Update pages if mode selection changes
            if (currentIndex == 3 && _selectedMode != null) {
              _pages = _buildOnboardingPages(Theme.of(context).colorScheme);
            }
          });
        },
        buildFooter: (
          context,
          netDragDistance,
          pagesLength,
          currentIndex,
          setIndex,
          slideDirection,
        ) {
          final isLastPage = currentIndex == pagesLength - 1;
          final isFirstPage = currentIndex == 0;

          return DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(
                top: BorderSide(
                  color: colorScheme.outline.withAlpha(50),
                  width: 1,
                ),
              ),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24.0,
                  vertical: 16.0,
                ),
                child: Row(
                  children: [
                    // Back/Skip button
                    if (isFirstPage)
                      TextButton(
                        onPressed: _skipOnboarding,
                        child: Text(
                          'Skip',
                          style: TextStyle(
                            color: colorScheme.onSurface.withAlpha(150),
                            fontSize: 16,
                          ),
                        ),
                      )
                    else if (!isLastPage)
                      TextButton(
                        onPressed: () => setIndex(currentIndex - 1),
                        child: Text(
                          'Back',
                          style: TextStyle(
                            color: colorScheme.onSurface.withAlpha(150),
                            fontSize: 16,
                          ),
                        ),
                      )
                    else
                      const SizedBox(width: 60),

                    const Spacer(),

                    // Page indicator using the built-in Indicator
                    SizedBox(
                      width: 80,
                      height: 20,
                      child: Indicator<CirclePainter>(
                        painter: CirclePainter(
                          currentPageIndex: currentIndex,
                          pagesLength: pagesLength,
                          netDragPercent: netDragDistance,
                          activePainter: Paint()..color = colorScheme.primary,
                          inactivePainter:
                              Paint()
                                ..color = colorScheme.outline.withAlpha(75),
                          slideDirection: slideDirection,
                          radius: 4,
                        ),
                      ),
                    ),

                    const Spacer(),

                    // Next/Continue button
                    ElevatedButton(
                      onPressed:
                          isLastPage
                              ? _completeOnboarding
                              : () => _nextPage(
                                setIndex,
                                currentIndex,
                                pagesLength,
                              ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: colorScheme.primary,
                        foregroundColor: colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                        ),
                      ),
                      child: Text(
                        _getButtonText(currentIndex, pagesLength),
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildOnboardingPages([ColorScheme? colorScheme]) {
    colorScheme ??= Theme.of(context).colorScheme;

    List<Widget> pages = [
      // 1. Introduction Screen
      _buildIntroductionPage(colorScheme),

      // 2. App Description
      _buildAppDescriptionPage(colorScheme),

      // 3. Mode Selection Page
      _buildModeSelectionPage(colorScheme),

      // 4. Mode-specific explanations and permissions
      if (_selectedMode != null) ..._getModeSpecificPages(colorScheme),

      // 5. Features Overview
      _buildFeaturesOverviewPage(colorScheme),

      // 6. Final congratulations page
      _buildFinalPage(colorScheme),
    ];

    return pages;
  }

  Widget _buildIntroductionPage(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // App Logo with animation placeholder
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 1500),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 0.8 + (0.2 * value),
                    child: Opacity(
                      opacity: value,
                      child: const MatchaIcon(size: 120),
                    ),
                  );
                },
              ),

              const SizedBox(height: 48),

              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 2000),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Opacity(
                    opacity: value,
                    child: Column(
                      children: [
                        const Text(
                          'Welcome to ZenRadar',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Your zen companion for matcha monitoring',
                          style: TextStyle(
                            fontSize: 18,
                            height: 1.5,
                            color: colorScheme.onSurface.withAlpha(200),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                },
              ),

              const Spacer(flex: 2),

              Text(
                'Let\'s get you started on your matcha journey',
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppDescriptionPage(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Animated icon
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 1500),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 0.8 + (0.2 * value),
                    child: _buildFeatureIcon(
                      Icons.notifications_active,
                      colorScheme.primary,
                    ),
                  );
                },
              ),

              const SizedBox(height: 48),

              const Text(
                'Never Miss a Restock Again',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              Text(
                'ZenRadar monitors premium matcha websites and instantly notifies you when your favorite products come back in stock.',
                style: TextStyle(
                  fontSize: 18,
                  height: 1.5,
                  color: colorScheme.onSurface.withAlpha(200),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Benefits list
              _buildBenefitsList(colorScheme, [
                'Real-time stock monitoring',
                'Price tracking & history',
                'Instant push notifications',
                'Multiple tea shop support',
                'Favorites & wishlist management',
              ]),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBenefitsList(ColorScheme colorScheme, List<String> benefits) {
    return Column(
      children:
          benefits.asMap().entries.map((entry) {
            return TweenAnimationBuilder<double>(
              duration: Duration(milliseconds: 800 + (entry.key * 200)),
              tween: Tween(begin: 0.0, end: 1.0),
              builder: (context, value, child) {
                return Transform.translate(
                  offset: Offset(50 * (1 - value), 0),
                  child: Opacity(
                    opacity: value,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Row(
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 20,
                            color: Colors.green,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              entry.value,
                              style: TextStyle(
                                fontSize: 16,
                                color: colorScheme.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          }).toList(),
    );
  }

  Widget _buildModeSelectionPage(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              const Spacer(),
              const Text(
                'Choose Your Experience',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Select how you want ZenRadar to monitor matcha stock for you',
                style: TextStyle(
                  fontSize: 18,
                  color: colorScheme.onSurface.withAlpha(200),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),

              // Local Mode Card (only on mobile)
              if (!kIsWeb) ...[
                _buildModeCard(
                  mode: 'local',
                  icon: Icons.smartphone,
                  title: 'Local Mode',
                  subtitle: 'Privacy-first, device-based monitoring',
                  features: [
                    '✅ Complete privacy & offline support',
                    '✅ Full control over all settings',
                    '✅ No data sent to external servers',
                    '✅ Works without internet (cached data)',
                  ],
                  tradeoffs: [
                    '⚠️ Uses device battery for monitoring',
                    '⚠️ Limited by device resources',
                    '⚠️ May be affected by device sleep modes',
                  ],
                  colorScheme: colorScheme,
                ),
                const SizedBox(height: 24),
              ],

              // Server Mode Card
              _buildModeCard(
                mode: 'server',
                icon: Icons.cloud,
                title: 'Cloud Mode',
                subtitle: 'Reliable, always-on monitoring',
                features: [
                  '✅ Zero battery usage on your device',
                  '✅ Always-on, 24/7 reliable monitoring',
                  '✅ Fast updates & shared improvements',
                  '✅ Never misses restocks due to device sleep',
                ],
                tradeoffs: [
                  '⚠️ Requires internet connection',
                  '⚠️ Data stored in secure cloud',
                  '⚠️ Dependent on server availability',
                ],
                colorScheme: colorScheme,
              ),

              if (kIsWeb) ...[
                const SizedBox(height: 24),
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withAlpha(75),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colorScheme.primary.withAlpha(75),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info, color: colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Web version automatically uses Cloud Mode for optimal performance.',
                          style: TextStyle(
                            color: colorScheme.onSurface,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModeCard({
    required String mode,
    required IconData icon,
    required String title,
    required String subtitle,
    required List<String> features,
    required List<String> tradeoffs,
    required ColorScheme colorScheme,
  }) {
    final isSelected = _selectedMode == mode;
    final canSelect = !kIsWeb || mode == 'server';

    return GestureDetector(
      onTap:
          canSelect
              ? () {
                setState(() {
                  _selectedMode = mode;
                  // Rebuild pages when mode changes
                  _pages = _buildOnboardingPages();
                });
              }
              : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? colorScheme.primaryContainer.withAlpha(75)
                  : colorScheme.surface,
          border: Border.all(
            color:
                isSelected
                    ? colorScheme.primary
                    : colorScheme.outline.withAlpha(75),
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: colorScheme.primary.withAlpha(25),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ]
                  : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? colorScheme.primary
                            : colorScheme.outline.withAlpha(25),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    icon,
                    color:
                        isSelected
                            ? colorScheme.onPrimary
                            : colorScheme.onSurface,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color:
                              isSelected
                                  ? colorScheme.primary
                                  : colorScheme.onSurface,
                        ),
                      ),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurface.withAlpha(175),
                        ),
                      ),
                    ],
                  ),
                ),
                if (canSelect)
                  Radio<String>(
                    value: mode,
                    groupValue: _selectedMode,
                    onChanged: (value) {
                      setState(() {
                        _selectedMode = value;
                        _pages = _buildOnboardingPages();
                      });
                    },
                    activeColor: colorScheme.primary,
                  ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(height: 16),
              ...features.map(
                (feature) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    feature,
                    style: TextStyle(
                      fontSize: 13,
                      color: colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              ...tradeoffs.map(
                (tradeoff) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    tradeoff,
                    style: TextStyle(
                      fontSize: 12,
                      color: colorScheme.onSurface.withAlpha(150),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _getModeSpecificPages(ColorScheme colorScheme) {
    if (_selectedMode == 'server') {
      return [_buildServerModeExplanationPage(colorScheme)];
    } else {
      return [_buildLocalModeExplanationPage(colorScheme)];
    }
  }

  Widget _buildServerModeExplanationPage(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              _buildFeatureIcon(Icons.cloud_sync, colorScheme.primary),

              const SizedBox(height: 48),

              const Text(
                'Cloud-Powered Monitoring',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              Text(
                'Our dedicated servers monitor matcha websites 24/7, so your device doesn\'t have to. Get instant notifications the moment products restock.',
                style: TextStyle(
                  fontSize: 18,
                  height: 1.5,
                  color: colorScheme.onSurface.withAlpha(200),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              if (!kIsWeb && !_notificationPermissionAsked) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withAlpha(50),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.primary.withAlpha(100),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        size: 48,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Enable Notifications',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Allow ZenRadar to send you instant notifications when your favorite matcha products come back in stock.',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurface.withAlpha(200),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _requestNotificationPermission,
                        icon: const Icon(Icons.notifications),
                        label: const Text('Allow Notifications'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLocalModeExplanationPage(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              _buildFeatureIcon(Icons.security, Colors.green),

              const SizedBox(height: 48),

              const Text(
                'Private & Secure',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              Text(
                'All monitoring happens directly on your device. Your data never leaves your phone, ensuring complete privacy and full control over your matcha tracking.',
                style: TextStyle(
                  fontSize: 18,
                  height: 1.5,
                  color: colorScheme.onSurface.withAlpha(200),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              if (!kIsWeb && !_notificationPermissionAsked) ...[
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withAlpha(50),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: colorScheme.primary.withAlpha(100),
                    ),
                  ),
                  child: Column(
                    children: [
                      Icon(
                        Icons.notifications_active,
                        size: 48,
                        color: colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Enable Local Notifications',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Allow ZenRadar to send you local notifications. These are created directly on your device and require no internet connection.',
                        style: TextStyle(
                          fontSize: 14,
                          color: colorScheme.onSurface.withAlpha(200),
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        onPressed: _requestNotificationPermission,
                        icon: const Icon(Icons.notifications),
                        label: const Text('Allow Notifications'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colorScheme.primary,
                          foregroundColor: colorScheme.onPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturesOverviewPage(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              const Text(
                'Explore ZenRadar',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              Text(
                'Here\'s what you can do with ZenRadar',
                style: TextStyle(
                  fontSize: 18,
                  color: colorScheme.onSurface.withAlpha(200),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 48),

              // Feature cards
              _buildFeatureCard(
                icon: Icons.dashboard,
                title: 'Website Overview',
                description:
                    'Monitor multiple tea shops at once. See which websites have new stock and track availability across all your favorite stores.',
                colorScheme: colorScheme,
              ),

              const SizedBox(height: 24),

              _buildFeatureCard(
                icon: Icons.update,
                title: 'Stock Updates',
                description:
                    'Get detailed notifications about stock changes. View history, track price changes, and never miss a restock again.',
                colorScheme: colorScheme,
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String description,
    required ColorScheme colorScheme,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outline.withAlpha(50)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 24, color: colorScheme.primary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 14,
                    color: colorScheme.onSurface.withAlpha(175),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinalPage(ColorScheme colorScheme) {
    return Container(
      color: colorScheme.surface,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Celebration animation
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 2000),
                tween: Tween(begin: 0.0, end: 1.0),
                builder: (context, value, child) {
                  return Transform.scale(
                    scale: 0.5 + (0.5 * value),
                    child: Transform.rotate(
                      angle: value * 2 * 3.14159,
                      child: _buildFeatureIcon(
                        Icons.celebration,
                        Colors.orange,
                      ),
                    ),
                  );
                },
              ),

              const SizedBox(height: 48),

              const Text(
                'You\'re All Set!',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 24),

              Text(
                _selectedMode == 'server'
                    ? 'Cloud monitoring is now active. Enjoy reliable, battery-friendly matcha tracking!'
                    : 'Local monitoring is configured. Your device will handle all tracking privately.',
                style: TextStyle(
                  fontSize: 18,
                  height: 1.5,
                  color: colorScheme.onSurface.withAlpha(200),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: colorScheme.primaryContainer.withAlpha(50),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '🍵 Enjoy your zen matcha journey with ZenRadar! May your cup always be full and your favorite matcha always in stock.',
                  style: TextStyle(
                    fontSize: 16,
                    color: colorScheme.primary,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const Spacer(flex: 3),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeatureIcon(IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 80, color: color),
    );
  }

  String _getButtonText(int currentIndex, int pagesLength) {
    if (currentIndex == 0) {
      return 'Start Journey';
    } else if (currentIndex == 2) {
      // Mode selection page
      return _selectedMode != null ? 'Continue' : 'Choose Mode';
    } else if (currentIndex == pagesLength - 1) {
      return 'Enter ZenRadar';
    } else {
      return 'Next';
    }
  }

  void _nextPage(Function(int) setIndex, int currentIndex, int pagesLength) {
    if (currentIndex == 2 && _selectedMode == null) {
      // On mode selection page but no mode selected
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please select a mode to continue'),
          backgroundColor: Colors.orange,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      );
      return;
    }

    if (currentIndex < pagesLength - 1) {
      setIndex(currentIndex + 1);
    }
  }

  Future<void> _requestNotificationPermission() async {
    if (kIsWeb) return;

    try {
      final result = await Permission.notification.request();
      setState(() {
        _notificationPermissionAsked = true;
      });

      if (result.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                '✅ Notifications enabled! You\'ll receive stock alerts.',
              ),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                '⚠️ Notifications disabled. You can enable them later in settings.',
              ),
              backgroundColor: Colors.orange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          );
        }
      }
    } catch (e) {
      setState(() {
        _notificationPermissionAsked = true;
      });
    }
  }

  Future<void> _skipOnboarding() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Skip Onboarding?'),
            content: const Text(
              'Are you sure you want to skip the setup? You can always access these settings later.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Skip'),
              ),
            ],
          ),
    );

    if (confirmed == true) {
      // Set default mode and complete onboarding
      _selectedMode = kIsWeb ? 'server' : 'local';
      await _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    _selectedMode ??= kIsWeb ? 'server' : 'local';

    try {
      // Save the selected mode to settings
      final settings = await SettingsService.instance.getSettings();
      final updatedSettings = settings.copyWith(appMode: _selectedMode);
      await SettingsService.instance.saveSettings(updatedSettings);

      // For local mode on mobile, ensure notification permissions and background service
      if (!kIsWeb && _selectedMode == 'local') {
        // Request notification permission if not already asked
        if (!_notificationPermissionAsked) {
          await _requestNotificationPermission();
        }

        // Initialize background service for local mode
        try {
          await initializeService();
          print('✅ Background service initialized for local mode');
        } catch (e) {
          print('❌ Failed to initialize background service: $e');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Warning: Background monitoring may not work properly',
                ),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }

      if (mounted) {
        // Navigate to home screen
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to save settings: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
