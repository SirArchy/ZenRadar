import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/website_stock_analytics.dart';
import '../models/stock_history.dart';

class WebsiteStockChart extends StatelessWidget {
  final WebsiteStockAnalytics analytics;
  final String timeRange;

  const WebsiteStockChart({
    super.key,
    required this.analytics,
    this.timeRange = 'month',
  });

  @override
  Widget build(BuildContext context) {
    final filteredUpdates = analytics.getFilteredUpdates(timeRange);

    if (filteredUpdates.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.timeline_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(75),
              ),
              const SizedBox(height: 8),
              Text(
                'No stock updates in ${_getTimeRangeLabel()}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface.withAlpha(175),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: true,
            horizontalInterval: 1,
            verticalInterval: _getTimeInterval(filteredUpdates),
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Theme.of(context).colorScheme.outline.withAlpha(50),
                strokeWidth: 1,
              );
            },
            getDrawingVerticalLine: (value) {
              return FlLine(
                color: Theme.of(context).colorScheme.outline.withAlpha(50),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: _getTimeInterval(filteredUpdates),
                getTitlesWidget: (value, meta) {
                  final date = DateTime.fromMillisecondsSinceEpoch(
                    value.toInt(),
                  );
                  return SideTitleWidget(
                    axisSide: meta.axisSide,
                    child: Text(
                      _formatTimeForAxis(date),
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 70,
                getTitlesWidget: (value, meta) {
                  final intValue = value.toInt();
                  if (intValue <= 0) return const SizedBox.shrink();

                  return SideTitleWidget(
                    axisSide: AxisSide.left,
                    child: Text(
                      '$intValue update${intValue > 1 ? 's' : ''}',
                      style: const TextStyle(fontSize: 10),
                    ),
                  );
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withAlpha(50),
            ),
          ),
          minY: 0,
          maxY: _getMaxUpdates(filteredUpdates) + 1,
          lineBarsData: [
            LineChartBarData(
              spots:
                  filteredUpdates.map((point) {
                    return FlSpot(
                      point.timestamp.millisecondsSinceEpoch.toDouble(),
                      point.stockDuration.toDouble(), // Use as update count
                    );
                  }).toList(),
              isCurved: false,
              color: _getLineColor(context),
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final updateCount = spot.y.toInt();
                  Color dotColor = _getDotColor(context, updateCount);

                  return FlDotCirclePainter(
                    radius: _getDotRadius(updateCount),
                    color: dotColor,
                    strokeWidth: 2,
                    strokeColor: Theme.of(context).colorScheme.surface,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _getLineColor(context).withAlpha(75),
                    _getLineColor(context).withAlpha(25),
                  ],
                ),
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
                  final updateCount = barSpot.y.toInt();

                  return LineTooltipItem(
                    '${_formatTimeForTooltip(date)}\n$updateCount stock update${updateCount > 1 ? 's' : ''}',
                    TextStyle(
                      color: _getLineColor(context),
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  double _getTimeInterval(List<StockStatusPoint> updates) {
    if (updates.isEmpty || updates.length == 1) {
      return const Duration(hours: 1).inMilliseconds.toDouble();
    }

    final totalDuration = updates.last.timestamp.difference(
      updates.first.timestamp,
    );

    switch (timeRange) {
      case 'day':
        return const Duration(hours: 2).inMilliseconds.toDouble();
      case 'week':
        return const Duration(days: 1).inMilliseconds.toDouble();
      case 'month':
        return const Duration(days: 5).inMilliseconds.toDouble();
      default:
        if (totalDuration.inMilliseconds <= 0) {
          return const Duration(days: 1).inMilliseconds.toDouble();
        }
        final calculatedInterval = totalDuration.inMilliseconds / 8.0;
        return calculatedInterval < const Duration(hours: 1).inMilliseconds
            ? const Duration(hours: 1).inMilliseconds.toDouble()
            : calculatedInterval;
    }
  }

  double _getMaxUpdates(List<StockStatusPoint> updates) {
    if (updates.isEmpty) return 5;

    final maxUpdates = updates
        .map((u) => u.stockDuration)
        .reduce((max, current) => current > max ? current : max);

    return maxUpdates.toDouble();
  }

  Color _getLineColor(BuildContext context) {
    return Theme.of(context).primaryColor;
  }

  Color _getDotColor(BuildContext context, int updateCount) {
    if (updateCount >= 10) return Colors.red;
    if (updateCount >= 5) return Colors.orange;
    if (updateCount >= 2) return Colors.blue;
    return Colors.green;
  }

  double _getDotRadius(int updateCount) {
    if (updateCount >= 10) return 6;
    if (updateCount >= 5) return 5;
    if (updateCount >= 2) return 4;
    return 3;
  }

  String _formatTimeForAxis(DateTime date) {
    switch (timeRange) {
      case 'day':
        return DateFormat('HH:mm').format(date);
      case 'week':
        return DateFormat('MM/dd').format(date);
      case 'month':
        return DateFormat('MM/dd').format(date);
      default:
        return DateFormat('MM/yy').format(date);
    }
  }

  String _formatTimeForTooltip(DateTime date) {
    switch (timeRange) {
      case 'day':
        return DateFormat('MMM dd, HH:mm').format(date);
      case 'week':
        return DateFormat('MMM dd, HH:mm').format(date);
      default:
        return DateFormat('MMM dd, yyyy HH:mm').format(date);
    }
  }

  String _getTimeRangeLabel() {
    switch (timeRange) {
      case 'day':
        return 'the last 24 hours';
      case 'week':
        return 'the last week';
      case 'month':
        return 'the last month';
      default:
        return 'this time period';
    }
  }
}

/// Widget showing hourly update pattern for a website
class WebsiteUpdatePatternWidget extends StatelessWidget {
  final WebsiteStockAnalytics analytics;

  const WebsiteUpdatePatternWidget({super.key, required this.analytics});

  @override
  Widget build(BuildContext context) {
    if (analytics.hourlyUpdatePattern.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        child: Text(
          'No update pattern data available',
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurface.withAlpha(175),
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Update Pattern (24 hours)',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 60,
          child: GridView.builder(
            scrollDirection: Axis.horizontal,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
            ),
            itemCount: 24,
            itemBuilder: (context, index) {
              final hour = index;
              final updateCount = analytics.hourlyUpdatePattern[hour] ?? 0;
              final maxUpdates =
                  analytics.hourlyUpdatePattern.values.isNotEmpty
                      ? analytics.hourlyUpdatePattern.values.reduce(
                        (max, current) => current > max ? current : max,
                      )
                      : 1;

              final intensity =
                  updateCount > 0 ? (updateCount / maxUpdates) : 0.0;

              Color cellColor;
              if (updateCount == 0) {
                cellColor = Colors.grey.withAlpha(50);
              } else if (intensity >= 0.7) {
                cellColor = Colors.red.withAlpha((255 * intensity).toInt());
              } else if (intensity >= 0.4) {
                cellColor = Colors.orange.withAlpha((255 * intensity).toInt());
              } else {
                cellColor = Colors.blue.withAlpha((255 * intensity).toInt());
              }

              return Tooltip(
                message:
                    '${hour.toString().padLeft(2, '0')}:00 - $updateCount update${updateCount != 1 ? 's' : ''}',
                child: Container(
                  decoration: BoxDecoration(
                    color: cellColor,
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.outline.withAlpha(50),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      hour.toString(),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: updateCount > 0 ? Colors.white : Colors.grey,
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        if (analytics.mostActiveHour != null)
          Text(
            'Most active: ${analytics.mostActiveHour!.toString().padLeft(2, '0')}:00',
            style: TextStyle(
              fontSize: 12,
              color: Theme.of(context).colorScheme.onSurface.withAlpha(175),
            ),
          ),
      ],
    );
  }
}
