import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:upi_expense_tracker/models/transaction.dart';

class DailySpendChart extends StatelessWidget {
  final List<Transaction> transactions;
  final DateTime startDate;
  final DateTime endDate;

  const DailySpendChart({
    Key? key,
    required this.transactions,
    required this.startDate,
    required this.endDate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Group transactions by date
    final Map<DateTime, double> dailyTotals = {};

    // Initialize all days in range with zero
    final difference = endDate.difference(startDate).inDays;

    for (int i = 0; i <= difference; i++) {
      final date = DateTime(
        startDate.year,
        startDate.month,
        startDate.day + i,
      );
      dailyTotals[date] = 0;
    }

    // Calculate actual spending for each day
    for (var transaction in transactions) {
      if (transaction.type == 'debit') {  // Only count debits for spending
        final dateOnly = DateTime(
          transaction.dateTime.year,
          transaction.dateTime.month,
          transaction.dateTime.day,
        );

        dailyTotals[dateOnly] = (dailyTotals[dateOnly] ?? 0) + transaction.amount;
      }
    }

    // Convert to sorted list for the chart
    final sortedDates = dailyTotals.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    if (sortedDates.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: TextStyle(color: scheme.onSurface.withOpacity(0.6)),
        ),
      );
    }

    // Create spots for line chart
    final spots = <FlSpot>[];
    for (int i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      spots.add(FlSpot(i.toDouble(), dailyTotals[date]!));
    }

    // Find max and min values for proper scaling
    double maxValue = 0;
    double minValue = double.infinity;
    dailyTotals.forEach((_, value) {
      if (value > maxValue) maxValue = value;
      if (value < minValue) minValue = value;
    });

    // Handle edge cases
    if (minValue == double.infinity) minValue = 0;
    maxValue = maxValue > 0 ? maxValue : 100;

    // Add some padding to prevent line from touching chart boundaries
    final yPadding = (maxValue - minValue) * 0.1;
    final chartMinY = (minValue - yPadding).clamp(0.0, double.infinity).toDouble();
    final chartMaxY = maxValue + yPadding;

    // Date formatter for x-axis
    final dateFormat = sortedDates.length > 30
        ? DateFormat('dd/MM')
        : DateFormat('dd MMM');

    return Center(
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: _getInterval(chartMaxY - chartMinY),
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: scheme.onSurface.withOpacity(0.1),
                strokeWidth: 1,
                dashArray: [5, 5],
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                interval: _getXAxisInterval(sortedDates.length),
                getTitlesWidget: (value, meta) {
                  final style = TextStyle(
                    color: scheme.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                    fontSize: 10,
                  );

                  final int index = value.toInt();
                  if (index >= 0 && index < sortedDates.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        dateFormat.format(sortedDates[index]),
                        style: style,
                      ),
                    );
                  }
                  return const SizedBox();
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: _getInterval(chartMaxY - chartMinY),
                getTitlesWidget: (value, meta) {
                  final style = TextStyle(
                    color: scheme.onSurface.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                    fontSize: 10,
                  );

                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      _formatCurrency(value),
                      style: style,
                      textAlign: TextAlign.right,
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
            border: Border(
              bottom: BorderSide(
                color: scheme.onSurface.withOpacity(0.2),
                width: 1,
              ),
              left: BorderSide(
                color: scheme.onSurface.withOpacity(0.2),
                width: 1,
              ),
            ),
          ),
          minX: 0,
          maxX: (sortedDates.length - 1).toDouble(),
          minY: chartMinY,
          maxY: chartMaxY,
          clipData: FlClipData.all(), // Ensure content stays within bounds
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: scheme.primary,
              barWidth: 2.5,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: spots.length <= 15,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 3,
                    color: scheme.primary,
                    strokeWidth: 2,
                    strokeColor: scheme.surface,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                cutOffY: chartMinY, // Prevent gradient from going below minY
                applyCutOffY: true,
                gradient: LinearGradient(
                  colors: [
                    scheme.primary.withOpacity(0.3),
                    scheme.primary.withOpacity(0.05),
                  ],
                  stops: const [0.0, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              tooltipBgColor: scheme.inverseSurface,
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((touchedSpot) {
                  final index = touchedSpot.x.toInt();
                  if (index >= 0 && index < sortedDates.length) {
                    final date = sortedDates[index];
                    final amount = dailyTotals[date]!;

                    return LineTooltipItem(
                      '${DateFormat('dd MMM yyyy').format(date)}\n${_formatCurrency(amount)}',
                      TextStyle(
                        color: scheme.onInverseSurface,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    );
                  }
                  return null;
                }).toList();
              },
            ),
            handleBuiltInTouches: true,
            touchSpotThreshold: 25,
          ),
        ),
      ),
    );
  }

  double _getInterval(double range) {
    if (range <= 100) return 20;
    if (range <= 500) return 100;
    if (range <= 1000) return 200;
    if (range <= 5000) return 1000;
    if (range <= 10000) return 2000;
    return (range / 5).roundToDouble();
  }

  double? _getXAxisInterval(int dataPoints) {
    if (dataPoints <= 7) return null;
    if (dataPoints <= 15) return 2;
    if (dataPoints <= 30) return 5;
    return (dataPoints / 6).ceilToDouble();
  }

  String _formatCurrency(double value) {
    if (value == 0) return '₹0';
    if (value >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k';
    }
    return '₹${value.toStringAsFixed(value % 1 == 0 ? 0 : 0)}';
  }
}