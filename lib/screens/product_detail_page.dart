import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/matcha_product.dart';
import '../models/price_history.dart';
import '../models/stock_history.dart';
import '../services/database_service.dart';
import '../widgets/category_icon.dart';
import '../widgets/stock_status_chart.dart';

class ProductDetailPage extends StatefulWidget {
  final MatchaProduct product;

  const ProductDetailPage({super.key, required this.product});

  @override
  State<ProductDetailPage> createState() => _ProductDetailPageState();
}

class _ProductDetailPageState extends State<ProductDetailPage> {
  PriceAnalytics? _priceAnalytics;
  StockAnalytics? _stockAnalytics;
  bool _isLoading = true;
  String _selectedTimeRange = 'month'; // day, week, month, all
  DateTime? _selectedDay;

  final dynamic _db = DatabaseService.platformService;

  @override
  void initState() {
    super.initState();
    _loadPriceHistory();
  }

  Future<void> _loadPriceHistory() async {
    setState(() => _isLoading = true);

    try {
      final analytics = await _db.getPriceAnalyticsForProduct(
        widget.product.id,
      );
      final stockAnalytics = await _db.getStockAnalyticsForProduct(
        widget.product.id,
      );
      setState(() {
        _priceAnalytics = analytics;
        _stockAnalytics = stockAnalytics;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading analytics: $e')));
      }
    }
  }

  List<PriceHistory> get _filteredHistory {
    if (_priceAnalytics == null) return [];

    switch (_selectedTimeRange) {
      case 'day':
        return _priceAnalytics!.dailyAggregatedHistory.where((h) {
          return h.date.isAfter(
            DateTime.now().subtract(const Duration(days: 7)),
          );
        }).toList();
      case 'week':
        return _priceAnalytics!.weeklyAggregatedHistory.where((h) {
          return h.date.isAfter(
            DateTime.now().subtract(const Duration(days: 30)),
          );
        }).toList();
      case 'month':
        return _priceAnalytics!.monthlyAggregatedHistory.where((h) {
          return h.date.isAfter(
            DateTime.now().subtract(const Duration(days: 365)),
          );
        }).toList();
      default:
        return _priceAnalytics!.dailyAggregatedHistory;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.product.name, style: const TextStyle(fontSize: 18)),
        actions: [
          IconButton(
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _launchUrl(widget.product.url),
          ),
        ],
      ),
      body:
          _isLoading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildProductHeader(),
                    const SizedBox(height: 24),
                    _buildPriceOverview(),
                    const SizedBox(height: 24),
                    _buildPriceChart(),
                    const SizedBox(height: 24),
                    _buildStockChart(),
                    const SizedBox(height: 24),
                    _buildProductDetails(),
                  ],
                ),
              ),
    );
  }

  Widget _buildProductHeader() {
    final bool isUnavailable =
        !widget.product.isInStock || widget.product.isDiscontinued;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CategoryIcon(
                  category: widget.product.category,
                  size: 48,
                  color:
                      isUnavailable
                          ? Theme.of(
                            context,
                          ).colorScheme.onSurface.withAlpha(100)
                          : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.product.name,
                        style: Theme.of(
                          context,
                        ).textTheme.headlineSmall?.copyWith(
                          decoration:
                              widget.product.isDiscontinued
                                  ? TextDecoration.lineThrough
                                  : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.store,
                            size: 16,
                            color: Theme.of(
                              context,
                            ).colorScheme.onSurface.withAlpha(150),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            widget.product.site,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurface.withAlpha(150),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                _buildStatusChip(),
              ],
            ),
            if (widget.product.price != null) ...[
              const SizedBox(height: 12),
              Text(
                'Current Price: ${widget.product.price}',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatusChip() {
    Color chipColor;
    IconData chipIcon;
    String chipText;

    if (widget.product.isDiscontinued) {
      chipColor = Theme.of(context).colorScheme.outline;
      chipIcon = Icons.not_interested;
      chipText = 'Discontinued';
    } else if (widget.product.isInStock) {
      chipColor = Theme.of(context).colorScheme.primary;
      chipIcon = Icons.check_circle;
      chipText = 'In Stock';
    } else {
      chipColor = Theme.of(context).colorScheme.error;
      chipIcon = Icons.cancel;
      chipText = 'Out of Stock';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: chipColor,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            chipIcon,
            size: 16,
            color: Theme.of(context).colorScheme.onPrimary,
          ),
          const SizedBox(width: 4),
          Text(
            chipText,
            style: TextStyle(
              color: Theme.of(context).colorScheme.onPrimary,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceOverview() {
    if (_priceAnalytics == null || _priceAnalytics!.totalDataPoints == 0) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(
                Icons.trending_up,
                size: 48,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(75),
              ),
              const SizedBox(height: 8),
              Text(
                'No Price History Available',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                'Price tracking will begin with the next scan',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Price Analytics',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Current',
                    '${_priceAnalytics!.currentPrice.toStringAsFixed(2)}€',
                    Icons.euro,
                    Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Lowest',
                    '${_priceAnalytics!.lowestPrice?.toStringAsFixed(2) ?? '-'}€',
                    Icons.trending_down,
                    Colors.green,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _buildStatCard(
                    'Highest',
                    '${_priceAnalytics!.highestPrice?.toStringAsFixed(2) ?? '-'}€',
                    Icons.trending_up,
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildStatCard(
                    'Average',
                    '${_priceAnalytics!.averagePrice?.toStringAsFixed(2) ?? '-'}€',
                    Icons.analytics,
                    Theme.of(context).colorScheme.secondary,
                  ),
                ),
              ],
            ),
            if (_priceAnalytics!.priceChange != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color:
                      _priceAnalytics!.hasPriceIncreased
                          ? Colors.red.withAlpha(25)
                          : _priceAnalytics!.hasPriceDecreased
                          ? Colors.green.withAlpha(25)
                          : Colors.grey.withAlpha(25),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      _priceAnalytics!.hasPriceIncreased
                          ? Icons.arrow_upward
                          : _priceAnalytics!.hasPriceDecreased
                          ? Icons.arrow_downward
                          : Icons.horizontal_rule,
                      color:
                          _priceAnalytics!.hasPriceIncreased
                              ? Colors.red
                              : _priceAnalytics!.hasPriceDecreased
                              ? Colors.green
                              : Colors.grey,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Price change: ${_priceAnalytics!.priceChange!.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color:
                            _priceAnalytics!.hasPriceIncreased
                                ? Colors.red
                                : _priceAnalytics!.hasPriceDecreased
                                ? Colors.green
                                : Colors.grey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPriceChart() {
    if (_priceAnalytics == null || _filteredHistory.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            height: 200,
            child: Center(
              child: Text(
                'No price data available for selected time range',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Price History',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(value: 'day', label: Text('7D')),
                    ButtonSegment(value: 'week', label: Text('1M')),
                    ButtonSegment(value: 'month', label: Text('1Y')),
                    ButtonSegment(value: 'all', label: Text('All')),
                  ],
                  selected: {_selectedTimeRange},
                  onSelectionChanged: (Set<String> selection) {
                    setState(() {
                      _selectedTimeRange = selection.first;
                    });
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 250,
              child: LineChart(
                LineChartData(
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: true,
                    horizontalInterval: 1,
                    verticalInterval: 1,
                    getDrawingHorizontalLine: (value) {
                      return FlLine(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withAlpha(50),
                        strokeWidth: 1,
                      );
                    },
                    getDrawingVerticalLine: (value) {
                      return FlLine(
                        color: Theme.of(
                          context,
                        ).colorScheme.outline.withAlpha(50),
                        strokeWidth: 1,
                      );
                    },
                  ),
                  titlesData: FlTitlesData(
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 30,
                        interval: _getDateInterval(),
                        getTitlesWidget: (value, meta) {
                          final date = DateTime.fromMillisecondsSinceEpoch(
                            value.toInt(),
                          );
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              _formatDateForAxis(date),
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (value, meta) {
                          return SideTitleWidget(
                            axisSide: meta.axisSide,
                            child: Text(
                              '${value.toStringAsFixed(0)}€',
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  borderData: FlBorderData(
                    show: true,
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withAlpha(50),
                    ),
                  ),
                  lineBarsData: [
                    LineChartBarData(
                      spots:
                          _filteredHistory.map((history) {
                            return FlSpot(
                              history.date.millisecondsSinceEpoch.toDouble(),
                              history.price,
                            );
                          }).toList(),
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      isStrokeCapRound: true,
                      dotData: FlDotData(
                        show: _filteredHistory.length <= 20,
                        getDotPainter:
                            (spot, percent, barData, index) =>
                                FlDotCirclePainter(
                                  radius: 3,
                                  color: Theme.of(context).colorScheme.primary,
                                  strokeWidth: 2,
                                  strokeColor:
                                      Theme.of(context).colorScheme.surface,
                                ),
                      ),
                      belowBarData: BarAreaData(
                        show: true,
                        color: Theme.of(
                          context,
                        ).colorScheme.primary.withAlpha(25),
                      ),
                    ),
                  ],
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                        return touchedBarSpots.map((barSpot) {
                          final date = DateTime.fromMillisecondsSinceEpoch(
                            barSpot.x.toInt(),
                          );
                          return LineTooltipItem(
                            '${DateFormat('MMM dd, yyyy').format(date)}\n${barSpot.y.toStringAsFixed(2)}€',
                            TextStyle(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        }).toList();
                      },
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  double? _getDateInterval() {
    if (_filteredHistory.isEmpty) return null;

    final totalDuration = _filteredHistory.last.date.difference(
      _filteredHistory.first.date,
    );

    switch (_selectedTimeRange) {
      case 'day':
        return const Duration(days: 1).inMilliseconds.toDouble();
      case 'week':
        return const Duration(days: 3).inMilliseconds.toDouble();
      case 'month':
        return const Duration(days: 30).inMilliseconds.toDouble();
      default:
        return (totalDuration.inMilliseconds / 6).toDouble();
    }
  }

  String _formatDateForAxis(DateTime date) {
    switch (_selectedTimeRange) {
      case 'day':
        return DateFormat('MM/dd').format(date);
      case 'week':
        return DateFormat('MM/dd').format(date);
      case 'month':
        return DateFormat('MMM').format(date);
      default:
        return DateFormat('MM/yy').format(date);
    }
  }

  Widget _buildProductDetails() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Product Details',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            _buildDetailRow('Site', widget.product.site),
            _buildDetailRow('Category', widget.product.category ?? 'Unknown'),
            if (widget.product.weight != null)
              _buildDetailRow('Weight', '${widget.product.weight}g'),
            if (widget.product.currency != null)
              _buildDetailRow('Currency', widget.product.currency!),
            _buildDetailRow(
              'First Seen',
              DateFormat('MMM dd, yyyy HH:mm').format(widget.product.firstSeen),
            ),
            _buildDetailRow(
              'Last Checked',
              DateFormat(
                'MMM dd, yyyy HH:mm',
              ).format(widget.product.lastChecked),
            ),
            if (_priceAnalytics != null && _priceAnalytics!.totalDataPoints > 0)
              _buildDetailRow(
                'Price Data Points',
                '${_priceAnalytics!.totalDataPoints}',
              ),
            if (widget.product.description != null) ...[
              const SizedBox(height: 8),
              Text(
                'Description',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 4),
              Text(
                widget.product.description!,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(200),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w500,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(175),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w400),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockChart() {
    if (_isLoading) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }

    final stockAnalytics = _stockAnalytics;
    if (stockAnalytics == null || stockAnalytics.statusPoints.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.inventory_2,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Stock History',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Text('No stock history available yet'),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.inventory_2,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 12),
                Text(
                  'Stock History',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const Spacer(),
                PopupMenuButton<String>(
                  initialValue: _selectedTimeRange,
                  onSelected: (value) {
                    setState(() {
                      _selectedTimeRange = value;
                      if (value == 'day') {
                        _selectedDay = DateTime.now();
                      } else {
                        _selectedDay = null;
                      }
                    });
                  },
                  itemBuilder:
                      (context) => [
                        const PopupMenuItem(value: 'day', child: Text('Today')),
                        const PopupMenuItem(
                          value: 'week',
                          child: Text('This Week'),
                        ),
                        const PopupMenuItem(
                          value: 'month',
                          child: Text('This Month'),
                        ),
                        const PopupMenuItem(
                          value: 'all',
                          child: Text('All Time'),
                        ),
                      ],
                  child: Chip(
                    label: Text(_getTimeRangeLabel()),
                    avatar: const Icon(Icons.access_time, size: 16),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Stock Status Summary
            Row(
              children: [
                Expanded(
                  child: _buildStockStat(
                    'Availability',
                    '${stockAnalytics.availabilityPercentage.toStringAsFixed(1)}%',
                    Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStockStat(
                    'Volatility',
                    stockAnalytics.isVolatileStock ? 'High' : 'Stable',
                    stockAnalytics.isVolatileStock ? Colors.red : Colors.green,
                  ),
                ),
                Expanded(
                  child: _buildStockStat(
                    'Trend',
                    stockAnalytics.currentTrend,
                    Colors.blue,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Chart or Grid based on time range
            if (_selectedTimeRange == 'day' && _selectedDay != null)
              FutureBuilder<List<StockStatusPoint>>(
                future: _getStockHistoryForDay(_selectedDay!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (snapshot.hasError || !snapshot.hasData) {
                    return const Center(
                      child: Text('Failed to load daily stock data'),
                    );
                  }

                  return StockStatusGrid(
                    stockPoints: snapshot.data!,
                    selectedDay: _selectedDay!,
                  );
                },
              )
            else
              StockStatusChart(
                stockPoints: _getFilteredStockPoints(),
                timeRange: _selectedTimeRange,
              ),

            // Day picker for daily view
            if (_selectedTimeRange == 'day') ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  IconButton(
                    onPressed:
                        _selectedDay != null
                            ? () => setState(() {
                              _selectedDay = _selectedDay!.subtract(
                                const Duration(days: 1),
                              );
                            })
                            : null,
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Center(
                      child: TextButton(
                        onPressed: () => _selectDate(),
                        child: Text(
                          _selectedDay != null
                              ? DateFormat('MMM dd, yyyy').format(_selectedDay!)
                              : 'Select Date',
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed:
                        _selectedDay != null &&
                                _selectedDay!.isBefore(
                                  DateTime.now().subtract(
                                    const Duration(days: 1),
                                  ),
                                )
                            ? () => setState(() {
                              _selectedDay = _selectedDay!.add(
                                const Duration(days: 1),
                              );
                            })
                            : null,
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStockStat(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(75)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(175),
            ),
          ),
        ],
      ),
    );
  }

  String _getTimeRangeLabel() {
    switch (_selectedTimeRange) {
      case 'day':
        return 'Today';
      case 'week':
        return 'This Week';
      case 'month':
        return 'This Month';
      case 'all':
        return 'All Time';
      default:
        return 'All Time';
    }
  }

  List<StockStatusPoint> _getFilteredStockPoints() {
    final stockAnalytics = _stockAnalytics;
    if (stockAnalytics == null) return [];

    final now = DateTime.now();
    DateTime cutoffDate;

    switch (_selectedTimeRange) {
      case 'day':
        cutoffDate = now.subtract(const Duration(days: 1));
        break;
      case 'week':
        cutoffDate = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        cutoffDate = now.subtract(const Duration(days: 30));
        break;
      default:
        return stockAnalytics.statusPoints;
    }

    return stockAnalytics.statusPoints
        .where((point) => point.timestamp.isAfter(cutoffDate))
        .toList();
  }

  Future<List<StockStatusPoint>> _getStockHistoryForDay(DateTime day) async {
    try {
      return await _db.getStockHistoryForDay(widget.product.id, day);
    } catch (e) {
      return [];
    }
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDay ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      setState(() {
        _selectedDay = picked;
      });
    }
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not launch $url')));
      }
    }
  }
}
