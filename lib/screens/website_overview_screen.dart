// ignore_for_file: avoid_print

import 'package:flutter/material.dart';
import '../models/website_stock_analytics.dart';
import '../services/website_analytics_service.dart';
import '../services/subscription_service.dart';
import '../services/preload_service.dart';
import '../services/cache_service.dart';
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
  Map<String, dynamic> _fastSummary = {};
  bool _isLoadingSummary = true;
  bool _isLoadingAnalytics = true;
  String _selectedTimeRange = 'month';
  String? _error;
  bool _isPremium = false;

  final List<String> _timeRanges = ['day', 'week', 'month', 'all'];

  @override
  void initState() {
    super.initState();
    _initializeScreen();
  }

  /// Initialize screen by loading subscription status first, then data
  Future<void> _initializeScreen() async {
    await _loadSubscriptionStatus();
    _loadProgressively();
  }

  Future<void> _loadSubscriptionStatus() async {
    try {
      final isPremium = await SubscriptionService.instance.isPremiumUser();
      setState(() {
        _isPremium = isPremium;
        // For free users, default to 'day' since it's the only available option
        if (!isPremium && _selectedTimeRange != 'day') {
          _selectedTimeRange = 'day';
        }
      });
      print('🔐 Subscription status loaded: isPremium = $_isPremium');
    } catch (e) {
      print('Error loading subscription status: $e');
    }
  }

  /// Load data progressively - fast summary first, then full analytics
  Future<void> _loadProgressively() async {
    // Trigger background preloading on first access (if not already started)
    if (!PreloadService.instance.hasCompletedInitialPreload) {
      PreloadService.instance.startBackgroundPreload().catchError((error) {
        print('Failed to start preload service: $error');
      });
    }

    // Check if preloading has completed - if so, try to load from cache immediately
    if (PreloadService.instance.hasCompletedInitialPreload) {
      print('🚀 Preload completed - loading from cache immediately');
      await _loadFromCacheOrServer();
    } else {
      // First, load fast summary for immediate feedback
      _loadFastSummary();

      // Then load full analytics in the background
      _loadFullAnalytics();

      // Also try to wait for preload to complete (with timeout)
      _waitForPreloadWithTimeout();
    }
  }

  /// Wait for preload completion with timeout to avoid blocking UI
  Future<void> _waitForPreloadWithTimeout() async {
    try {
      await PreloadService.instance.waitForInitialPreload().timeout(
        const Duration(seconds: 5),
      );

      print('🎯 Preload completed - refreshing with cached data');

      // Once preload completes, refresh with the cached data
      if (mounted) {
        await _loadFromCacheOrServer();
      }
    } catch (e) {
      print('⏰ Preload timeout or error - continuing with normal loading: $e');
    }
  }

  /// Load data from cache first, then from server if needed
  Future<void> _loadFromCacheOrServer() async {
    setState(() {
      _isLoadingSummary = true;
      _isLoadingAnalytics = true;
      _error = null;
    });

    try {
      // Load analytics and summary from cache first (preload service handles caching)
      final results = await Future.wait([
        _analyticsService.getAllWebsiteAnalytics(
          timeRange: _selectedTimeRange,
          forceRefresh: false, // Use cache if available
        ),
        _analyticsService.getAnalyticsSummary(
          timeRange: _selectedTimeRange,
          forceRefresh: false, // Use cache if available
        ),
        _analyticsService.getFastSummary(
          timeRange: _selectedTimeRange,
          forceRefresh: false, // Use cache if available
        ),
      ]);

      final analytics = results[0] as List<WebsiteStockAnalytics>;
      final summary = results[1] as Map<String, dynamic>;
      final fastSummary = results[2] as Map<String, dynamic>;

      // Filter analytics for free users
      List<WebsiteStockAnalytics> filteredAnalytics = analytics;
      print(
        '🔍 Filtering analytics: isPremium = $_isPremium, total sites = ${analytics.length}',
      );

      if (!_isPremium) {
        final freeSites = [
          'ippodo',
          'marukyu',
          'tokichi',
          'matcha-karu',
          'yoshien',
        ];
        filteredAnalytics =
            analytics
                .where((analytics) => freeSites.contains(analytics.siteKey))
                .toList();
        print(
          '🆓 Free user - filtered to ${filteredAnalytics.length} sites: ${filteredAnalytics.map((a) => a.siteKey).toList()}',
        );
      } else {
        print(
          '💎 Premium user - showing all ${analytics.length} sites: ${analytics.map((a) => a.siteKey).toList()}',
        );
      }

      setState(() {
        _websiteAnalytics = filteredAnalytics;
        _summary = summary;
        _fastSummary = fastSummary;
        _isLoadingSummary = false;
        _isLoadingAnalytics = false;
      });

      print('✅ Data loaded successfully: ${filteredAnalytics.length} websites');
    } catch (e) {
      setState(() {
        _error = 'Failed to load analytics: $e';
        _isLoadingSummary = false;
        _isLoadingAnalytics = false;
      });
      print('❌ Failed to load data: $e');
    }
  }

  /// Load fast summary data for immediate display
  Future<void> _loadFastSummary() async {
    setState(() {
      _isLoadingSummary = true;
      _error = null;
    });

    try {
      final fastSummary = await _analyticsService.getFastSummary(
        timeRange: _selectedTimeRange,
        forceRefresh: false,
      );

      setState(() {
        _fastSummary = fastSummary;
        _isLoadingSummary = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load summary: $e';
        _isLoadingSummary = false;
      });
    }
  }

  /// Load full analytics data
  Future<void> _loadFullAnalytics() async {
    setState(() {
      _isLoadingAnalytics = true;
    });

    try {
      // Load analytics and full summary (will use cache if available)
      final results = await Future.wait([
        _analyticsService.getAllWebsiteAnalytics(
          timeRange: _selectedTimeRange,
          forceRefresh: false,
        ),
        _analyticsService.getAnalyticsSummary(
          timeRange: _selectedTimeRange,
          forceRefresh: false,
        ),
      ]);

      final analytics = results[0] as List<WebsiteStockAnalytics>;
      final summary = results[1] as Map<String, dynamic>;

      // Filter analytics for free users
      List<WebsiteStockAnalytics> filteredAnalytics = analytics;
      print(
        '🔍 [FullAnalytics] Filtering analytics: isPremium = $_isPremium, total sites = ${analytics.length}',
      );

      if (!_isPremium) {
        final freeSites = [
          'ippodo',
          'marukyu',
          'tokichi',
          'matcha-karu',
          'yoshien',
        ];
        filteredAnalytics =
            analytics
                .where((analytics) => freeSites.contains(analytics.siteKey))
                .toList();
        print(
          '🆓 [FullAnalytics] Free user - filtered to ${filteredAnalytics.length} sites',
        );
      } else {
        print(
          '💎 [FullAnalytics] Premium user - showing all ${analytics.length} sites',
        );
      }

      setState(() {
        _websiteAnalytics = filteredAnalytics;
        _summary = summary;
        _isLoadingAnalytics = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to load full analytics: $e';
        _isLoadingAnalytics = false;
      });
    }
  }

  Future<void> _loadAnalytics() async {
    await _loadProgressively();
  }

  /// Calculate stock percentage for free users based on filtered analytics
  double _calculateFreeUserStockPercentage() {
    if (_websiteAnalytics.isEmpty) return 0.0;

    final totalProducts = _websiteAnalytics.fold<int>(
      0,
      (sum, analytics) => sum + analytics.totalProducts,
    );
    final productsInStock = _websiteAnalytics.fold<int>(
      0,
      (sum, analytics) => sum + analytics.productsInStock,
    );

    if (totalProducts == 0) return 0.0;
    return (productsInStock / totalProducts) * 100;
  }

  Future<void> _forceRefreshAnalytics() async {
    setState(() {
      _isLoadingSummary = true;
      _isLoadingAnalytics = true;
      _error = null;
    });

    try {
      // Clear all relevant caches
      await CacheService.clearCache('website_analytics_$_selectedTimeRange');
      await CacheService.clearCache('analytics_summary_$_selectedTimeRange');
      await CacheService.clearCache('fast_summary_$_selectedTimeRange');

      // Also refresh preload service cache
      await PreloadService.instance.refreshPreloadedData();

      // Force refresh from server/database, bypass cache
      final results = await Future.wait([
        _analyticsService.getAllWebsiteAnalytics(
          timeRange: _selectedTimeRange,
          forceRefresh: true, // Force refresh
        ),
        _analyticsService.getAnalyticsSummary(
          timeRange: _selectedTimeRange,
          forceRefresh: true, // Force refresh
        ),
        _analyticsService.getFastSummary(
          timeRange: _selectedTimeRange,
          forceRefresh: true, // Force refresh
        ),
      ]);

      final analytics = results[0] as List<WebsiteStockAnalytics>;
      final summary = results[1] as Map<String, dynamic>;
      final fastSummary = results[2] as Map<String, dynamic>;

      // Filter analytics for free users
      List<WebsiteStockAnalytics> filteredAnalytics = analytics;
      if (!_isPremium) {
        // Only show analytics for free tier sites
        final freeSites = [
          'ippodo',
          'marukyu',
          'tokichi',
          'matcha-karu',
          'yoshien',
        ];
        filteredAnalytics =
            analytics
                .where((analytics) => freeSites.contains(analytics.siteKey))
                .toList();
      }

      setState(() {
        _websiteAnalytics = filteredAnalytics;
        _summary = summary;
        _fastSummary = fastSummary;
        _isLoadingSummary = false;
        _isLoadingAnalytics = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Failed to refresh analytics: $e';
        _isLoadingSummary = false;
        _isLoadingAnalytics = false;
      });
    }
  }

  void _showTimeRangePicker() {
    // Filter time ranges based on subscription tier
    final availableTimeRanges =
        _isPremium
            ? _timeRanges
            : ['day']; // Only show 7 days option for free users

    showDialog<String>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Select Time Range'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children:
                availableTimeRanges.map((String timeRange) {
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
        _loadProgressively();
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
    // Show loading skeleton if both summary and analytics are loading
    if (_isLoadingSummary && _isLoadingAnalytics) {
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
          SliverToBoxAdapter(
            child:
                _isLoadingAnalytics
                    ? Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Center(child: CircularProgressIndicator()),
                          const SizedBox(height: 16),
                          Text(
                            'Loading detailed analytics...',
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withAlpha(150),
                            ),
                          ),
                        ],
                      ),
                    )
                    : const SizedBox.shrink(),
          ),
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
    // Use fast summary if available, otherwise fall back to full summary
    final summaryData = _fastSummary.isNotEmpty ? _fastSummary : _summary;

    // Calculate free-tier specific numbers
    final totalWebsitesForUser =
        _isPremium
            ? (summaryData['totalWebsites'] ?? 0)
            : 5; // Free tier has 5 available websites

    final activeWebsitesForUser =
        _isPremium
            ? (summaryData['activeWebsites'] ?? 0)
            : _websiteAnalytics.length; // Show actual active free sites

    // Show loading skeleton if no data is available
    if (summaryData.isEmpty && _isLoadingSummary) {
      return Container(
        margin: const EdgeInsets.all(16),
        child: const SkeletonStatsHeader(),
      );
    }

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
                          _isPremium ? 'Overall Summary' : 'Free Tier Summary',
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
                      '$activeWebsitesForUser/$totalWebsitesForUser',
                      Icons.language,
                      Colors.blue,
                    ),
                  ),
                  Expanded(
                    child: _buildSummaryItem(
                      'Products',
                      '${_isPremium ? (summaryData['totalProducts'] ?? 0) : _websiteAnalytics.fold<int>(0, (sum, analytics) => sum + analytics.totalProducts)}',
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
                      '${_isPremium ? (summaryData['overallStockPercentage'] ?? 0).toStringAsFixed(1) : _calculateFreeUserStockPercentage().toStringAsFixed(1)}%',
                      Icons.check_circle,
                      Colors.green,
                    ),
                  ),
                  Expanded(
                    child: _buildSummaryItem(
                      'Updates',
                      '${_isPremium ? (summaryData['totalUpdates'] ?? 0) : _websiteAnalytics.fold<int>(0, (sum, analytics) => sum + analytics.stockUpdates.length)}',
                      Icons.timeline,
                      Colors.orange,
                    ),
                  ),
                ],
              ),
              if (summaryData['mostRecentUpdate'] != null) ...[
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final mostRecentUpdate = _safeParseDateTime(
                      summaryData['mostRecentUpdate'],
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
              if (summaryData['mostActiveWebsite'] != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Most active: ${summaryData['mostActiveWebsite']}',
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
        return _isPremium ? 'Last 24 hours' : 'Last 7 days';
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
