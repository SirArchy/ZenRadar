import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/price_history.dart';

class ImprovedPriceChart extends StatelessWidget {
  final List<PriceHistory> priceHistory;
  final String timeRange;
  final String currencySymbol;
  final Color? primaryColor;

  const ImprovedPriceChart({
    super.key,
    required this.priceHistory,
    required this.timeRange,
    this.currencySymbol = '€',
    this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    if (priceHistory.isEmpty) {
      return _buildEmptyState(context);
    }

    // Sort by date to ensure proper ordering
    final sortedHistory = List<PriceHistory>.from(priceHistory)
      ..sort((a, b) => a.date.compareTo(b.date));

    final spots = _generateSpots(sortedHistory);
    if (spots.isEmpty) {
      return _buildEmptyState(context);
    }

    final minPrice = sortedHistory
        .map((h) => h.price)
        .reduce((a, b) => a < b ? a : b);
    final maxPrice = sortedHistory
        .map((h) => h.price)
        .reduce((a, b) => a > b ? a : b);
    final priceRange = maxPrice - minPrice;

    // Add padding to the Y-axis range (10% on each side)
    final padding = priceRange * 0.1;
    final yMin = (minPrice - padding).clamp(0.0, double.infinity);
    final yMax = maxPrice + padding;

    return SizedBox(
      height: 300,
      child: LineChart(
        LineChartData(
          gridData: _buildGridData(context),
          titlesData: _buildTitlesData(context, sortedHistory, yMin, yMax),
          borderData: _buildBorderData(context),
          lineBarsData: [_buildLineBarData(context, spots)],
          lineTouchData: _buildTouchData(context, sortedHistory),
          minX: spots.first.x,
          maxX: spots.last.x,
          minY: yMin,
          maxY: yMax,
          extraLinesData: _buildExtraLines(context, sortedHistory, yMin, yMax),
        ),
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
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
            'No Price Data Available',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(150),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Price tracking will begin with the next scan for this time range',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface.withAlpha(100),
            ),
          ),
        ],
      ),
    );
  }

  List<FlSpot> _generateSpots(List<PriceHistory> history) {
    return history
        .map((h) => FlSpot(h.date.millisecondsSinceEpoch.toDouble(), h.price))
        .toList();
  }

  FlGridData _buildGridData(BuildContext context) {
    return FlGridData(
      show: true,
      drawVerticalLine: true,
      drawHorizontalLine: true,
      horizontalInterval: _getHorizontalInterval(),
      verticalInterval: _getVerticalInterval(),
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
  ) {
    return FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 35,
          interval: _getTimeInterval(history),
          getTitlesWidget:
              (value, meta) => _buildDateTitle(context, value, meta),
        ),
      ),
      leftTitles: AxisTitles(
        sideTitles: SideTitles(
          showTitles: true,
          reservedSize: 60,
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
            fontSize: 11,
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
            fontSize: 11,
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
            show: true,
            labelResolver:
                (line) => 'Avg: ${avgPrice.toStringAsFixed(2)}$currencySymbol',
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

  double _getTimeInterval(List<PriceHistory> history) {
    if (history.length <= 1) {
      return const Duration(days: 1).inMilliseconds.toDouble();
    }

    final totalDuration = history.last.date.difference(history.first.date);

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

  double _getHorizontalInterval() {
    if (priceHistory.isEmpty) return 1.0;

    final minPrice = priceHistory
        .map((h) => h.price)
        .reduce((a, b) => a < b ? a : b);
    final maxPrice = priceHistory
        .map((h) => h.price)
        .reduce((a, b) => a > b ? a : b);
    final range = maxPrice - minPrice;

    if (range <= 0) return 1.0;

    // Aim for 4-6 horizontal grid lines
    final targetLines = 5;
    final rawInterval = range / targetLines;

    // Round to nice numbers
    if (rawInterval >= 10) return (rawInterval / 10).round() * 10.0;
    if (rawInterval >= 5) return (rawInterval / 5).round() * 5.0;
    if (rawInterval >= 1) return rawInterval.round().toDouble();
    if (rawInterval >= 0.5) return 0.5;
    if (rawInterval >= 0.1) return 0.1;
    return 0.01;
  }

  double _getVerticalInterval() {
    return _getTimeInterval(priceHistory);
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
}
