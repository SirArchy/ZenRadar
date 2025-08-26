// ignore_for_file: unused_element, use_build_context_synchronously

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/scan_activity.dart';
import '../services/database_service.dart';
import '../services/firestore_service.dart';
import '../services/cache_service.dart';
import '../widgets/skeleton_loading.dart';
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
  final ScrollController _scrollController = ScrollController();
  bool _hasMoreData = true;
  final bool _isLoadingMore = false;

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
      setState(() {});
      await _loadActivities();
    } catch (e) {
      print('Error loading settings: $e');
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
      // Load server scan activities from Firestore (server mode only)
      try {
        final serverActivities = await _loadServerActivitiesFromFirestore();
        print(
          'Loaded ${serverActivities.length} server activities from Firestore',
        );
        setState(() {
          _activities = serverActivities;
          _totalActivities = serverActivities.length;
          _hasMoreData = false; // No pagination for server mode yet
          _isLoading = false;
        });
      } catch (e) {
        print('Error loading server activities: $e');
        setState(() {
          _activities = [];
          _totalActivities = 0;
          _hasMoreData = false;
          _isLoading = false;
        });

        // Show error message to user
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to load server activities: $e'),
              backgroundColor: Colors.red,
              action: SnackBarAction(
                label: 'Retry',
                onPressed: () => _forceRefreshActivities(),
              ),
            ),
          );
        }
      }
    } catch (e) {
      print('Error loading scan activities: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _forceRefreshActivities() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Clear cache and force refresh from server
      await CacheService.clearCache('server_activities');

      final serverActivities = await _loadServerActivitiesFromFirestore(
        forceRefresh: true,
      );
      print(
        'Force refreshed ${serverActivities.length} server activities from Firestore',
      );
      setState(() {
        _activities = serverActivities;
        _totalActivities = serverActivities.length;
        _hasMoreData = false;
        _isLoading = false;
      });
    } catch (e) {
      print('Error force refreshing server activities: $e');
      setState(() {
        _activities = [];
        _totalActivities = 0;
        _hasMoreData = false;
        _isLoading = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to refresh server activities: $e'),
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
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear Old Activities'),
            content: const Text(
              'This will remove scan activities older than 30 days. Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Clear'),
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
            const SnackBar(
              content: Text('Old activities cleared successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error clearing activities: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _clearAllActivities() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Clear All Activities'),
            content: const Text(
              'This will permanently delete ALL scan activities. This action cannot be undone. Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                style: TextButton.styleFrom(foregroundColor: Colors.red),
                child: const Text('Delete All'),
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
            const SnackBar(
              content: Text('All activities cleared successfully'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error clearing activities: $e'),
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
        tooltip: 'Refresh activities',
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
              'No server scans found',
              style: const TextStyle(fontSize: 18, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              'Server scan activities will appear here',
              style: const TextStyle(fontSize: 14, color: Colors.grey),
            ),
            if (true) ...[
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _loadActivities,
                child: const Text('Refresh'),
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

        // Activities list
        Expanded(
          child: RefreshIndicator(
            onRefresh: _forceRefreshActivities,
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _activities.length + (_hasMoreData ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _activities.length) {
                  // Loading indicator at the bottom
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }

                final activity = _activities[index];
                return _buildActivityCard(activity);
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          // Mode indicator
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.shade100,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue, width: 1),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud, size: 16, color: Colors.blue),
                const SizedBox(width: 6),
                Text(
                  'Server Mode',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.blue.shade700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Statistics
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                'Total Scans',
                _totalActivities.toString(),
                Icons.history,
              ),
              _buildStatItem(
                'This Week',
                _getWeeklyCount().toString(),
                Icons.calendar_today,
              ),
              _buildStatItem(
                'With Updates',
                _getUpdatesCount().toString(),
                Icons.notifications_active,
              ),
            ],
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

  int _getWeeklyCount() {
    final oneWeekAgo = DateTime.now().subtract(const Duration(days: 7));
    return _activities
        .where((activity) => activity.timestamp.isAfter(oneWeekAgo))
        .length;
  }

  int _getUpdatesCount() {
    return _activities.where((activity) => activity.hasStockUpdates).length;
  }

  Widget _buildActivityCard(ScanActivity activity) {
    final dateFormat = DateFormat('MMM d, HH:mm');
    final isToday = DateTime.now().difference(activity.timestamp).inDays == 0;
    final timeFormat = isToday ? DateFormat('HH:mm') : dateFormat;

    return GestureDetector(
      onTap: null, // Stock updates not available in server mode
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
                          '${activity.itemsScanned} items scanned',
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
                            'Stock updates found',
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
                            'No stock updates',
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
            ],
          ),
        ),
      ),
    );
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
        print(
          'Using cached server activities (${cachedActivities.length} items)',
        );
        return cachedActivities
            .map((item) => ScanActivity.fromJson(item as Map<String, dynamic>))
            .toList();
      }
    }

    try {
      print('Loading server activities from Firestore...');

      // Use FirestoreService to get crawl requests
      final crawlRequests = await FirestoreService.instance.getCrawlRequests(
        limit: 50, // Increased limit to get more recent activities
      );

      print('Retrieved ${crawlRequests.length} crawl requests from Firestore');

      if (crawlRequests.isEmpty) {
        print('No crawl requests found in Firestore');
        return [];
      }

      final activities = <ScanActivity>[];

      for (final crawlRequest in crawlRequests) {
        try {
          print(
            'Processing crawl request: ${crawlRequest['id']} (status: ${crawlRequest['status']})',
          );
          final activity = _convertCrawlRequestToScanActivity(crawlRequest);
          activities.add(activity);
          print(
            'Converted: ${activity.itemsScanned} products, ${activity.hasStockUpdates ? activity.details : 'no updates'}',
          );
        } catch (e) {
          print('Error converting crawl request ${crawlRequest['id']}: $e');
          print('Crawl request data keys: ${crawlRequest.keys.toList()}');
          // Continue with other requests even if one fails
          continue;
        }
      }

      print(
        'Successfully converted ${activities.length}/${crawlRequests.length} server activities',
      );

      // Sort activities by timestamp (most recent first)
      activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      // Cache the results for 10 minutes
      await CacheService.setCache(
        cacheKey,
        activities.map((activity) => activity.toJson()).toList(),
        duration: const Duration(minutes: 10),
      );

      print('Cached ${activities.length} server activities');

      return activities;
    } catch (e) {
      print('Error loading server activities from Firestore: $e');
      print('Error type: ${e.runtimeType}');
      if (e is Exception) {
        print('Exception details: ${e.toString()}');
      }
      rethrow; // Re-throw to be handled by calling method
    }
  }

  /// Convert a crawl request from Firestore to a ScanActivity
  ScanActivity _convertCrawlRequestToScanActivity(
    Map<String, dynamic> crawlRequest,
  ) {
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

    final hasStockUpdates = stockUpdates > 0;
    final requestId = crawlRequest['id'] ?? 'unknown';

    // Build detailed status message based on actual data
    String details;
    switch (status) {
      case 'completed':
        details =
            'Scanned $totalProducts products across $sitesProcessed sites';
        if (hasStockUpdates) {
          details += ' - $stockUpdates stock updates found';
        }
        break;
      case 'running':
        details = 'Scan in progress - $totalProducts products found so far';
        break;
      case 'failed':
        final results = crawlRequest['results'] as Map<String, dynamic>? ?? {};
        final errors = results['errors'] as List? ?? [];
        details = 'Scan failed';
        if (errors.isNotEmpty) {
          details += ' - ${errors.length} error(s)';
        }
        break;
      case 'pending':
        details = 'Scan queued for processing';
        break;
      default:
        details = 'Status: $status';
        if (totalProducts > 0) {
          details += ' - $totalProducts products';
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

    return ScanActivity(
      id: 'server_${requestId}_${timestamp.millisecondsSinceEpoch}',
      timestamp: timestamp,
      scanType: scanType,
      duration: durationInSeconds,
      itemsScanned: totalProducts,
      hasStockUpdates: hasStockUpdates,
      details: details,
    );
  }
}
