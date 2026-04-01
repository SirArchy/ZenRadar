// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:zenradar/presentation/screens/home/home_screen_content.dart';
import 'package:zenradar/presentation/screens/analytics/website_overview_screen.dart';
import 'package:zenradar/presentation/screens/analytics/recent_scans.dart';
import 'package:zenradar/presentation/screens/settings/settings_screen.dart';
import 'package:zenradar/data/services/cache/preload_service.dart';
import 'package:zenradar/data/services/auth/auth_service.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;
  // App now runs exclusively in server mode - no mode tracking needed

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentIndex = _tabController.index;
      });
    });

    // Start background data preloading now that user is authenticated
    _initializePreloadService();
  }

  /// Initialize the preload service after user authentication is confirmed
  void _initializePreloadService() {
    // Verify authentication state before starting preload
    final authService = AuthService.instance;
    if (!authService.isSignedIn || authService.currentUser == null) {
      return;
    }

    // Add a small delay to ensure all services are fully initialized
    Future.delayed(const Duration(milliseconds: 500), () {
      // Double-check authentication is still valid before proceeding
      if (authService.isSignedIn && authService.currentUser != null) {
        PreloadService.instance.startBackgroundPreload().catchError((error) {});
      } else {}
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      body: Column(
        children: [
          // Custom header with tabs only - removed settings button
          Container(
            color: Theme.of(context).colorScheme.inversePrimary,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Tab bar only - removed title and settings button
                  TabBar(
                    controller: _tabController,
                    indicatorColor: Theme.of(context).colorScheme.primary,
                    labelColor: Theme.of(context).colorScheme.primary,
                    unselectedLabelColor: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha(150),
                    tabs: [
                      Tab(icon: const Icon(Icons.home), text: l10n.home),
                      Tab(
                        icon: const Icon(Icons.web),
                        text: l10n.websiteOverview,
                      ),
                      Tab(
                        icon: const Icon(Icons.history),
                        text: l10n.scanActivity,
                      ),
                      Tab(
                        icon: const Icon(Icons.settings),
                        text: l10n.settings,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: const [
                HomeScreenContent(),
                WebsiteOverviewScreen(),
                BackgroundActivityScreen(),
                SettingsScreen(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton:
          _currentIndex ==
                  0 // Only show FAB on home screen
              ? FloatingActionButton(
                onPressed: () {
                  // Trigger refresh for home screen only
                  HomeScreenContent.refreshIfActive();
                },
                tooltip: AppLocalizations.of(context)!.refresh,
                child: const Icon(Icons.refresh),
              )
              : null,
    );
  }
}
