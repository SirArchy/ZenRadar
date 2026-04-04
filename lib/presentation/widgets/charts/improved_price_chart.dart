import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:zenradar/models/price_history.dart';
import 'package:zenradar/models/matcha_product.dart';

class ImprovedPriceChart extends StatelessWidget {
  final List<PriceHistory> priceHistory;
  final String timeRange;
  final String currencySymbol;
  final Color? primaryColor;
  final MatchaProduct?
  product; // Add product to show current price when no history

  const ImprovedPriceChart({
    super.key,
    required this.priceHistory,
    required this.timeRange,
    this.currencySymbol = '€',
    this.primaryColor,
    this.product,
  });

  @override
  Widget build(BuildContext context) {
    if (priceHistory.isEmpty) {
      return _buildEmptyStateWithCurrentPrice(context);
    }

    // Sort by date to ensure proper ordering
    final sortedHistory = List<PriceHistory>.from(priceHistory)
      ..sort((a, b) => a.date.compareTo(b.date));

    // Apply windowing and downsampling based on time range
    final downsampledHistory = _downsampleData(sortedHistory);

    final spots = _generateSpots(downsampledHistory);
    if (spots.isEmpty) {
      return _buildEmptyStateWithCurrentPrice(context);
    }

    final minPrice = downsampledHistory
        .map((h) => h.price)
        .reduce((a, b) => a < b ? a : b);
    final maxPrice = downsampledHistory
        .map((h) => h.price)
        .reduce((a, b) => a > b ? a : b);
    final priceRange = maxPrice - minPrice;

    // Add padding to the Y-axis range (10% on each side)
    final padding = priceRange * 0.1;
    final yMin = (minPrice - padding).clamp(0.0, double.infinity);
    final yMax = maxPrice + padding;

    // For monthly view, add a month header
    if (timeRange == 'month') {
      return _buildMonthlyChartWithHeader(
        context,
        downsampledHistory,
        spots,
        yMin,
        yMax,
      );
    }

    return SizedBox(
      height: 300,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final chartWidth = constraints.maxWidth;
          return LineChart(
            LineChartData(
              gridData: _buildGridData(context, downsampledHistory, yMin, yMax),
              titlesData: _buildTitlesData(
                context,
                downsampledHistory,
                yMin,
                yMax,
                chartWidth,
              ),
              borderData: _buildBorderData(context),
              lineBarsData: [_buildLineBarData(context, spots)],
              lineTouchData: _buildTouchData(context, downsampledHistory),
              minX: spots.first.x,
              maxX: spots.last.x,
              minY: yMin,
              maxY: yMax,
              extraLinesData: _buildExtraLines(
                context,
                downsampledHistory,
                yMin,
                yMax,
              ),
            ),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
      ),
    );
  }

  Widget _buildEmptyStateWithCurrentPrice(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // If we have a product with current price, show it as a flat line
    if (product != null && product!.priceValue != null) {
      return _buildCurrentPriceChart(context);
    }

    return Container(
      height: 300,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.trending_up_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noPriceHistoryAvailable,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.priceTrackingStartsNextScan,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentPriceChart(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final currentPrice = product!.priceValue!;
    final now = DateTime.now();

    // Create time range based on selected period
    DateTime startTime;
    switch (timeRange) {
      case 'day':
      case 'today':
        startTime = now.subtract(const Duration(days: 1));
        break;
      case 'week':
        startTime = now.subtract(const Duration(days: 7));
        break;
      case 'month':
        startTime = now.subtract(const Duration(days: 30));
        break;
      default:
        startTime = product!.firstSeen;
    }

    // Create a flat line for the selected time range at current price
    final spots = [
      FlSpot(startTime.millisecondsSinceEpoch.toDouble(), currentPrice),
      FlSpot(now.millisecondsSinceEpoch.toDouble(), currentPrice),
    ];

    final yMin = (currentPrice * 0.9).clamp(0.0, double.infinity);
    final yMax = currentPrice * 1.1;

    // For monthly view, add a month header
    if (timeRange == 'month') {
      return _buildMonthlyCurrentPriceChart(
        context,
        spots,
        yMin,
        yMax,
        currentPrice,
        startTime,
      );
    }

    return SizedBox(
      height: 300,
      child: Column(
        children: [
          // Message about no price changes
          Container(
            padding: const EdgeInsets.all(12),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primaryContainer.withAlpha(75),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: Theme.of(context).colorScheme.primary.withAlpha(75),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    l10n.noPriceChangesYetCurrentPrice(
                      '${currentPrice.toStringAsFixed(2)}$currencySymbol',
                    ),
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Chart showing flat line
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final chartWidth = constraints.maxWidth;
                return LineChart(
                  LineChartData(
                    gridData: _buildGridDataForFlatLine(
                      context,
                      spots,
                      yMin,
                      yMax,
                    ),
                    titlesData: _buildTitlesDataForFlatLine(
                      context,
                      spots,
                      yMin,
                      yMax,
                      chartWidth,
                    ),
                    borderData: _buildBorderData(context),
                    lineBarsData: [_buildFlatLineBarData(context, spots)],
                    lineTouchData: _buildFlatLineTouchData(
                      context,
                      currentPrice,
                    ),
                    minX: spots.first.x,
                    maxX: spots.last.x,
                    minY: yMin,
                    maxY: yMax,
                  ),
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyCurrentPriceChart(
    BuildContext context,
    List<FlSpot> spots,
    double yMin,
    double yMax,
    double currentPrice,
    DateTime startTime,
  ) {
    final l10n = AppLocalizations.of(context)!;
    // Get the month name from the start time
    final monthName = DateFormat('MMMM yyyy').format(startTime);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Message about no price changes
        Container(
          padding: const EdgeInsets.all(12),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primaryContainer.withAlpha(75),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withAlpha(75),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.info_outline,
                size: 16,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  l10n.noPriceChangesYetCurrentPrice(
                    '${currentPrice.toStringAsFixed(2)}$currencySymbol',
                  ),
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        // Month header
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            monthName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        // Chart
        SizedBox(
          height: 240,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final chartWidth = constraints.maxWidth;
              return LineChart(
                LineChartData(
                  gridData: _buildGridDataForFlatLine(
                    context,
                    spots,
                    yMin,
                    yMax,
                  ),
                  titlesData: _buildTitlesDataForFlatLine(
                    context,
                    spots,
                    yMin,
                    yMax,
                    chartWidth,
                  ),
                  borderData: _buildBorderData(context),
                  lineBarsData: [_buildFlatLineBarData(context, spots)],
                  lineTouchData: _buildFlatLineTouchData(context, currentPrice),
                  minX: spots.first.x,
                  maxX: spots.last.x,
                  minY: yMin,
                  maxY: yMax,
                ),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
          ),
        ),
      ],
    );
  }

  // LTTB keeps trend shape better than simple step sampling.
  List<PriceHistory> _downsampleData(List<PriceHistory> history) {
    final targetPoints = _targetPointCount();
    if (history.length <= targetPoints) return history;

    final sampled = _largestTriangleThreeBuckets(history, targetPoints);
    sampled.sort((a, b) => a.date.compareTo(b.date));
    return sampled;
  }

  int _targetPointCount() {
    switch (timeRange) {
      case 'day':
      case 'today':
        return 28;
      case 'week':
        return 36;
      case 'month':
        return 42;
      case 'all':
      default:
        return 56;
    }
  }

  List<PriceHistory> _largestTriangleThreeBuckets(
    List<PriceHistory> data,
    int threshold,
  ) {
    if (threshold >= data.length || threshold < 3) {
      return data;
    }

    final sampled = <PriceHistory>[];
    final bucketSize = (data.length - 2) / (threshold - 2);
    int a = 0;
    sampled.add(data[a]);

    for (int i = 0; i < threshold - 2; i++) {
      final avgRangeStart = (i + 1) * bucketSize + 1;
      final avgRangeEnd = (i + 2) * bucketSize + 1;
      final avgStart = avgRangeStart.floor().clamp(1, data.length - 1);
      final avgEnd = avgRangeEnd.floor().clamp(1, data.length);

      double avgX = 0;
      double avgY = 0;
      final avgRangeLength = (avgEnd - avgStart).clamp(1, data.length);
      for (int j = avgStart; j < avgEnd; j++) {
        avgX += data[j].date.millisecondsSinceEpoch.toDouble();
        avgY += data[j].price;
      }
      avgX /= avgRangeLength;
      avgY /= avgRangeLength;

      final rangeOffs = (i * bucketSize + 1).floor().clamp(1, data.length - 1);
      final rangeTo = ((i + 1) * bucketSize + 1).floor().clamp(
        1,
        data.length - 1,
      );

      final pointAX = data[a].date.millisecondsSinceEpoch.toDouble();
      final pointAY = data[a].price;

      double maxArea = -1;
      int nextA = rangeOffs;

      for (int j = rangeOffs; j <= rangeTo; j++) {
        final pointX = data[j].date.millisecondsSinceEpoch.toDouble();
        final pointY = data[j].price;
        final area =
            ((pointAX - avgX) * (pointY - pointAY) -
                    (pointAX - pointX) * (avgY - pointAY))
                .abs() *
            0.5;

        if (area > maxArea) {
          maxArea = area;
          nextA = j;
        }
      }

      sampled.add(data[nextA]);
      a = nextA;
    }

    sampled.add(data.last);
    return sampled;
  }

  List<FlSpot> _generateSpots(List<PriceHistory> history) {
    return history
        .map((h) => FlSpot(h.date.millisecondsSinceEpoch.toDouble(), h.price))
        .toList();
  }

  FlGridData _buildGridData(
    BuildContext context,
    List<PriceHistory> history,
    double yMin,
    double yMax,
  ) {
    return FlGridData(
      show: true,
      drawVerticalLine: true,
      drawHorizontalLine: true,
      horizontalInterval: _getPriceInterval(yMin, yMax),
      verticalInterval: _getTimeInterval(history, 5),
      getDrawingHorizontalLine:
          (value) => FlLine(
            color: Theme.of(context).colorScheme.outline.withAlpha(30),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
      getDrawingVerticalLine:
          (value) => FlLine(
            color: Theme.of(context).colorScheme.outline.withAlpha(30),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
    );
  }

  FlTitlesData _buildTitlesData(
    BuildContext context,
    List<PriceHistory> history,
    double yMin,
    double yMax,
    double chartWidth,
  ) {
    final bottomLabelCount = _idealBottomLabelCount(chartWidth);
    return FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 38,
          interval: _getTimeInterval(history, bottomLabelCount),
          getTitlesWidget:
              (value, meta) => _buildDateTitle(context, value, meta),
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 66,
          interval: _getPriceInterval(yMin, yMax),
          getTitlesWidget:
              (value, meta) => _buildPriceTitle(context, value, meta),
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  Widget _buildDateTitle(BuildContext context, double value, TitleMeta meta) {
    if (meta.axisSide != AxisSide.bottom) return const SizedBox.shrink();

    final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
    final text = _formatDateForAxis(date);

    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Container(
        padding: const EdgeInsets.only(top: 6),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildPriceTitle(BuildContext context, double value, TitleMeta meta) {
    if (meta.axisSide != AxisSide.left) return const SizedBox.shrink();

    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Container(
        padding: const EdgeInsets.only(right: 6),
        child: Text(
          '${value.toStringAsFixed(value >= 100 ? 0 : 1)}$currencySymbol',
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  FlBorderData _buildBorderData(BuildContext context) {
    return FlBorderData(
      show: true,
      border: Border.all(
        color: Theme.of(context).colorScheme.outline.withAlpha(50),
        width: 1,
      ),
    );
  }

  LineChartBarData _buildLineBarData(BuildContext context, List<FlSpot> spots) {
    final color = primaryColor ?? Theme.of(context).colorScheme.primary;

    return LineChartBarData(
      spots: spots,
      isCurved: true,
      curveSmoothness: 0.3,
      color: color,
      barWidth: 3,
      isStrokeCapRound: true,
      dotData: FlDotData(
        show: spots.length <= 20, // Only show dots for smaller datasets
        getDotPainter:
            (spot, percent, barData, index) => FlDotCirclePainter(
              radius: 4,
              color: color,
              strokeWidth: 2,
              strokeColor: Theme.of(context).colorScheme.surface,
            ),
      ),
      belowBarData: BarAreaData(
        show: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            color.withAlpha(80),
            color.withAlpha(20),
            color.withAlpha(5),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      shadow: Shadow(
        color: color.withAlpha(50),
        blurRadius: 3,
        offset: const Offset(0, 2),
      ),
    );
  }

  LineTouchData _buildTouchData(
    BuildContext context,
    List<PriceHistory> history,
  ) {
    return LineTouchData(
      enabled: true,
      touchTooltipData: LineTouchTooltipData(
        tooltipRoundedRadius: 8,
        tooltipPadding: const EdgeInsets.all(12),
        tooltipMargin: 8,
        getTooltipColor:
            (touchedSpot) =>
                Theme.of(context).colorScheme.surfaceContainerHighest,
        tooltipBorder: BorderSide(
          color: Theme.of(context).colorScheme.outline.withAlpha(100),
          width: 1,
        ),
        getTooltipItems:
            (touchedSpots) =>
                touchedSpots.map((spot) {
                  final date = DateTime.fromMillisecondsSinceEpoch(
                    spot.x.toInt(),
                  );
                  final price = spot.y;

                  return LineTooltipItem(
                    '${DateFormat('MMM dd, yyyy').format(date)}\n${price.toStringAsFixed(2)}$currencySymbol',
                    TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  );
                }).toList(),
      ),
      touchCallback: (FlTouchEvent event, LineTouchResponse? touchResponse) {
        // Add haptic feedback on touch
        if (event is FlTapUpEvent &&
            touchResponse?.lineBarSpots?.isNotEmpty == true) {
          // You can add haptic feedback here if needed
        }
      },
    );
  }

  ExtraLinesData _buildExtraLines(
    BuildContext context,
    List<PriceHistory> history,
    double yMin,
    double yMax,
  ) {
    if (history.length < 2) return ExtraLinesData();

    // Calculate average price line
    final avgPrice =
        history.map((h) => h.price).reduce((a, b) => a + b) / history.length;

    return ExtraLinesData(
      horizontalLines: [
        HorizontalLine(
          y: avgPrice,
          color: Theme.of(context).colorScheme.secondary.withAlpha(150),
          strokeWidth: 1.5,
          dashArray: [8, 4],
          label: HorizontalLineLabel(
            show: false,
            labelResolver:
                (line) => AppLocalizations.of(context)!.averagePriceLabel(
                  '${avgPrice.toStringAsFixed(2)}$currencySymbol',
                ),
            style: TextStyle(
              color: Theme.of(context).colorScheme.secondary,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
            alignment: Alignment.topRight,
            padding: const EdgeInsets.only(right: 8, bottom: 4),
          ),
        ),
      ],
    );
  }

  int _idealBottomLabelCount(double chartWidth) {
    if (chartWidth < 300) return 3;
    if (chartWidth < 420) return 4;
    return 5;
  }

  double _getTimeInterval(List<PriceHistory> history, int targetLabels) {
    if (history.length <= 1) {
      return const Duration(days: 1).inMilliseconds.toDouble();
    }

    final totalDuration = history.last.date.difference(history.first.date);
    final calculatedInterval = totalDuration.inMilliseconds / targetLabels;

    switch (timeRange) {
      case 'day':
      case 'today':
        if (totalDuration.inHours <= 6) {
          return const Duration(hours: 1).inMilliseconds.toDouble();
        } else if (totalDuration.inHours <= 12) {
          return const Duration(hours: 3).inMilliseconds.toDouble();
        } else {
          return const Duration(hours: 6).inMilliseconds.toDouble();
        }
      case 'week':
        if (totalDuration.inDays <= 3) {
          return const Duration(days: 1).inMilliseconds.toDouble();
        } else {
          return const Duration(days: 2).inMilliseconds.toDouble();
        }
      case 'month':
        if (totalDuration.inDays <= 14) {
          return const Duration(days: 3).inMilliseconds.toDouble();
        } else {
          return const Duration(days: 7).inMilliseconds.toDouble();
        }
      case 'all':
      default:
        if (totalDuration.inDays <= 7) {
          return const Duration(days: 2).inMilliseconds.toDouble();
        } else if (totalDuration.inDays <= 30) {
          return const Duration(days: 7).inMilliseconds.toDouble();
        } else if (totalDuration.inDays <= 90) {
          return const Duration(days: 20).inMilliseconds.toDouble();
        } else if (totalDuration.inDays <= 365) {
          return const Duration(days: 60).inMilliseconds.toDouble();
        } else {
          // For very long periods, use calculated interval with minimum of 30 days
          final minInterval =
              const Duration(days: 30).inMilliseconds.toDouble();
          return calculatedInterval > minInterval
              ? calculatedInterval
              : minInterval;
        }
    }
  }

  double _getPriceInterval(double yMin, double yMax) {
    final range = yMax - yMin;
    if (range <= 0) return 1.0;

    // Aim for 4-6 price labels
    final targetLabels = 5;
    final rawInterval = range / targetLabels;

    // Round to nice numbers
    if (rawInterval >= 100) return (rawInterval / 100).round() * 100.0;
    if (rawInterval >= 50) return (rawInterval / 50).round() * 50.0;
    if (rawInterval >= 10) return (rawInterval / 10).round() * 10.0;
    if (rawInterval >= 5) return (rawInterval / 5).round() * 5.0;
    if (rawInterval >= 1) return rawInterval.round().toDouble();
    if (rawInterval >= 0.5) return 0.5;
    if (rawInterval >= 0.1) return 0.1;
    return 0.01;
  }

  String _formatDateForAxis(DateTime date) {
    switch (timeRange) {
      case 'day':
      case 'today':
        return DateFormat('HH:mm').format(date);
      case 'week':
        return DateFormat('MM/dd').format(date);
      case 'month':
        return DateFormat('d').format(date); // Show just day number
      default:
        return DateFormat('MM/dd').format(date);
    }
  }

  Widget _buildMonthlyChartWithHeader(
    BuildContext context,
    List<PriceHistory> downsampledHistory,
    List<FlSpot> spots,
    double yMin,
    double yMax,
  ) {
    // Get the month name from the first data point
    final monthName =
        downsampledHistory.isNotEmpty
            ? DateFormat('MMMM yyyy').format(downsampledHistory.first.date)
            : DateFormat('MMMM yyyy').format(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Month header
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            monthName,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        // Chart
        SizedBox(
          height: 280,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final chartWidth = constraints.maxWidth;
              return LineChart(
                LineChartData(
                  gridData: _buildGridData(
                    context,
                    downsampledHistory,
                    yMin,
                    yMax,
                  ),
                  titlesData: _buildTitlesData(
                    context,
                    downsampledHistory,
                    yMin,
                    yMax,
                    chartWidth,
                  ),
                  borderData: _buildBorderData(context),
                  lineBarsData: [_buildLineBarData(context, spots)],
                  lineTouchData: _buildTouchData(context, downsampledHistory),
                  minX: spots.first.x,
                  maxX: spots.last.x,
                  minY: yMin,
                  maxY: yMax,
                  extraLinesData: _buildExtraLines(
                    context,
                    downsampledHistory,
                    yMin,
                    yMax,
                  ),
                ),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
              );
            },
          ),
        ),
      ],
    );
  }

  // Methods for flat line chart (current price with no changes)
  FlTitlesData _buildTitlesDataForFlatLine(
    BuildContext context,
    List<FlSpot> spots,
    double yMin,
    double yMax,
    double chartWidth,
  ) {
    final bottomLabelCount = _idealBottomLabelCount(chartWidth);
    return FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 38,
          interval: _getTimeIntervalForFlatLine(spots, bottomLabelCount),
          getTitlesWidget:
              (value, meta) => _buildDateTitle(context, value, meta),
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 66,
          interval: _getPriceInterval(yMin, yMax),
          getTitlesWidget:
              (value, meta) => _buildPriceTitle(context, value, meta),
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  LineChartBarData _buildFlatLineBarData(
    BuildContext context,
    List<FlSpot> spots,
  ) {
    final color = primaryColor ?? Theme.of(context).colorScheme.primary;

    return LineChartBarData(
      spots: spots,
      isCurved: false,
      color: color.withAlpha(200),
      barWidth: 2,
      isStrokeCapRound: true,
      dashArray: [8, 4], // Dashed line to indicate no changes
      dotData: FlDotData(show: false),
      belowBarData: BarAreaData(show: true, color: color.withAlpha(25)),
    );
  }

  LineTouchData _buildFlatLineTouchData(
    BuildContext context,
    double currentPrice,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return LineTouchData(
      touchTooltipData: LineTouchTooltipData(
        getTooltipColor:
            (touchedSpot) =>
                Theme.of(context).colorScheme.surfaceContainerHighest,
        tooltipBorder: BorderSide(
          color: Theme.of(context).colorScheme.outline.withAlpha(125),
          width: 1,
        ),
        getTooltipItems: (touchedSpots) {
          return touchedSpots.map((spot) {
            final date = DateTime.fromMillisecondsSinceEpoch(spot.x.toInt());
            return LineTooltipItem(
              '${DateFormat('MMM dd, yyyy').format(date)}\n${l10n.currentPriceLabel(currentPrice.toStringAsFixed(2) + currencySymbol)}\n${l10n.noPriceChangesYetShort}',
              TextStyle(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            );
          }).toList();
        },
      ),
    );
  }

  FlGridData _buildGridDataForFlatLine(
    BuildContext context,
    List<FlSpot> spots,
    double yMin,
    double yMax,
  ) {
    return FlGridData(
      show: true,
      drawVerticalLine: true,
      drawHorizontalLine: true,
      horizontalInterval: _getPriceInterval(yMin, yMax),
      verticalInterval: _getTimeIntervalForFlatLine(spots, 5),
      getDrawingHorizontalLine:
          (value) => FlLine(
            color: Theme.of(context).colorScheme.outline.withAlpha(30),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
      getDrawingVerticalLine:
          (value) => FlLine(
            color: Theme.of(context).colorScheme.outline.withAlpha(30),
            strokeWidth: 1,
            dashArray: [4, 4],
          ),
    );
  }

  double _getTimeIntervalForFlatLine(List<FlSpot> spots, int targetLabels) {
    if (spots.length < 2) {
      return const Duration(days: 1).inMilliseconds.toDouble();
    }

    final totalDuration = spots.last.x - spots.first.x;
    return totalDuration / targetLabels;
  }
}
