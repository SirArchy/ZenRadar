import 'package:flutter/material.dart';
import '../models/website_stock_analytics.dart';
import '../services/website_analytics_service.dart';
import '../widgets/website_stock_chart.dart';
import '../widgets/skeleton_loading.dart';

class WebsiteOverviewScreen extends StatefulWidget {
  const WebsiteOverviewScreen({super.key});

  @override
  State<WebsiteOverviewScreen> createState() => _WebsiteOverviewScreenState();
}

class _WebsiteOverviewScreenState extends State<WebsiteOverviewScreen> {
  final WebsiteAnalyticsService _analyticsService =
      WebsiteAnalyticsService.instance;

  List<WebsiteStockAnalytics> _websiteAnalytics = [];
  Map<String, dynamic> _summary = {};
  bool _isLoading = true;
  String _selectedTimeRange = 'month';
  String? _error;

  final List<String> _timeRanges = ['day', 'week', 'month', 'all'];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Load analytics (will use cache if available)
      final analytics = await _analyticsService.getAllWebsiteAnalytics(
        timeRange: _selectedTimeRange,
        forceRefresh: false, // Use cache by default
      );
      final summary = await _analyticsService.getOverallSummary(
        timeRange: _selectedTimeRange,
        forceRefresh: false, // Use cache by default
      );

      setState(() {
        _websiteAnalytics = analytics;
        _summary = summary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load analytics: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _forceRefreshAnalytics() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Force refresh from server/database, bypass cache
      final analytics = await _analyticsService.getAllWebsiteAnalytics(
        timeRange: _selectedTimeRange,
        forceRefresh: true, // Force refresh
      );
      final summary = await _analyticsService.getOverallSummary(
        timeRange: _selectedTimeRange,
        forceRefresh: true, // Force refresh
      );

      setState(() {
        _websiteAnalytics = analytics;
        _summary = summary;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to refresh analytics: $e';
        _isLoading = false;
      });
    }
  }

  void _showTimeRangePicker() {
    showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Time Range'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children:
                _timeRanges.map((String timeRange) {
                  return RadioListTile<String>(
                    title: Text(_getTimeRangeLabel(timeRange)),
                    value: timeRange,
                    groupValue: _selectedTimeRange,
                    onChanged: (String? value) {
                      if (value != null) {
                        Navigator.of(context).pop(value);
                      }
                    },
                  );
                }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        );
      },
    ).then((String? selectedTimeRange) {
      if (selectedTimeRange != null) {
        setState(() {
          _selectedTimeRange = selectedTimeRange;
        });
        _loadAnalytics();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: _forceRefreshAnalytics,
        tooltip: 'Refresh analytics',
        child: const Icon(Icons.refresh),
      ),
      body: _buildBody(),
    );
  }

  // Public method to refresh analytics (can be called from parent)
  void refreshAnalytics() {
    _loadAnalytics();
  }

  Widget _buildBody() {
    if (_isLoading) {
      return ListView.builder(
        itemCount: 3,
        itemBuilder: (context, index) {
          if (index == 0) {
            return const SkeletonStatsHeader();
          }
          return const SkeletonWebsiteCard();
        },
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _forceRefreshAnalytics,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _forceRefreshAnalytics,
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: _buildSummaryCard()),
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildBuilderDelegate((context, index) {
                if (index >= _websiteAnalytics.length) return null;
                return _buildWebsiteCard(_websiteAnalytics[index]);
              }, childCount: _websiteAnalytics.length),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard() {
    return Container(
      margin: const EdgeInsets.all(16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Fixed layout for header row
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.dashboard_outlined,
                        color: Theme.of(context).primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Overall Summary',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Time range selector moved to separate row
                  Align(
                    alignment: Alignment.centerRight,
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 200),
                      child: InkWell(
                        onTap: _showTimeRangePicker,
                        borderRadius: BorderRadius.circular(16),
                        child: Chip(
                          label: Text(
                            _getTimeRangeLabel(_selectedTimeRange),
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                          backgroundColor:
                              Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                          side: BorderSide(
                            color: Theme.of(
                              context,
                            ).colorScheme.outline.withAlpha(100),
                            width: 1,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryItem(
                      'Websites',
                      '${_summary['activeWebsites'] ?? 0}/${_summary['totalWebsites'] ?? 0}',
                      Icons.language,
                      Colors.blue,
                    ),
                  ),
                  Expanded(
                    child: _buildSummaryItem(
                      'Products',
                      '${_summary['totalProducts'] ?? 0}',
                      Icons.inventory_2,
                      Colors.green,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _buildSummaryItem(
                      'In Stock',
                      '${(_summary['overallStockPercentage'] ?? 0).toStringAsFixed(1)}%',
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildSummaryItem(
                      'Updates',
                      '${_summary['totalUpdates'] ?? 0}',
                      Icons.timeline,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              if (_summary['mostRecentUpdate'] != null) ...[
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final mostRecentUpdate = _safeParseDateTime(
                      _summary['mostRecentUpdate'],
                    );
                    return Text(
                      'Last update: ${mostRecentUpdate != null ? _formatDateTime(mostRecentUpdate) : 'Unknown'}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withAlpha(175),
                      ),
                    );
                  },
                ),
              ],
              if (_summary['mostActiveWebsite'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Most active: ${_summary['mostActiveWebsite']}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha(175),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(175),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWebsiteCard(WebsiteStockAnalytics analytics) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: ExpansionTile(
        title: Row(
          children: [
            _buildWebsiteStatusIcon(analytics),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    analytics.siteName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  Text(
                    _buildWebsiteSubtitle(analytics),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withAlpha(175),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8, left: 44),
          child: Row(
            children: [
              _buildStatusChip(
                '${analytics.productsInStock}/${analytics.totalProducts} in stock',
                analytics.stockPercentage >= 50 ? Colors.green : Colors.red,
              ),
              const SizedBox(width: 8),
              _buildStatusChip(
                '${analytics.stockUpdates.length} updates',
                Colors.blue,
              ),
            ],
          ),
        ),
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Stock update chart
                Text(
                  'Stock Updates (${_getTimeRangeLabel(_selectedTimeRange)})',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                WebsiteStockChart(
                  analytics: analytics,
                  timeRange: _selectedTimeRange,
                ),
                const SizedBox(height: 24),

                // Update pattern
                WebsiteUpdatePatternWidget(analytics: analytics),

                // Recent updates
                if (analytics.recentUpdates.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Recent Updates (Last 7 days)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...analytics.recentUpdates
                      .take(5)
                      .map((update) => _buildRecentUpdateItem(update)),
                ],

                const SizedBox(height: 16),
                Text(
                  'Update frequency: ${analytics.updateFrequencyDescription}',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha(175),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWebsiteStatusIcon(WebsiteStockAnalytics analytics) {
    IconData icon;
    Color color;

    if (analytics.totalProducts == 0) {
      icon = Icons.help_outline;
      color = Colors.grey;
    } else if (analytics.stockPercentage >= 75) {
      icon = Icons.check_circle;
      color = Colors.green;
    } else if (analytics.stockPercentage >= 25) {
      icon = Icons.warning;
      color = Colors.orange;
    } else {
      icon = Icons.error;
      color = Colors.red;
    }

    return Icon(icon, color: color, size: 32);
  }

  String _buildWebsiteSubtitle(WebsiteStockAnalytics analytics) {
    if (analytics.totalProducts == 0) {
      return 'No products tracked';
    }

    final lastUpdate = analytics.lastStockChange;
    if (lastUpdate != null) {
      return 'Last update: ${_formatDateTime(lastUpdate)}';
    }

    return 'No recent updates';
  }

  Widget _buildStatusChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(50),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildRecentUpdateItem(StockUpdateEvent update) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(50),
        ),
      ),
      child: Row(
        children: [
          Icon(
            update.hasRestocks ? Icons.trending_up : Icons.trending_down,
            size: 16,
            color: update.hasRestocks ? Colors.green : Colors.red,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(update.description, style: const TextStyle(fontSize: 12)),
                Text(
                  _formatDateTime(update.timestamp),
                  style: TextStyle(
                    fontSize: 10,
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withAlpha(150),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeRangeLabel(String timeRange) {
    switch (timeRange) {
      case 'day':
        return 'Last 24 hours';
      case 'week':
        return 'Last 7 days';
      case 'month':
        return 'Last 30 days';
      case 'all':
        return 'All time';
      default:
        return timeRange;
    }
  }

  /// Safely converts a dynamic value to DateTime, handling both DateTime objects and strings
  DateTime? _safeParseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        print('Error parsing DateTime from string: $value, error: $e');
        return null;
      }
    }
    print('Unexpected DateTime type: ${value.runtimeType}');
    return null;
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays}d ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }
}
