import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/stock_history.dart';

class StockStatusChart extends StatelessWidget {
  final List<StockStatusPoint> stockPoints;
  final String timeRange;
  final DateTime? selectedDay;

  const StockStatusChart({
    super.key,
    required this.stockPoints,
    this.timeRange = 'day',
    this.selectedDay,
  });

  @override
  Widget build(BuildContext context) {
    if (stockPoints.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 48,
                color: Theme.of(context).colorScheme.onSurface.withAlpha(75),
              ),
              const SizedBox(height: 8),
              Text(
                'No stock history available',
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
            horizontalInterval: 0.5,
            verticalInterval: _getTimeInterval(),
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
                interval: _getTimeInterval(),
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
                reservedSize: 60,
                getTitlesWidget: (value, meta) {
                  if (value == 0) {
                    return const SideTitleWidget(
                      axisSide: AxisSide.left,
                      child: Text(
                        'Out of Stock',
                        style: TextStyle(fontSize: 10, color: Colors.red),
                      ),
                    );
                  } else if (value == 1) {
                    return const SideTitleWidget(
                      axisSide: AxisSide.left,
                      child: Text(
                        'In Stock',
                        style: TextStyle(fontSize: 10, color: Colors.green),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
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
          minY: -0.1,
          maxY: 1.1,
          lineBarsData: [
            LineChartBarData(
              spots:
                  stockPoints.map((point) {
                    return FlSpot(
                      point.timestamp.millisecondsSinceEpoch.toDouble(),
                      point.isInStock ? 1.0 : 0.0,
                    );
                  }).toList(),
              isCurved: false, // Step chart for stock status
              color: Colors.blue,
              barWidth: 3,
              isStrokeCapRound: false,
              dotData: FlDotData(
                show: stockPoints.length <= 24, // Show dots for hourly data
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
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.green.withAlpha(75),
                    Colors.green.withAlpha(25),
                  ],
                ),
                cutOffY: 0.5,
                applyCutOffY: true,
              ),
              aboveBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.red.withAlpha(25), Colors.red.withAlpha(75)],
                ),
                cutOffY: 0.5,
                applyCutOffY: true,
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
                  final isInStock = barSpot.y > 0.5;
                  final status = isInStock ? 'In Stock' : 'Out of Stock';
                  final statusColor = isInStock ? Colors.green : Colors.red;

                  return LineTooltipItem(
                    '${_formatTimeForTooltip(date)}\n$status',
                    TextStyle(color: statusColor, fontWeight: FontWeight.bold),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }

  double _getTimeInterval() {
    if (stockPoints.isEmpty || stockPoints.length == 1) {
      // If no data or only one point, return a default interval
      return const Duration(hours: 1).inMilliseconds.toDouble();
    }

    final totalDuration = stockPoints.last.timestamp.difference(
      stockPoints.first.timestamp,
    );

    // Prevent zero interval by ensuring minimum interval
    double baseInterval;

    switch (timeRange) {
      case 'day':
        baseInterval = const Duration(hours: 2).inMilliseconds.toDouble();
        break;
      case 'week':
        baseInterval = const Duration(days: 1).inMilliseconds.toDouble();
        break;
      case 'month':
        baseInterval = const Duration(days: 5).inMilliseconds.toDouble();
        break;
      default:
        // For "all" time range, ensure we have a reasonable interval
        if (totalDuration.inMilliseconds <= 0) {
          // If duration is zero or negative, use a default interval
          baseInterval = const Duration(days: 1).inMilliseconds.toDouble();
        } else {
          // Divide by 8 but ensure minimum interval
          final calculatedInterval = totalDuration.inMilliseconds / 8.0;
          baseInterval =
              calculatedInterval < const Duration(hours: 1).inMilliseconds
                  ? const Duration(hours: 1).inMilliseconds.toDouble()
                  : calculatedInterval;
        }
        break;
    }

    // Ensure the interval is never zero
    return baseInterval > 0
        ? baseInterval
        : const Duration(hours: 1).inMilliseconds.toDouble();
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
}

class StockStatusGrid extends StatelessWidget {
  final List<StockStatusPoint> stockPoints;
  final DateTime selectedDay;

  const StockStatusGrid({
    super.key,
    required this.stockPoints,
    required this.selectedDay,
  });

  @override
  Widget build(BuildContext context) {
    // Create a 24-hour grid
    final hourlyStatus = <int, bool>{};

    // Fill with stock status data
    for (final point in stockPoints) {
      hourlyStatus[point.timestamp.hour] = point.isInStock;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hourly Stock Status - ${DateFormat('MMM dd, yyyy').format(selectedDay)}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 12),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 12,
            childAspectRatio: 1,
            crossAxisSpacing: 2,
            mainAxisSpacing: 2,
          ),
          itemCount: 24,
          itemBuilder: (context, index) {
            final hour = index;
            final hasData = hourlyStatus.containsKey(hour);
            final isInStock = hourlyStatus[hour] ?? false;

            Color cellColor;
            IconData cellIcon;

            if (!hasData) {
              cellColor = Colors.grey.withAlpha(75);
              cellIcon = Icons.help_outline;
            } else if (isInStock) {
              cellColor = Colors.green;
              cellIcon = Icons.check_circle;
            } else {
              cellColor = Colors.red;
              cellIcon = Icons.cancel;
            }

            return Tooltip(
              message:
                  hasData
                      ? '${hour.toString().padLeft(2, '0')}:00 - ${isInStock ? 'In Stock' : 'Out of Stock'}'
                      : '${hour.toString().padLeft(2, '0')}:00 - No Data',
              child: Container(
                decoration: BoxDecoration(
                  color: cellColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child:
                      hasData
                          ? Icon(cellIcon, size: 16, color: Colors.white)
                          : Text(
                            hour.toString(),
                            style: const TextStyle(
                              fontSize: 10,
                              color: Colors.grey,
                            ),
                          ),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildLegendItem(
              context,
              Colors.green,
              Icons.check_circle,
              'In Stock',
            ),
            _buildLegendItem(context, Colors.red, Icons.cancel, 'Out of Stock'),
            _buildLegendItem(
              context,
              Colors.grey,
              Icons.help_outline,
              'No Data',
            ),
          ],
        ),
      ],
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
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
          child: Icon(icon, size: 12, color: Colors.white),
        ),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurface.withAlpha(175),
          ),
        ),
      ],
    );
  }
}
