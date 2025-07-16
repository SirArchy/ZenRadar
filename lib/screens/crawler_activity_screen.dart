import 'package:flutter/material.dart';
import 'dart:async';
import '../services/crawler_logger.dart';

class CrawlerActivityScreen extends StatefulWidget {
  const CrawlerActivityScreen({super.key});

  @override
  State<CrawlerActivityScreen> createState() => _CrawlerActivityScreenState();
}

class _CrawlerActivityScreenState extends State<CrawlerActivityScreen> {
  late StreamSubscription<CrawlerActivity> _activitySubscription;
  final List<CrawlerActivity> _activities = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();

    // Load existing activities
    _activities.addAll(CrawlerLogger.instance.activities);

    // Listen to new activities
    _activitySubscription = CrawlerLogger.instance.activityStream.listen((
      activity,
    ) {
      if (mounted) {
        setState(() {
          _activities.insert(0, activity);

          // Keep only the most recent 50 activities in UI
          if (_activities.length > 50) {
            _activities.removeAt(50);
          }
        });

        // Auto-scroll to top when new activity arrives
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
      }
    });
  }

  @override
  void dispose() {
    _activitySubscription.cancel();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crawler Activity'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.clear_all),
            onPressed: () {
              setState(() {
                _activities.clear();
              });
              CrawlerLogger.instance.clearActivities();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Activity log cleared')),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Status banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              color:
                  CrawlerLogger.instance.isHeadModeEnabled
                      ? Colors.green.shade100
                      : Colors.orange.shade100,
              border: Border(
                bottom: BorderSide(
                  color:
                      CrawlerLogger.instance.isHeadModeEnabled
                          ? Colors.green
                          : Colors.orange,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  CrawlerLogger.instance.isHeadModeEnabled
                      ? Icons.visibility
                      : Icons.visibility_off,
                  color:
                      CrawlerLogger.instance.isHeadModeEnabled
                          ? Colors.green
                          : Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    CrawlerLogger.instance.isHeadModeEnabled
                        ? 'Head mode is active - showing real-time activity'
                        : 'Head mode is disabled - no new activity will be shown',
                    style: TextStyle(
                      color:
                          CrawlerLogger.instance.isHeadModeEnabled
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Activity list
          Expanded(
            child:
                _activities.isEmpty
                    ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.timeline,
                            size: 64,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 16),
                          Text(
                            'No activity yet',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            CrawlerLogger.instance.isHeadModeEnabled
                                ? 'Activity will appear here when the crawler runs'
                                : 'Enable head mode in settings to see activity',
                            style: TextStyle(color: Colors.grey[600]),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      controller: _scrollController,
                      padding: const EdgeInsets.all(16.0),
                      itemCount: _activities.length,
                      itemBuilder: (context, index) {
                        return _ActivityTile(activity: _activities[index]);
                      },
                    ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  final CrawlerActivity activity;

  const _ActivityTile({required this.activity});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8.0),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Activity type icon
            Container(
              padding: const EdgeInsets.all(6.0),
              decoration: BoxDecoration(
                color: _getActivityColor(activity.type).withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _getActivityIcon(activity.type),
                size: 16,
                color: _getActivityColor(activity.type),
              ),
            ),
            const SizedBox(width: 12),

            // Activity content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (activity.siteName != null) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue.shade100,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            activity.siteName!,
                            style: TextStyle(
                              fontSize: 10,
                              color: Colors.blue.shade700,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                      ],
                      Text(
                        _formatTime(activity.timestamp),
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(activity.message, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getActivityColor(CrawlerActivityType type) {
    switch (type) {
      case CrawlerActivityType.info:
        return Colors.blue;
      case CrawlerActivityType.success:
        return Colors.green;
      case CrawlerActivityType.warning:
        return Colors.orange;
      case CrawlerActivityType.error:
        return Colors.red;
      case CrawlerActivityType.progress:
        return Colors.purple;
    }
  }

  IconData _getActivityIcon(CrawlerActivityType type) {
    switch (type) {
      case CrawlerActivityType.info:
        return Icons.info;
      case CrawlerActivityType.success:
        return Icons.check_circle;
      case CrawlerActivityType.warning:
        return Icons.warning;
      case CrawlerActivityType.error:
        return Icons.error;
      case CrawlerActivityType.progress:
        return Icons.hourglass_empty;
    }
  }

  String _formatTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else {
      return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}
