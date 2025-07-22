// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/scan_activity.dart';
import '../services/database_service.dart';

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
  static const int _pageSize = 20;
  bool _hasMoreData = true;
  bool _isLoadingMore = false;

  @override
  void initState() {
    super.initState();
    _loadActivities();
    _scrollController.addListener(_onScroll);
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
      final activities = await DatabaseService.platformService
          .getScanActivities(limit: _pageSize, offset: 0);
      final totalCount =
          await DatabaseService.platformService.getScanActivitiesCount();

      print(
        '📊 Loaded ${activities.length} scan activities, total: $totalCount',
      );

      setState(() {
        _activities = activities;
        _totalActivities = totalCount;
        _hasMoreData = activities.length == _pageSize;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading scan activities: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadMoreActivities() async {
    if (_isLoadingMore) return;

    setState(() {
      _isLoadingMore = true;
    });

    try {
      final moreActivities = await DatabaseService.platformService
          .getScanActivities(limit: _pageSize, offset: _activities.length);

      setState(() {
        _activities.addAll(moreActivities);
        _hasMoreData = moreActivities.length == _pageSize;
        _isLoadingMore = false;
      });
    } catch (e) {
      print('Error loading more activities: $e');
      setState(() {
        _isLoadingMore = false;
      });
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
      appBar: AppBar(
        title: const Text('Recent Scans'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadActivities,
            tooltip: 'Refresh',
          ),
          PopupMenuButton<String>(
            onSelected: (value) {
              if (value == 'clear_old') {
                _clearOldActivities();
              } else if (value == 'clear_all') {
                _clearAllActivities();
              }
            },
            itemBuilder:
                (context) => [
                  const PopupMenuItem(
                    value: 'clear_old',
                    child: Row(
                      children: [
                        Icon(Icons.delete_sweep),
                        SizedBox(width: 8),
                        Text('Clear Old Activities'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'clear_all',
                    child: Row(
                      children: [
                        Icon(Icons.delete_forever, color: Colors.red),
                        SizedBox(width: 8),
                        Text(
                          'Clear All Activities',
                          style: TextStyle(color: Colors.red),
                        ),
                      ],
                    ),
                  ),
                ],
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _buildActivityList(),
    );
  }

  Widget _buildActivityList() {
    if (_activities.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No scan activities recorded yet',
              style: TextStyle(fontSize: 18, color: Colors.grey),
            ),
            SizedBox(height: 8),
            Text(
              'Background scans will appear here',
              style: TextStyle(fontSize: 14, color: Colors.grey),
            ),
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
            onRefresh: _loadActivities,
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
      child: Row(
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

    return Card(
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
                      const Spacer(),
                      _buildScanTypeChip(activity.scanType),
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
    );
  }

  Widget _buildScanTypeChip(String scanType) {
    Color chipColor;
    IconData chipIcon;

    switch (scanType) {
      case 'background':
        chipColor = Colors.blue;
        chipIcon = Icons.schedule;
        break;
      case 'manual':
        chipColor = Colors.orange;
        chipIcon = Icons.touch_app;
        break;
      case 'favorites':
        chipColor = Colors.pink;
        chipIcon = Icons.favorite;
        break;
      default:
        chipColor = Colors.grey;
        chipIcon = Icons.help_outline;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: chipColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: chipColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(chipIcon, size: 12, color: chipColor),
          const SizedBox(width: 4),
          Text(
            ScanActivity(
              id: '',
              timestamp: DateTime.now(),
              itemsScanned: 0,
              duration: 0,
              hasStockUpdates: false,
              scanType: scanType,
            ).scanTypeDisplayName,
            style: TextStyle(
              color: chipColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
