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
              tooltipRoundedRadius: 8,
              getTooltipColor:
                  (touchedSpot) =>
                      Theme.of(context).colorScheme.surfaceContainerHighest,
              tooltipBorder: BorderSide(
                color: Theme.of(
                  context,
                ).colorScheme.outline.withValues(alpha: 0.5),
                width: 1,
              ),
              getTooltipItems: (List<LineBarSpot> touchedBarSpots) {
                return touchedBarSpots.map((barSpot) {
                  final date = DateTime.fromMillisecondsSinceEpoch(
                    barSpot.x.toInt(),
                  );
                  final updateCount = barSpot.y.toInt();

                  return LineTooltipItem(
                    '${_formatTimeForTooltip(date)}\n$updateCount stock update${updateCount > 1 ? 's' : ''}',
                    TextStyle(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
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
      case 'today':
        // For today/day, if duration is very short, use smaller intervals
        if (totalDuration.inHours <= 1) {
          return const Duration(minutes: 15).inMilliseconds.toDouble();
        } else if (totalDuration.inHours <= 6) {
          return const Duration(minutes: 30).inMilliseconds.toDouble();
        } else {
          return const Duration(hours: 2).inMilliseconds.toDouble();
        }
      case 'week':
        return const Duration(days: 1).inMilliseconds.toDouble();
      case 'month':
        return const Duration(days: 5).inMilliseconds.toDouble();
      case 'all':
      default:
        if (totalDuration.inMilliseconds <= 0) {
          return const Duration(days: 1).inMilliseconds.toDouble();
        } else if (totalDuration.inDays <= 1) {
          // Very short duration - use hourly intervals
          return const Duration(hours: 2).inMilliseconds.toDouble();
        } else if (totalDuration.inDays <= 7) {
          // Week duration - use daily intervals
          return const Duration(days: 1).inMilliseconds.toDouble();
        } else if (totalDuration.inDays <= 30) {
          // Month duration - use 5-day intervals
          return const Duration(days: 5).inMilliseconds.toDouble();
        } else {
          // Longer duration - calculate based on total duration
          final calculatedInterval = totalDuration.inMilliseconds / 8.0;
          return calculatedInterval < const Duration(hours: 1).inMilliseconds
              ? const Duration(hours: 1).inMilliseconds.toDouble()
              : calculatedInterval;
        }
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
    final brightness = Theme.of(context).brightness;
    if (brightness == Brightness.dark) {
      // Use a brighter, more visible color in dark mode
      return Theme.of(context).colorScheme.primary.withValues(alpha: 0.9);
    } else {
      // Use the primary color for light mode
      return Theme.of(context).colorScheme.primary;
    }
  }

  Color _getDotColor(BuildContext context, int updateCount) {
    final brightness = Theme.of(context).brightness;

    if (updateCount >= 10) {
      return brightness == Brightness.dark
          ? Colors.red.shade300
          : Colors.red.shade600;
    }
    if (updateCount >= 5) {
      return brightness == Brightness.dark
          ? Colors.orange.shade300
          : Colors.orange.shade600;
    }
    if (updateCount >= 2) {
      return brightness == Brightness.dark
          ? Colors.blue.shade300
          : Colors.blue.shade600;
    }
    return brightness == Brightness.dark
        ? Colors.green.shade300
        : Colors.green.shade600;
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
      case 'today':
        return DateFormat('HH:mm').format(date);
      case 'week':
        return DateFormat('MM/dd').format(date);
      case 'month':
        return DateFormat('MM/dd').format(date);
      case 'all':
      default:
        return DateFormat('MM/yy').format(date);
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

  String _getTimeRangeLabel() {
    switch (timeRange) {
      case 'day':
      case 'today':
        return 'the last 24 hours';
      case 'week':
        return 'the last week';
      case 'month':
        return 'the last month';
      case 'all':
        return 'all time';
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
              final isDark = Theme.of(context).brightness == Brightness.dark;

              if (updateCount == 0) {
                cellColor = Theme.of(
                  context,
                ).colorScheme.surfaceContainerHighest.withAlpha(100);
              } else if (intensity >= 0.7) {
                // High activity - red for both themes
                cellColor = (isDark ? Colors.red.shade300 : Colors.red.shade600)
                    .withAlpha((200 * intensity).toInt().clamp(80, 200));
              } else if (intensity >= 0.4) {
                // Medium activity - orange for both themes
                cellColor = (isDark
                        ? Colors.orange.shade300
                        : Colors.orange.shade600)
                    .withAlpha((200 * intensity).toInt().clamp(80, 200));
              } else {
                // Low activity - use primary color for better theme integration
                cellColor = Theme.of(context).colorScheme.primary.withAlpha(
                  (180 * intensity).toInt().clamp(60, 180),
                );
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
                        color:
                            updateCount > 0
                                ? (isDark ? Colors.white : Colors.white)
                                : Theme.of(
                                  context,
                                ).colorScheme.onSurface.withAlpha(125),
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
