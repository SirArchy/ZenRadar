// ignore_for_file: avoid_print, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'home_screen_content.dart';
import 'website_overview_screen.dart';
import 'background_activity_screen.dart';
import 'settings_screen.dart';
import '../services/settings_service.dart';
import '../services/database_service.dart';
import '../widgets/site_selection_dialog.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> with TickerProviderStateMixin {
  late TabController _tabController;
  int _currentIndex = 0;
  String _appMode = 'local'; // Default to local mode

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      setState(() {
        _currentIndex = _tabController.index;
      });
    });
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final settings = await SettingsService.instance.getSettings();
      setState(() {
        _appMode = settings.appMode;
      });
    } catch (e) {
      print('Error loading settings: $e');
    }
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
      floatingActionButton: _buildFloatingActionButton(),
    );
  }

  Widget? _buildFloatingActionButton() {
    // Only show FAB in local mode for home tab
    if (_appMode != 'local' || _currentIndex != 0) {
      return null;
    }

    return FloatingActionButton(
      onPressed: _showManualScanDialog,
      tooltip: 'Start Manual Scan',
      child: const Icon(Icons.refresh),
    );
  }

  void _showManualScanDialog() async {
    try {
      // Load available sites for the dialog
      final sites = await DatabaseService.platformService.getAvailableSites();

      final selectedSites = await showSiteSelectionDialog(
        context: context,
        availableSites: sites,
      );

      if (selectedSites != null && selectedSites.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Starting manual scan for ${selectedSites.length} sites...',
            ),
            duration: const Duration(seconds: 3),
          ),
        );

        // TODO: Trigger actual manual scan functionality
        // This would typically call a service method to start the scan
      }
    } catch (e) {
      print('Error showing site selection dialog: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Error loading sites for scan'),
          backgroundColor: Colors.red,
        ),
      );
    }
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
