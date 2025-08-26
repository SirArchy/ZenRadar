import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/stock_history.dart';

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

    return SizedBox(
      height: 280,
      child: LineChart(
        LineChartData(
          gridData: _buildGridData(context),
          titlesData: _buildTitlesData(context, sortedPoints),
          borderData: _buildBorderData(context),
          lineBarsData: [_buildStockLineData(context, sortedPoints)],
          lineTouchData: _buildTouchData(context, sortedPoints),
          minX: sortedPoints.first.timestamp.millisecondsSinceEpoch.toDouble(),
          maxX: sortedPoints.last.timestamp.millisecondsSinceEpoch.toDouble(),
          minY: -0.1,
          maxY: 1.1,
          extraLinesData: _buildStockLevels(context),
        ),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
            'No Stock History Available',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Stock tracking will begin with the next scan for this time range',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
            ),
          ),
        ],
      ),
    );
  }

  FlGridData _buildGridData(BuildContext context) {
    return FlGridData(
      show: true,
      drawVerticalLine: true,
      drawHorizontalLine: false, // No horizontal lines for stock chart
      verticalInterval: _getTimeInterval(),
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
  ) {
    return FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 35,
          interval: _getTimeInterval(),
          getTitlesWidget:
              (value, meta) => _buildTimeTitle(context, value, meta),
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 80,
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
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildStockTitle(BuildContext context, double value, TitleMeta meta) {
    if (meta.axisSide != AxisSide.left) return const SizedBox.shrink();

    String text;
    Color color;
    IconData icon;

    if (value <= 0.25) {
      text = 'Out of Stock';
      color = Colors.red;
      icon = Icons.cancel;
    } else if (value >= 0.75) {
      text = 'In Stock';
      color = Colors.green;
      icon = Icons.check_circle;
    } else {
      return const SizedBox.shrink(); // Don't show intermediate values
    }

    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Container(
        padding: const EdgeInsets.only(right: 8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 4),
            Text(
              text,
              style: TextStyle(
                fontSize: 10,
                color: color,
                fontWeight: FontWeight.w600,
              ),
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
      color: Colors.blue,
      barWidth: 3,
      isStrokeCapRound: false,
      dotData: FlDotData(
        show: spots.length <= 24, // Show dots for hourly or less frequent data
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
                  final status = isInStock ? 'In Stock' : 'Out of Stock';
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
            show: true,
            labelResolver: (line) => 'In Stock',
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
            show: true,
            labelResolver: (line) => 'Out of Stock',
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

  double _getTimeInterval() {
    if (stockPoints.isEmpty || stockPoints.length == 1) {
      return const Duration(hours: 1).inMilliseconds.toDouble();
    }

    final totalDuration = stockPoints.last.timestamp.difference(
      stockPoints.first.timestamp,
    );

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
          return const Duration(days: 30).inMilliseconds.toDouble();
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
        return DateFormat('MM/dd').format(date);
      case 'all':
      default:
        final now = DateTime.now();
        final difference = now.difference(date).inDays;

        if (difference <= 30) {
          return DateFormat('MM/dd').format(date);
        } else if (difference <= 365) {
          return DateFormat('MMM').format(date);
        } else {
          return DateFormat('MM/yy').format(date);
        }
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
                'Hourly Stock Status - ${DateFormat('EEEE, MMM dd, yyyy').format(selectedDay)}',
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
    final tooltipText =
        hasData
            ? '$hourText:00 - ${isInStock ? 'In Stock' : 'Out of Stock'}'
            : '$hourText:00 - No Data';

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
            'In Stock',
          ),
          _buildLegendItem(context, Colors.red, Icons.cancel, 'Out of Stock'),
          _buildLegendItem(context, Colors.grey, Icons.help_outline, 'No Data'),
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
            'Hours Tracked',
            totalHours.toString(),
            Icons.access_time,
          ),
          _buildStatItem(
            context,
            'In Stock',
            inStockHours.toString(),
            Icons.check_circle,
          ),
          _buildStatItem(
            context,
            'Availability',
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
