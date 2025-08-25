// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'home_screen_content.dart';
import 'website_overview_screen.dart';
import 'background_activity_screen.dart';
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
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentIndex = _tabController.index;
      });
    });
    // No need to load app mode settings since server mode is always active
  }

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
          // Custom header with tabs and settings
          Container(
            color: Theme.of(context).colorScheme.inversePrimary,
            child: SafeArea(
              bottom: false,
              child: Column(
                children: [
                  // Header with title and settings
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _getAppBarTitle(),
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.settings),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const SettingsScreen(),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  // Tab bar
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
              ],
            ),
          ),
        ],
      ),
      floatingActionButton:
          _currentIndex == 0
              ? FloatingActionButton(
                onPressed: () {
                  // Trigger refresh on the HomeScreenContent widget
                  HomeScreenContent.refreshIfActive();
                },
                tooltip: 'Refresh products',
                child: const Icon(Icons.refresh),
              )
              : null,
      // No FAB needed in server mode - all monitoring is handled by cloud services
    );
  }

  String _getAppBarTitle() {
    switch (_currentIndex) {
      case 0:
        return 'ZenRadar';
      case 1:
        return 'Website Overview';
      case 2:
        return 'Background Activity';
      default:
        return 'ZenRadar';
    }
  }
}
