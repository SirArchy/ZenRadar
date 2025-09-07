// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'home_screen_content.dart';
import 'website_overview_screen.dart';
import 'recent_scans.dart';
import 'settings_screen.dart';

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
    // _initializePreloadService(); // Temporarily disabled to prevent permission errors
  }

  /// Initialize the preload service after user authentication is confirmed
  // Temporarily disabled to prevent permission errors
  /*
  void _initializePreloadService() {
    // Add a small delay to ensure authentication state is fully established
    Future.delayed(const Duration(milliseconds: 500), () {
      // Start preloading in background without blocking UI
      PreloadService.instance.startBackgroundPreload().catchError((error) {
        print('Preload service initialization failed: $error');
      });
    });
  }
  */

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
                    tabs: const [
                      Tab(icon: Icon(Icons.home), text: 'Home'),
                      Tab(icon: Icon(Icons.web), text: 'Websites'),
                      Tab(icon: Icon(Icons.history), text: 'Activity'),
                      Tab(icon: Icon(Icons.settings), text: 'Settings'),
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
                tooltip: 'Refresh',
                child: const Icon(Icons.refresh),
              )
              : null,
    );
  }
}
