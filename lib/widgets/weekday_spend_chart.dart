import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:upi_expense_tracker/models/transaction.dart';
import 'package:intl/intl.dart';

class WeekdaySpendChart extends StatelessWidget {
  final List<Transaction> transactions;

  const WeekdaySpendChart({Key? key, required this.transactions}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Initialize spending by day of week
    List<double> weekdaySums = List.filled(7, 0.0);
    List<int> weekdayCounts = List.filled(7, 0);

    // Filter for debit transactions only and group by day of week
    final debitTransactions = transactions.where((t) => t.type == 'debit').toList();

    for (var transaction in debitTransactions) {
      final weekday = transaction.dateTime.weekday - 1; // 0-6 (Monday-Sunday)
      weekdaySums[weekday] += transaction.amount;
      weekdayCounts[weekday]++;
    }

    // Get max value for scaling
    double maxSum = weekdaySums.isNotEmpty ? weekdaySums.reduce((a, b) => a > b ? a : b) : 0;

    // Skip chart if no data
    if (maxSum == 0) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sentiment_dissatisfied,
              size: 48,
              color: scheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No data available',
              style: TextStyle(
                color: scheme.onSurface.withOpacity(0.6),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // Get weekday names
    final weekdayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

    return Center(
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceEvenly,
          maxY: maxSum * 1.1,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: scheme.inverseSurface,
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final weekday = weekdayNames[group.x.toInt()];
                final sum = weekdaySums[group.x.toInt()];
                final count = weekdayCounts[group.x.toInt()];
                final avg = count > 0 ? sum / count : 0.0;

                return BarTooltipItem(
                  '$weekday\n${_formatCurrency(sum)} total\n$count transactions\nAvg: ${_formatCurrency(avg)}',
                  TextStyle(
                    color: scheme.onInverseSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value >= 0 && value < weekdayNames.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        weekdayNames[value.toInt()],
                        style: TextStyle(
                          color: scheme.onSurface.withOpacity(0.7),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
                reservedSize: 20,
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                interval: _getInterval(maxSum),
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      _formatCurrency(value),
                      style: TextStyle(
                        color: scheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                        fontSize: 10,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  );
                },
                reservedSize: 40,
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
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: _getInterval(maxSum),
            getDrawingHorizontalLine: (value) => FlLine(
              color: scheme.onSurface.withOpacity(0.1),
              strokeWidth: 1,
              dashArray: [5, 5],
            ),
          ),
          barGroups: List.generate(7, (i) {
            final isWeekend = i >= 5; // Saturday and Sunday
            final barColor = isWeekend ? scheme.secondary : scheme.primary;

            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: weekdaySums[i],
                  width: 18,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(4),
                    topRight: Radius.circular(4),
                  ),
                  gradient: LinearGradient(
                    colors: [
                      barColor.withOpacity(0.7),
                      barColor,
                    ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: maxSum * 1.1,
                    color: scheme.surfaceVariant.withOpacity(0.3),
                  ),
                ),
              ],
            );
          }),
        ),
      ),
    );
  }

  double _getInterval(double maxValue) {
    if (maxValue <= 100) return 20;
    if (maxValue <= 500) return 100;
    if (maxValue <= 1000) return 200;
    if (maxValue <= 5000) return 1000;
    if (maxValue <= 10000) return 2000;
    return (maxValue / 5).roundToDouble();
  }

  String _formatCurrency(double value) {
    if (value == 0) return '₹0';
    if (value >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k';
    }
    return '₹${value.toStringAsFixed(value % 1 == 0 ? 0 : 0)}';
  }
}