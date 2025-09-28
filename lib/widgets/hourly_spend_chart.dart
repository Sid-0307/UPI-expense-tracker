import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:upi_expense_tracker/models/transaction.dart';

class HourlySpendChart extends StatelessWidget {
  final List<Transaction> transactions;

  const HourlySpendChart({Key? key, required this.transactions}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Filter for debit transactions only
    final debitTransactions = transactions.where((t) => t.type == 'debit').toList();

    if (debitTransactions.isEmpty) {
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

    final List<double> hourlyTotals = List.filled(24, 0.0);
    for (final t in debitTransactions) {
      final hour = t.dateTime.hour; // 0-23
      hourlyTotals[hour] += t.amount;
    }

    final double maxValue = hourlyTotals.reduce((a, b) => a > b ? a : b);
    final double maxY = maxValue > 0 ? maxValue * 1.1 : 100;

    return Center(
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceBetween,
          maxY: maxY,
          titlesData: FlTitlesData(
            show: true,
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 40,
                interval: _getInterval(maxY),
                getTitlesWidget: (value, meta) {
                  return Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: Text(
                      _formatCurrency(value),
                      style: TextStyle(
                        color: scheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                        fontSize: 9,
                      ),
                      textAlign: TextAlign.right,
                    ),
                  );
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 20,
                interval: 3,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  return Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      '${i.toString()}  ',
                      style: TextStyle(
                        color: scheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                        fontSize: 9,
                      ),
                    ),
                  );
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: _getInterval(maxY),
            getDrawingHorizontalLine: (value) => FlLine(
              color: scheme.onSurface.withOpacity(0.1),
              strokeWidth: 1,
              dashArray: [5, 5],
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
          barGroups: List.generate(24, (index) {
            // Color bars differently based on time periods
            Color barColor;
            if (index >= 6 && index < 12) {
              // Morning (6 AM - 12 PM): Primary color
              barColor = scheme.primary;
            } else if (index >= 12 && index < 18) {
              // Afternoon (12 PM - 6 PM): Secondary color
              barColor = scheme.secondary;
            } else if (index >= 18 && index < 22) {
              // Evening (6 PM - 10 PM): Tertiary color
              barColor = Colors.blue;
            } else {
              // Night/Late night (10 PM - 6 AM): Surface variant
              barColor = scheme.onSurface;
            }

            return BarChartGroupData(
                x: index,
                barRods: [
                  BarChartRodData(
                    toY: hourlyTotals[index],
                    width: 8,
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(2),
                      topRight: Radius.circular(2),
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
                      toY: maxY,
                      color: scheme.surfaceVariant.withOpacity(0.2),
                    ),
                  ),
                ]
            );
          }),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipBgColor: scheme.inverseSurface,
              tooltipRoundedRadius: 8,
              tooltipPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final hour = group.x.toInt();
                final timeLabel = _getTimeLabel(hour);
                return BarTooltipItem(
                  '${hour.toString().padLeft(2, '0')}:00 $timeLabel\n${_formatCurrency(hourlyTotals[hour])}',
                  TextStyle(
                    color: scheme.onInverseSurface,
                    fontWeight: FontWeight.w600,
                    fontSize: 12,
                  ),
                );
              },
            ),
          ),
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

  String _getTimeLabel(int hour) {
    if (hour >= 6 && hour < 12) return '(Morning)';
    if (hour >= 12 && hour < 18) return '(Afternoon)';
    if (hour >= 18 && hour < 22) return '(Evening)';
    return '(Night)';
  }
}