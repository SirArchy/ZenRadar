import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:zenradar/models/stock_history.dart';

class ImprovedStockChart extends StatelessWidget {
  final List<StockStatusPoint> stockPoints;
  final String timeRange;
  final DateTime? selectedDay;

  const ImprovedStockChart({
    super.key,
    required this.stockPoints,
    this.timeRange = 'day',
    this.selectedDay,
  });

  @override
  Widget build(BuildContext context) {
    if (stockPoints.isEmpty) {
      return _buildEmptyState(context);
    }

    // Sort by timestamp to ensure proper ordering
    final sortedPoints = List<StockStatusPoint>.from(stockPoints)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // Handle single data point case
    if (sortedPoints.length == 1) {
      return _buildSinglePointState(context, sortedPoints.first);
    }

    // Apply downsampling for better performance and cleaner display
    final downsampledPoints = _downsampleStockData(sortedPoints);

    // Ensure we have at least 2 points for a proper chart
    if (downsampledPoints.length < 2) {
      return _buildInsufficientDataState(context, downsampledPoints);
    }

    // For monthly view, add a month header
    if (timeRange == 'month') {
      return _buildMonthlyChartWithHeader(context, downsampledPoints);
    }

    return SizedBox(
      height: 280,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final chartWidth = constraints.maxWidth;
          return LineChart(
            LineChartData(
              gridData: _buildGridData(context, downsampledPoints, chartWidth),
              titlesData: _buildTitlesData(
                context,
                downsampledPoints,
                chartWidth,
              ),
              borderData: _buildBorderData(context),
              lineBarsData: [_buildStockLineData(context, downsampledPoints)],
              lineTouchData: _buildTouchData(context, downsampledPoints),
              minX:
                  downsampledPoints.first.timestamp.millisecondsSinceEpoch
                      .toDouble(),
              maxX:
                  downsampledPoints.last.timestamp.millisecondsSinceEpoch
                      .toDouble(),
              minY: -0.1,
              maxY: 1.1,
              extraLinesData: _buildStockLevels(context),
            ),
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          );
        },
      ),
    );
  }

  // Keep structural transitions, then window-sample for stable rendering.
  List<StockStatusPoint> _downsampleStockData(List<StockStatusPoint> points) {
    final compressed = _compressTransitions(points);
    final targetPoints = _targetPointCount();
    if (compressed.length <= targetPoints) {
      return compressed;
    }

    final startMs = compressed.first.timestamp.millisecondsSinceEpoch;
    final endMs = compressed.last.timestamp.millisecondsSinceEpoch;
    final durationMs = (endMs - startMs).clamp(1, 1 << 31);
    final bucketMs = (durationMs / targetPoints).ceil();

    final windowed = <StockStatusPoint>[compressed.first];
    int bucketStart = startMs;
    int index = 0;

    while (bucketStart <= endMs && index < compressed.length) {
      final bucketEnd = bucketStart + bucketMs;
      final bucket = <StockStatusPoint>[];

      while (index < compressed.length) {
        final ms = compressed[index].timestamp.millisecondsSinceEpoch;
        if (ms < bucketEnd) {
          bucket.add(compressed[index]);
          index++;
        } else {
          break;
        }
      }

      if (bucket.isNotEmpty) {
        final middle = bucket[bucket.length ~/ 2];
        if (windowed.last.timestamp != middle.timestamp) {
          windowed.add(middle);
        }
        final lastInBucket = bucket.last;
        if (windowed.last.timestamp != lastInBucket.timestamp) {
          windowed.add(lastInBucket);
        }
      }

      bucketStart = bucketEnd;
    }

    if (windowed.last.timestamp != compressed.last.timestamp) {
      windowed.add(compressed.last);
    }

    return _compressTransitions(windowed);
  }

  List<StockStatusPoint> _compressTransitions(List<StockStatusPoint> points) {
    if (points.length <= 2) return points;

    final compressed = <StockStatusPoint>[points.first];
    for (int i = 1; i < points.length - 1; i++) {
      if (points[i].isInStock != compressed.last.isInStock) {
        compressed.add(points[i]);
      }
    }
    if (compressed.last.timestamp != points.last.timestamp) {
      compressed.add(points.last);
    }
    return compressed;
  }

  int _targetPointCount() {
    switch (timeRange) {
      case 'day':
      case 'today':
        return 30;
      case 'week':
        return 36;
      case 'month':
        return 40;
      case 'all':
      default:
        return 52;
    }
  }

  Widget _buildEmptyState(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height: 280,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.noStockHistoryAvailable,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.stockTrackingStartsNextScan,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSinglePointState(BuildContext context, StockStatusPoint point) {
    final l10n = AppLocalizations.of(context)!;
    final isInStock = point.isInStock;
    final statusColor = isInStock ? Colors.green : Colors.red;
    final statusIcon = isInStock ? Icons.check_circle : Icons.cancel;
    final statusText = isInStock ? l10n.inStock : l10n.outOfStock;

    return Container(
      height: 280,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(statusIcon, size: 64, color: statusColor),
          const SizedBox(height: 16),
          Text(
            statusText,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: statusColor,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.singleDataPointFrom(
              DateFormat('MMM dd, HH:mm').format(point.timestamp),
            ),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.moreDataAvailableAfterScans,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInsufficientDataState(
    BuildContext context,
    List<StockStatusPoint> points,
  ) {
    final l10n = AppLocalizations.of(context)!;
    return Container(
      height: 280,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.trending_up,
            size: 64,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
          ),
          const SizedBox(height: 16),
          Text(
            l10n.insufficientDataForChart,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.onlyDataPointsAvailable(points.length),
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.chartRequiresAtLeastTwoPoints,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyChartWithHeader(
    BuildContext context,
    List<StockStatusPoint> downsampledPoints,
  ) {
    // Get the month name from the first point
    final monthName =
        downsampledPoints.isNotEmpty
            ? DateFormat('MMMM yyyy').format(downsampledPoints.first.timestamp)
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
          height: 260,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final chartWidth = constraints.maxWidth;
              return LineChart(
                LineChartData(
                  gridData: _buildGridData(
                    context,
                    downsampledPoints,
                    chartWidth,
                  ),
                  titlesData: _buildTitlesData(
                    context,
                    downsampledPoints,
                    chartWidth,
                  ),
                  borderData: _buildBorderData(context),
                  lineBarsData: [
                    _buildStockLineData(context, downsampledPoints),
                  ],
                  lineTouchData: _buildTouchData(context, downsampledPoints),
                  minX:
                      downsampledPoints.first.timestamp.millisecondsSinceEpoch
                          .toDouble(),
                  maxX:
                      downsampledPoints.last.timestamp.millisecondsSinceEpoch
                          .toDouble(),
                  minY: -0.1,
                  maxY: 1.1,
                  extraLinesData: _buildStockLevels(context),
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

  FlGridData _buildGridData(
    BuildContext context,
    List<StockStatusPoint> points,
    double chartWidth,
  ) {
    final interval = _getTimeInterval(
      points,
      _idealBottomLabelCount(chartWidth),
    );
    return FlGridData(
      show: true,
      drawVerticalLine: true,
      drawHorizontalLine: false, // No horizontal lines for stock chart
      verticalInterval: interval,
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
    List<StockStatusPoint> points,
    double chartWidth,
  ) {
    final interval = _getTimeInterval(
      points,
      _idealBottomLabelCount(chartWidth),
    );
    return FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 38,
          interval: interval,
          getTitlesWidget:
              (value, meta) => _buildTimeTitle(context, value, meta),
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 70,
          interval: 1.0, // Only show at Y=0 and Y=1
          getTitlesWidget:
              (value, meta) => _buildStockTitle(context, value, meta),
        ),
      ),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  Widget _buildTimeTitle(BuildContext context, double value, TitleMeta meta) {
    if (meta.axisSide != AxisSide.bottom) return const SizedBox.shrink();

    final date = DateTime.fromMillisecondsSinceEpoch(value.toInt());
    final text = _formatTimeForAxis(date);

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

  Widget _buildStockTitle(BuildContext context, double value, TitleMeta meta) {
    final l10n = AppLocalizations.of(context)!;
    if (meta.axisSide != AxisSide.left) return const SizedBox.shrink();

    String text;
    Color color;
    IconData icon;

    // Only show labels at exactly Y=0 and Y=1
    if (value == 0.0) {
      text = l10n.outOfStock;
      color = Colors.red;
      icon = Icons.cancel;
    } else if (value == 1.0) {
      text = l10n.inStock;
      color = Colors.green;
      icon = Icons.check_circle;
    } else {
      return const SizedBox.shrink(); // Don't show labels for other values
    }

    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Container(
        padding: const EdgeInsets.only(right: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 2),
            Text(
              text,
              style: TextStyle(
                fontSize: 8,
                color: color,
                fontWeight: FontWeight.w600,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
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

  LineChartBarData _buildStockLineData(
    BuildContext context,
    List<StockStatusPoint> points,
  ) {
    final spots =
        points
            .map(
              (point) => FlSpot(
                point.timestamp.millisecondsSinceEpoch.toDouble(),
                point.isInStock ? 1.0 : 0.0,
              ),
            )
            .toList();

    return LineChartBarData(
      spots: spots,
      isCurved: false, // Step-like chart for binary stock status
      isStepLineChart: true, // This creates the step effect
      color: Theme.of(context).colorScheme.primary,
      barWidth: 3,
      isStrokeCapRound: false,
      dotData: FlDotData(
        show: spots.length <= 16,
        getDotPainter: (spot, percent, barData, index) {
          final isInStock = spot.y > 0.5;
          return FlDotCirclePainter(
            radius: 4,
            color: isInStock ? Colors.green : Colors.red,
            strokeWidth: 2,
            strokeColor: Theme.of(context).colorScheme.surface,
          );
        },
      ),
      belowBarData: BarAreaData(
        show: true,
        cutOffY: 0.5,
        applyCutOffY: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.green.withAlpha(80),
            Colors.green.withAlpha(40),
            Colors.green.withAlpha(20),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
      aboveBarData: BarAreaData(
        show: true,
        cutOffY: 0.5,
        applyCutOffY: true,
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Colors.red.withAlpha(20),
            Colors.red.withAlpha(40),
            Colors.red.withAlpha(80),
          ],
          stops: const [0.0, 0.5, 1.0],
        ),
      ),
    );
  }

  LineTouchData _buildTouchData(
    BuildContext context,
    List<StockStatusPoint> points,
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
                  final isInStock = spot.y > 0.5;
                  final l10n = AppLocalizations.of(context)!;
                  final status = isInStock ? l10n.inStock : l10n.outOfStock;
                  final statusColor = isInStock ? Colors.green : Colors.red;

                  return LineTooltipItem(
                    '${_formatTimeForTooltip(date)}\n$status',
                    TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                    ),
                  );
                }).toList(),
      ),
    );
  }

  ExtraLinesData _buildStockLevels(BuildContext context) {
    return ExtraLinesData(
      horizontalLines: [
        // In Stock level
        HorizontalLine(
          y: 1.0,
          color: Colors.green.withAlpha(100),
          strokeWidth: 1,
          dashArray: [6, 3],
          label: HorizontalLineLabel(
            show: false,
            labelResolver: (line) => AppLocalizations.of(context)!.inStock,
            style: TextStyle(
              color: Colors.green,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            alignment: Alignment.topLeft,
            padding: const EdgeInsets.only(left: 8, bottom: 4),
          ),
        ),
        // Out of Stock level
        HorizontalLine(
          y: 0.0,
          color: Colors.red.withAlpha(100),
          strokeWidth: 1,
          dashArray: [6, 3],
          label: HorizontalLineLabel(
            show: false,
            labelResolver: (line) => AppLocalizations.of(context)!.outOfStock,
            style: TextStyle(
              color: Colors.red,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
            alignment: Alignment.bottomLeft,
            padding: const EdgeInsets.only(left: 8, top: 4),
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

  double _getTimeInterval(List<StockStatusPoint> points, int targetLabels) {
    if (points.isEmpty || points.length == 1) {
      return const Duration(hours: 1).inMilliseconds.toDouble();
    }

    final totalDuration = points.last.timestamp.difference(
      points.first.timestamp,
    );
    final calculated = totalDuration.inMilliseconds / targetLabels;

    switch (timeRange) {
      case 'day':
      case 'today':
        if (totalDuration.inHours <= 12) {
          return const Duration(hours: 2).inMilliseconds.toDouble();
        } else {
          return const Duration(hours: 6).inMilliseconds.toDouble();
        }
      case 'week':
        return const Duration(days: 1).inMilliseconds.toDouble();
      case 'month':
        return const Duration(days: 7).inMilliseconds.toDouble();
      case 'all':
      default:
        if (totalDuration.inDays <= 7) {
          return const Duration(days: 1).inMilliseconds.toDouble();
        } else if (totalDuration.inDays <= 30) {
          return const Duration(days: 7).inMilliseconds.toDouble();
        } else if (totalDuration.inDays <= 90) {
          return const Duration(days: 15).inMilliseconds.toDouble();
        } else {
          final minInterval =
              const Duration(days: 30).inMilliseconds.toDouble();
          return calculated > minInterval ? calculated : minInterval;
        }
    }
  }

  String _formatTimeForAxis(DateTime date) {
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

  String _formatTimeForTooltip(DateTime date) {
    switch (timeRange) {
      case 'day':
      case 'today':
        return DateFormat('MMM dd, HH:mm').format(date);
      case 'week':
        return DateFormat('MMM dd, HH:mm').format(date);
      case 'all':
      default:
        return DateFormat('MMM dd, yyyy HH:mm').format(date);
    }
  }
}

/// Enhanced grid view for daily stock status
class ImprovedStockGrid extends StatelessWidget {
  final List<StockStatusPoint> stockPoints;
  final DateTime selectedDay;

  const ImprovedStockGrid({
    super.key,
    required this.stockPoints,
    required this.selectedDay,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Create a 24-hour grid with better organization
    final hourlyStatus = <int, bool>{};
    final hourlyTimestamps = <int, DateTime>{};

    // Fill with stock status data
    for (final point in stockPoints) {
      final hour = point.timestamp.hour;
      hourlyStatus[hour] = point.isInStock;
      hourlyTimestamps[hour] = point.timestamp;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with date
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainer,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withAlpha(50),
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.calendar_today,
                size: 20,
                color: Theme.of(context).colorScheme.primary,
              ),
              const SizedBox(width: 8),
              Text(
                l10n.hourlyStockStatusWithDate(
                  DateFormat('EEEE, MMM dd, yyyy').format(selectedDay),
                ),
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Time grid
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 8, // 8 columns for better layout on mobile
            childAspectRatio: 1.2,
            crossAxisSpacing: 6,
            mainAxisSpacing: 6,
          ),
          itemCount: 24,
          itemBuilder: (context, index) {
            final hour = index;
            final hasData = hourlyStatus.containsKey(hour);
            final isInStock = hourlyStatus[hour] ?? false;
            final timestamp = hourlyTimestamps[hour];

            return _buildHourCell(context, hour, hasData, isInStock, timestamp);
          },
        ),

        const SizedBox(height: 16),

        // Legend
        _buildLegend(context),

        const SizedBox(height: 16),

        // Summary stats
        _buildSummaryStats(context, hourlyStatus),
      ],
    );
  }

  Widget _buildHourCell(
    BuildContext context,
    int hour,
    bool hasData,
    bool isInStock,
    DateTime? timestamp,
  ) {
    Color backgroundColor;
    Color borderColor;
    IconData? icon;
    Color textColor;

    if (!hasData) {
      backgroundColor = Theme.of(context).colorScheme.surfaceContainerHigh;
      borderColor = Theme.of(context).colorScheme.outline.withAlpha(50);
      textColor = Theme.of(context).colorScheme.onSurface.withAlpha(100);
    } else if (isInStock) {
      backgroundColor = Colors.green.withAlpha(150);
      borderColor = Colors.green;
      icon = Icons.check_circle;
      textColor = Colors.white;
    } else {
      backgroundColor = Colors.red.withAlpha(150);
      borderColor = Colors.red;
      icon = Icons.cancel;
      textColor = Colors.white;
    }

    final hourText = hour.toString().padLeft(2, '0');
    final l10n = AppLocalizations.of(context)!;
    final tooltipText =
        hasData
            ? '$hourText:00 - ${isInStock ? l10n.inStock : l10n.outOfStock}'
            : '$hourText:00 - ${l10n.noData}';

    return Tooltip(
      message: tooltipText,
      child: Container(
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: borderColor, width: 1.5),
          boxShadow:
              hasData
                  ? [
                    BoxShadow(
                      color: borderColor.withAlpha(50),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 16, color: textColor),
              const SizedBox(height: 2),
            ],
            Text(
              hourText,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLegend(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withAlpha(30),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _buildLegendItem(
            context,
            Colors.green,
            Icons.check_circle,
            AppLocalizations.of(context)!.inStock,
          ),
          _buildLegendItem(
            context,
            Colors.red,
            Icons.cancel,
            AppLocalizations.of(context)!.outOfStock,
          ),
          _buildLegendItem(
            context,
            Colors.grey,
            Icons.help_outline,
            AppLocalizations.of(context)!.noData,
          ),
        ],
      ),
    );
  }

  Widget _buildLegendItem(
    BuildContext context,
    Color color,
    IconData icon,
    String label,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 20,
          height: 20,
          decoration: BoxDecoration(
            color: color.withAlpha(150),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: color, width: 1.5),
          ),
          child: Icon(icon, size: 12, color: Colors.white),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(175),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSummaryStats(BuildContext context, Map<int, bool> hourlyStatus) {
    final l10n = AppLocalizations.of(context)!;
    final totalHours = hourlyStatus.length;
    final inStockHours = hourlyStatus.values.where((inStock) => inStock).length;
    final availability =
        totalHours > 0 ? (inStockHours / totalHours * 100) : 0.0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primaryContainer,
            Theme.of(context).colorScheme.primaryContainer.withAlpha(150),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Theme.of(context).colorScheme.primary.withAlpha(100),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem(
            context,
            l10n.hoursTracked,
            totalHours.toString(),
            Icons.access_time,
          ),
          _buildStatItem(
            context,
            l10n.inStock,
            inStockHours.toString(),
            Icons.check_circle,
          ),
          _buildStatItem(
            context,
            l10n.availability,
            '${availability.toStringAsFixed(0)}%',
            Icons.analytics,
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem(
    BuildContext context,
    String label,
    String value,
    IconData icon,
  ) {
    return Column(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary, size: 20),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(175),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
