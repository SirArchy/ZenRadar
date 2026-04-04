// ignore_for_file: unused_element, use_build_context_synchronously, empty_catches

import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:zenradar/models/scan_activity.dart';
import 'package:zenradar/data/services/data/database_service.dart';
import 'package:zenradar/data/services/data/firestore_service.dart';
import 'package:zenradar/data/services/cache/cache_service.dart';
import 'package:zenradar/data/services/cache/preload_service.dart';
import 'package:zenradar/data/services/subscription/subscription_service.dart';
import 'package:zenradar/presentation/widgets/common/skeleton_loading.dart';
import 'package:zenradar/presentation/screens/updates/stock_updates_screen.dart';
// ignore_for_file: avoid_print

class BackgroundActivityScreen extends StatefulWidget {
  const BackgroundActivityScreen({super.key});

  @override
  State<BackgroundActivityScreen> createState() =>
      _BackgroundActivityScreenState();
}

class _BackgroundActivityScreenState extends State<BackgroundActivityScreen> {
  List<ScanActivity> _activities = [];
  bool _isLoading = true;
  int _totalActivities = 0;
  int _weeklyCount = 0; // Actual weekly count from database
  final ScrollController _scrollController = ScrollController();
  bool _hasMoreData = true;
  final bool _isLoadingMore = false;
  bool _isPremium = false;

  // Filter state
  bool _showOnlyWithUpdates = false;
  String _sortBy = 'timestamp'; // 'timestamp', 'updates', 'site'
  bool _sortAscending = false;
  bool _showFilters = false;

  // Public method to refresh activities (can be called from parent)
  void refreshActivities() {
    _loadActivities();
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _scrollController.addListener(_onScroll);
  }

  Future<void> _loadSettings() async {
    try {
      // Load subscription status
      _isPremium = await SubscriptionService.instance.isPremiumUser();
      setState(() {});
      await _loadActivities();
    } catch (e) {
      await _loadActivities();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !_isLoadingMore &&
        _hasMoreData) {
      _loadMoreActivities();
    }
  }

  Future<void> _loadActivities() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Trigger background preloading on first access (if not already started)
      if (!PreloadService.instance.hasCompletedInitialPreload) {
        PreloadService.instance.startBackgroundPreload().catchError((error) {});
      }

      List<ScanActivity> activities = [];

      // First, try to get cached activities from preload service
      if (PreloadService.instance.hasCompletedInitialPreload) {
        final cachedActivities =
            await PreloadService.instance.getCachedRecentActivities();
        if (cachedActivities != null && cachedActivities.isNotEmpty) {
          activities = cachedActivities;
        }
      }

      // If no cached activities, load from Firestore
      if (activities.isEmpty) {
        final isPremium = await SubscriptionService.instance.isPremiumUser();
        activities = await _loadServerActivitiesFromFirestore(
          forceRefresh: false,
        );

        // Apply free mode limitation if needed
        if (!isPremium && activities.length > 24) {
          activities = activities.take(24).toList();
        }
      } else {
        // Apply free mode limitation to cached data too
        final isPremium = await SubscriptionService.instance.isPremiumUser();
        if (!isPremium && activities.length > 24) {
          activities = activities.take(24).toList();
        }
      }

      // Load actual weekly count from database
      await _loadWeeklyCount();

      setState(() {
        _activities = activities;
        _totalActivities = activities.length;
        _hasMoreData = false; // No pagination for server mode yet
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _activities = [];
        _totalActivities = 0;
        _hasMoreData = false;
        _isLoading = false;
      });

      // Show error message to user
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.failedToLoadActivitiesWithError('$e')),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: l10n.retry,
              onPressed: () => _forceRefreshActivities(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _forceRefreshActivities() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Clear cache and force refresh from server
      await CacheService.clearCache('server_activities');
      await CacheService.clearCache('recent_activities_preload');

      // Also refresh preload service cache
      await PreloadService.instance.refreshPreloadedData();

      final serverActivities = await _loadServerActivitiesFromFirestore(
        forceRefresh: true,
      );

      // Apply free mode limitation - only last 24 scans
      final isPremium = await SubscriptionService.instance.isPremiumUser();
      final limitedActivities =
          isPremium ? serverActivities : serverActivities.take(24).toList();

      // Load actual weekly count from database
      await _loadWeeklyCount();

      setState(() {
        _activities = limitedActivities;
        _totalActivities = limitedActivities.length;
        _hasMoreData = false;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _activities = [];
        _totalActivities = 0;
        _hasMoreData = false;
        _isLoading = false;
      });

      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.failedToRefreshActivitiesWithError('$e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadMoreActivities() async {
    if (_isLoadingMore || true) {
      return; // No pagination for server mode placeholder
    }
  }

  Future<void> _clearOldActivities() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.clearOld),
            content: Text(l10n.clearOldActivitiesConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.clearOld),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await DatabaseService.platformService.clearOldScanActivities();
        _loadActivities(); // Reload the list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.oldActivitiesClearedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.errorClearingActivitiesWithError('$e')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _clearAllActivities() async {
    final l10n = AppLocalizations.of(context)!;
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Text(l10n.clearAll),
            content: Text(l10n.clearAllActivitiesConfirm),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: Text(l10n.deleteAll),
              ),
            ],
          ),
    );

    if (confirm == true) {
      try {
        await DatabaseService.platformService.clearAllScanActivities();
        _loadActivities(); // Reload the list
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.allActivitiesClearedSuccessfully),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.errorClearingActivitiesWithError('$e')),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _forceRefreshActivities,
        tooltip: AppLocalizations.of(context)!.refreshActivities,
        child: const Icon(Icons.refresh),
      ),
      body:
          _isLoading
              ? Column(
                children: [
                  const SkeletonStatsHeader(),
                  Expanded(
                    child: ListView.builder(
                      itemCount: 5,
                      itemBuilder:
                          (context, index) => const SkeletonActivityItem(),
                    ),
                  ),
                ],
              )
              : _buildActivityList(),
    );
  }

  Widget _buildActivityList() {
    if (_activities.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(
              AppLocalizations.of(context)!.noServerScansFound,
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              AppLocalizations.of(context)!.serverScanActivitiesAppearHere,
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            if (true) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadActivities,
                child: Text(AppLocalizations.of(context)!.refresh),
              ),
            ],
          ],
        ),
      );
    }

    return Column(
      children: [
        // Statistics header
        _buildStatsHeader(),

        // Filter section
        _buildFilterSection(),

        // Activities list
        Expanded(
          child: RefreshIndicator(
            onRefresh: _forceRefreshActivities,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount:
                  _getFilteredAndSortedActivities().length +
                  (_hasMoreData ? 1 : 0),
              itemBuilder: (context, index) {
                final filteredActivities = _getFilteredAndSortedActivities();
                if (index == filteredActivities.length) {
                  // Loading indicator at the bottom
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final activity = filteredActivities[index];
                return _buildActivityCard(activity);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsHeader() {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Statistics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                l10n.totalScans,
                _totalActivities.toString(),
                Icons.history,
              ),
              _buildStatItem(
                l10n.weeklyScans,
                _getWeeklyCount().toString(),
                Icons.calendar_today,
              ),
              _buildStatItem(
                l10n.withUpdates,
                _getUpdatesCount().toString(),
                Icons.notifications_active,
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Free mode notice - only show for non-premium users
          if (!_isPremium)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                AppLocalizations.of(context)!.freeModeShowingLast24Scans,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onPrimaryContainer,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterSection() {
    final screenWidth = MediaQuery.of(context).size.width;
    final isSmallScreen = screenWidth < 400;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(50),
        ),
      ),
      child: Column(
        children: [
          // Filter toggle button
          InkWell(
            onTap: () {
              setState(() {
                _showFilters = !_showFilters;
              });
            },
            borderRadius: BorderRadius.circular(8),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Icon(
                    Icons.tune_rounded,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      AppLocalizations.of(context)!.filterAndSortOptions,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).colorScheme.onSurface,
                      ),
                    ),
                  ),
                  Icon(
                    _showFilters ? Icons.expand_less : Icons.expand_more,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                ],
              ),
            ),
          ),

          // Collapsible filter content
          if (_showFilters) ...[
            const SizedBox(height: 16),

            // Updates Filter Section
            _buildUpdatesFilterChips(isSmallScreen),

            const SizedBox(height: 20),

            // Sorting Section
            _buildSortingChips(isSmallScreen),
          ],
        ],
      ),
    );
  }

  Widget _buildUpdatesFilterChips(bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.update_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(175),
              ),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context)!.filterByUpdates,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(175),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildEnhancedFilterChip(
                  label: AppLocalizations.of(context)!.allScans,
                  icon: Icons.scanner_rounded,
                  isSelected: !_showOnlyWithUpdates,
                  selectedColor: Colors.blue,
                  onSelected: (_) {
                    setState(() {
                      _showOnlyWithUpdates = false;
                    });
                  },
                  isSmallScreen: isSmallScreen,
                ),
                const SizedBox(width: 10),
                _buildEnhancedFilterChip(
                  label: AppLocalizations.of(context)!.withUpdatesOnly,
                  icon: Icons.notifications_active_rounded,
                  isSelected: _showOnlyWithUpdates,
                  selectedColor: Colors.orange,
                  onSelected: (_) {
                    setState(() {
                      _showOnlyWithUpdates = true;
                    });
                  },
                  isSmallScreen: isSmallScreen,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSortingChips(bool isSmallScreen) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.sort_rounded,
                size: 16,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(175),
              ),
              const SizedBox(width: 6),
              Text(
                AppLocalizations.of(context)!.sortOptions,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(175),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildEnhancedSortChip(
                  AppLocalizations.of(context)!.timeLabel,
                  'timestamp',
                  Icons.access_time_rounded,
                  isSmallScreen,
                ),
                const SizedBox(width: 10),
                _buildEnhancedSortChip(
                  AppLocalizations.of(context)!.updatesLabel,
                  'updates',
                  Icons.update_rounded,
                  isSmallScreen,
                ),
                const SizedBox(width: 10),
                _buildEnhancedSortChip(
                  AppLocalizations.of(context)!.sitesLabel,
                  'site',
                  Icons.language_rounded,
                  isSmallScreen,
                ),
                const SizedBox(width: 16),
                // Sort direction toggle
                _buildSortDirectionChip(isSmallScreen),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEnhancedFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color selectedColor,
    required ValueChanged<bool> onSelected,
    required bool isSmallScreen,
    String? badge,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => onSelected(!isSelected),
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12 : 16,
              vertical: isSmallScreen ? 8 : 10,
            ),
            decoration: BoxDecoration(
              gradient:
                  isSelected
                      ? LinearGradient(
                        colors: [
                          selectedColor.withAlpha(225),
                          selectedColor.withAlpha(175),
                        ],
                      )
                      : null,
              color:
                  !isSelected
                      ? Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHigh.withAlpha(175)
                      : null,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    isSelected
                        ? selectedColor.withAlpha(75)
                        : Theme.of(context).colorScheme.outline.withAlpha(50),
                width: isSelected ? 2 : 1,
              ),
              boxShadow:
                  isSelected
                      ? [
                        BoxShadow(
                          color: selectedColor.withAlpha(55),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                      : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? Colors.white.withAlpha(50)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    icon,
                    size: isSmallScreen ? 14 : 16,
                    color:
                        isSelected
                            ? Colors.white
                            : Theme.of(
                              context,
                            ).colorScheme.onSurface.withAlpha(175),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color:
                        isSelected
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color:
                          isSelected
                              ? Colors.white.withAlpha(55)
                              : selectedColor.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isSelected ? Colors.white : selectedColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEnhancedSortChip(
    String label,
    String sortKey,
    IconData icon,
    bool isSmallScreen,
  ) {
    final isSelected = _sortBy == sortKey;
    final selectedColor = Colors.purple;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              if (_sortBy == sortKey) {
                _sortAscending = !_sortAscending;
              } else {
                _sortBy = sortKey;
                _sortAscending = true;
              }
            });
          },
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12 : 16,
              vertical: isSmallScreen ? 8 : 10,
            ),
            decoration: BoxDecoration(
              gradient:
                  isSelected
                      ? LinearGradient(
                        colors: [
                          selectedColor.withAlpha(225),
                          selectedColor.withAlpha(175),
                        ],
                      )
                      : null,
              color:
                  !isSelected
                      ? Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHigh.withAlpha(175)
                      : null,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color:
                    isSelected
                        ? selectedColor.withAlpha(75)
                        : Theme.of(context).colorScheme.outline.withAlpha(50),
                width: isSelected ? 2 : 1,
              ),
              boxShadow:
                  isSelected
                      ? [
                        BoxShadow(
                          color: selectedColor.withAlpha(55),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                      : [],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color:
                        isSelected
                            ? Colors.white.withAlpha(50)
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    icon,
                    size: isSmallScreen ? 14 : 16,
                    color:
                        isSelected
                            ? Colors.white
                            : Theme.of(
                              context,
                            ).colorScheme.onSurface.withAlpha(175),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color:
                        isSelected
                            ? Colors.white
                            : Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (isSelected) ...[
                  const SizedBox(width: 4),
                  Icon(
                    _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 12,
                    color: Colors.white,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSortDirectionChip(bool isSmallScreen) {
    final selectedColor = Colors.indigo;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOutCubic,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _sortAscending = !_sortAscending;
            });
          },
          borderRadius: BorderRadius.circular(20),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeInOutCubic,
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12 : 16,
              vertical: isSmallScreen ? 8 : 10,
            ),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  selectedColor.withAlpha(225),
                  selectedColor.withAlpha(175),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: selectedColor.withAlpha(75), width: 2),
              boxShadow: [
                BoxShadow(
                  color: selectedColor.withAlpha(55),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(50),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Icon(
                    _sortAscending ? Icons.arrow_upward : Icons.arrow_downward,
                    size: isSmallScreen ? 14 : 16,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _sortAscending
                      ? AppLocalizations.of(context)!.sortAsc
                      : AppLocalizations.of(context)!.sortDesc,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Load the actual weekly scan count from the database
  Future<void> _loadWeeklyCount() async {
    try {
      final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));

      // Query Firestore directly for weekly count
      final querySnapshot =
          await FirestoreService.instance.firestore
              .collection('crawl_requests')
              .where('createdAt', isGreaterThan: oneWeekAgo)
              .get();

      setState(() {
        _weeklyCount = querySnapshot.docs.length;
      });
    } catch (e) {
      // Fallback to loaded activities count
      setState(() {
        _weeklyCount = _getWeeklyCountFromLoaded();
      });
    }
  }

  int _getWeeklyCount() {
    // Return the actual database count, not the loaded activities count
    return _weeklyCount;
  }

  int _getWeeklyCountFromLoaded() {
    final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
    return _activities
        .where((activity) => activity.timestamp.isAfter(oneWeekAgo))
        .length;
  }

  int _getUpdatesCount() {
    return _activities.where((activity) => activity.hasStockUpdates).length;
  }

  /// Apply filters and sorting to activities
  List<ScanActivity> _getFilteredAndSortedActivities() {
    List<ScanActivity> filtered = List.from(_activities);

    // Apply filters
    if (_showOnlyWithUpdates) {
      filtered =
          filtered.where((activity) => activity.hasStockUpdates).toList();
    }

    // Note: Stock vs price update filtering would require additional data
    // from the backend to distinguish between different types of updates
    // For now, we'll use hasStockUpdates as a general "has updates" flag

    // Apply sorting
    filtered.sort((a, b) {
      switch (_sortBy) {
        case 'timestamp':
          return _sortAscending
              ? a.timestamp.compareTo(b.timestamp)
              : b.timestamp.compareTo(a.timestamp);
        case 'updates':
          final aUpdates = a.hasStockUpdates ? 1 : 0;
          final bUpdates = b.hasStockUpdates ? 1 : 0;
          return _sortAscending
              ? aUpdates.compareTo(bUpdates)
              : bUpdates.compareTo(aUpdates);
        case 'site':
          final aSites = a.details?.length ?? 0;
          final bSites = b.details?.length ?? 0;
          return _sortAscending
              ? aSites.compareTo(bSites)
              : bSites.compareTo(aSites);
        default:
          return _sortAscending
              ? a.timestamp.compareTo(b.timestamp)
              : b.timestamp.compareTo(a.timestamp);
      }
    });

    return filtered;
  }

  Widget _buildActivityCard(ScanActivity activity) {
    final l10n = AppLocalizations.of(context)!;
    final dateFormat = DateFormat('MMM d, HH:mm');
    final isToday = DateTime.now().difference(activity.timestamp).inDays == 0;
    final timeFormat = isToday ? DateFormat('HH:mm') : dateFormat;

    // Debug logging to verify activity data

    return GestureDetector(
      onTap:
          activity.hasStockUpdates
              ? () {
                _showStockUpdates(activity);
              }
              : () {},
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color:
                      activity.hasStockUpdates
                          ? Colors.green
                          : Colors.grey.shade400,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 12),

              // Main content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          timeFormat.format(activity.timestamp),
                          style: const TextStyle(
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.shopping_bag_outlined,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          l10n.itemsScannedCount(activity.itemsScanned),
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Icon(
                          Icons.timer_outlined,
                          size: 16,
                          color: Colors.grey.shade600,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          activity.formattedDuration,
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    if (activity.hasStockUpdates) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.notifications_active,
                            size: 16,
                            color: Colors.green.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.stockUpdatesFoundTapToView,
                            style: TextStyle(
                              color: Colors.green.shade600,
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.check_circle_outline,
                            size: 16,
                            color: Colors.grey.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            l10n.noStockUpdates,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (activity.details != null &&
                        activity.details!.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        activity.details!,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Arrow indicator for clickable items
              if (activity.hasStockUpdates) ...[
                Icon(
                  Icons.arrow_forward_ios,
                  size: 16,
                  color: Colors.grey.shade400,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  /// Show stock updates for a specific scan activity
  Future<void> _showStockUpdates(ScanActivity activity) async {
    final l10n = AppLocalizations.of(context)!;
    if (activity.crawlRequestId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.noStockUpdateDetailsForScan),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Debug: Let's see what's actually in the stock_history collection
      final debugQuery =
          await FirestoreService.instance.firestore
              .collection('stock_history')
              .orderBy('timestamp', descending: true)
              .limit(10)
              .get();

      for (int i = 0; i < debugQuery.docs.length; i++) {
        final doc = debugQuery.docs[i];
        final data = doc.data();

        if (data.containsKey('crawlRequestId')) {
          if (data['crawlRequestId'] == activity.crawlRequestId) {}
        } else {}

        if (data.containsKey('timestamp')) {}
      }

      // Get both stock updates and price updates for this crawl request
      final stockUpdates = await FirestoreService.instance
          .getStockUpdatesForCrawlRequest(activity.crawlRequestId!);

      final priceUpdates = await FirestoreService.instance
          .getPriceUpdatesForCrawlRequest(activity.crawlRequestId!);

      // Combine stock and price updates
      final allUpdates = [...stockUpdates, ...priceUpdates];

      // If no updates found, try to get products that were updated during the scan timeframe
      List<Map<String, dynamic>> fallbackUpdates = [];
      if (allUpdates.isEmpty && activity.hasStockUpdates) {
        try {
          // Get the crawl request details to find the time range
          final crawlRequestDoc =
              await FirestoreService.instance.firestore
                  .collection('crawl_requests')
                  .doc(activity.crawlRequestId)
                  .get();

          if (crawlRequestDoc.exists) {
            final crawlData = crawlRequestDoc.data()!;
            final startTime = crawlData['startedAt'] ?? crawlData['createdAt'];
            final endTime = crawlData['completedAt'] ?? crawlData['updatedAt'];

            if (startTime != null && endTime != null) {
              DateTime startTimestamp =
                  startTime is DateTime ? startTime : startTime.toDate();
              DateTime endTimestamp =
                  endTime is DateTime ? endTime : endTime.toDate();

              // Query products that were last updated during the scan timeframe
              final productsQuery =
                  await FirestoreService.instance.firestore
                      .collection('products')
                      .where(
                        'lastUpdated',
                        isGreaterThanOrEqualTo: startTimestamp,
                      )
                      .where('lastUpdated', isLessThanOrEqualTo: endTimestamp)
                      .where('isInStock', isEqualTo: true)
                      .limit(50)
                      .get();

              for (final doc in productsQuery.docs) {
                final productData = doc.data();
                fallbackUpdates.add({
                  'productId': doc.id,
                  'name': productData['name'] ?? 'Unknown',
                  'site': productData['site'] ?? '',
                  'siteName': productData['siteName'] ?? '',
                  'price': productData['price'] ?? '',
                  'priceValue': productData['priceValue'],
                  'currency': productData['currency'] ?? 'EUR',
                  'url': productData['url'] ?? '',
                  'imageUrl': productData['imageUrl'],
                  'category': productData['category'] ?? 'Matcha',
                  'timestamp': productData['lastUpdated'],
                  'previousStatus': false, // Assume it was out of stock before
                  'isInStock': true,
                  'changeType': 'restock',
                });
              }
            }
          }
        } catch (e) {}
      }

      final finalUpdates = allUpdates.isNotEmpty ? allUpdates : fallbackUpdates;

      // Convert Firestore Timestamps to DateTime for compatibility
      final convertedUpdates =
          finalUpdates.map((update) {
            final convertedUpdate = Map<String, dynamic>.from(update);

            // Convert timestamp if it's a Firestore Timestamp to ISO string
            if (convertedUpdate['timestamp'] is Timestamp) {
              convertedUpdate['timestamp'] =
                  (convertedUpdate['timestamp'] as Timestamp)
                      .toDate()
                      .toIso8601String();
            } else if (convertedUpdate['timestamp'] is DateTime) {
              // If it's already a DateTime, convert to ISO string
              convertedUpdate['timestamp'] =
                  (convertedUpdate['timestamp'] as DateTime).toIso8601String();
            }

            return convertedUpdate;
          }).toList();

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      if (convertedUpdates.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.noDetailedProductUpdatesForScan),
              backgroundColor: Colors.orange,
            ),
          );
        }
        return;
      }

      // Navigate to stock updates screen
      if (mounted) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (context) => StockUpdatesScreen(
                  updates: convertedUpdates,
                  scanActivity: activity,
                ),
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.errorLoadingStockUpdatesWithError('$e')),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  /// Load server scan activities from Firestore via FirestoreService
  Future<List<ScanActivity>> _loadServerActivitiesFromFirestore({
    bool forceRefresh = false,
  }) async {
    const cacheKey = 'server_activities';

    // Try to get from cache first unless force refresh is requested
    if (!forceRefresh) {
      final cachedActivities = await CacheService.getCache<List<dynamic>>(
        cacheKey,
      );
      if (cachedActivities != null) {
        return cachedActivities
            .map((item) => ScanActivity.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    }

    try {
      // Use FirestoreService to get crawl requests
      final crawlRequests = await FirestoreService.instance.getCrawlRequests(
        limit: 50, // Increased limit to get more recent activities
      );

      if (crawlRequests.isEmpty) {
        return [];
      }

      final activities = <ScanActivity>[];

      for (final crawlRequest in crawlRequests) {
        try {
          final activity = _convertCrawlRequestToScanActivity(crawlRequest);
          activities.add(activity);
        } catch (e) {
          // Continue with other requests even if one fails
          continue;
        }
      }

      // Sort activities by timestamp (most recent first)
      activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Cache the results for 10 minutes
      await CacheService.setCache(
        cacheKey,
        activities.map((activity) => activity.toJson()).toList(),
        duration: const Duration(minutes: 10),
      );

      return activities;
    } catch (e) {
      if (e is Exception) {}
      rethrow; // Re-throw to be handled by calling method
    }
  }

  /// Convert a crawl request from Firestore to a ScanActivity
  ScanActivity _convertCrawlRequestToScanActivity(
    Map<String, dynamic> crawlRequest,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final status = crawlRequest['status'] ?? 'unknown';
    final createdAt = crawlRequest['createdAt'];
    final completedAt = crawlRequest['completedAt'];
    final startedAt = crawlRequest['startedAt'];
    final processedAt = crawlRequest['processedAt'];

    // Parse timestamps - handle both DateTime and Timestamp objects
    DateTime timestamp = DateTime.now();
    if (createdAt != null) {
      if (createdAt is DateTime) {
        timestamp = createdAt;
      } else if (createdAt.runtimeType.toString().contains('Timestamp')) {
        timestamp = createdAt.toDate();
      } else if (createdAt is String) {
        timestamp = DateTime.tryParse(createdAt) ?? DateTime.now();
      }
    }

    // Extract scan details from the actual document structure
    final totalProducts = (crawlRequest['totalProducts'] ?? 0) as int;
    final stockUpdates = (crawlRequest['stockUpdates'] ?? 0) as int;
    final priceUpdates = (crawlRequest['priceUpdates'] ?? 0) as int;
    final sitesProcessed = (crawlRequest['sitesProcessed'] ?? 0) as int;
    final triggerType = crawlRequest['triggerType'] ?? 'manual';

    // Calculate duration from duration field (in milliseconds) or from timestamps
    int durationInSeconds = 0;
    final durationMs = crawlRequest['duration'];
    if (durationMs != null && durationMs is int && durationMs > 0) {
      durationInSeconds = (durationMs / 1000).round();
    } else {
      // Fallback: calculate from timestamps
      DateTime? endTime;
      final endTimeStamp = completedAt ?? startedAt ?? processedAt;
      if (endTimeStamp != null) {
        if (endTimeStamp is DateTime) {
          endTime = endTimeStamp;
        } else if (endTimeStamp.runtimeType.toString().contains('Timestamp')) {
          endTime = endTimeStamp.toDate();
        } else if (endTimeStamp is String) {
          endTime = DateTime.tryParse(endTimeStamp);
        }
      }

      if (endTime != null) {
        durationInSeconds = endTime.difference(timestamp).inSeconds.abs();
      }
    }

    // Include both stock updates and price updates
    final hasStockUpdates = stockUpdates > 0 || priceUpdates > 0;
    final requestId = crawlRequest['id'] ?? 'unknown';

    // More accurate status determination - if it has completedAt, it's completed
    String actualStatus = status;
    if (completedAt != null && status == 'running') {
      actualStatus = 'completed';
    }

    // Build detailed status message based on actual data
    String details;
    switch (actualStatus) {
      case 'completed':
        details = l10n.scannedProductsAcrossSites(
          totalProducts,
          sitesProcessed,
        );
        if (hasStockUpdates) {
          List<String> updateTypes = [];
          if (stockUpdates > 0) {
            updateTypes.add('$stockUpdates stock');
          }
          if (priceUpdates > 0) {
            updateTypes.add('$priceUpdates price');
          }
          details += l10n.scanUpdatesFound(updateTypes.join(', '));
        }
        break;
      case 'running':
        details = l10n.scanInProgressProductsFound(totalProducts);
        break;
      case 'failed':
        final results = crawlRequest['results'] as Map<String, dynamic>? ?? {};
        final errors = results['errors'] as List? ?? [];
        details = l10n.scanFailedWithErrors(errors.length);
        break;
      case 'pending':
        details = l10n.scanQueuedForProcessing;
        break;
      default:
        details = l10n.statusWithValue(status);
        if (totalProducts > 0) {
          details += l10n.scanProductsCount(totalProducts);
        }
        break;
    }

    // Determine scan type based on trigger type
    String scanType;
    switch (triggerType) {
      case 'scheduled':
        scanType = 'server';
        break;
      case 'manual':
        scanType = 'manual';
        break;
      default:
        scanType = 'server';
        break;
    }

    final scanActivity = ScanActivity(
      id: 'server_${requestId}_${timestamp.millisecondsSinceEpoch}',
      timestamp: timestamp,
      scanType: scanType,
      duration: durationInSeconds,
      itemsScanned: totalProducts,
      hasStockUpdates: hasStockUpdates,
      details: details,
      crawlRequestId:
          requestId, // Add the crawl request ID for detailed stock updates
    );

    return scanActivity;
  }
}
