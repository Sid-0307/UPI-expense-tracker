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
      final dateOnly = DateTime(
        transaction.dateTime.year,
        transaction.dateTime.month,
        transaction.dateTime.day,
      );

      dailyTotals[dateOnly] = (dailyTotals[dateOnly] ?? 0) + transaction.amount;
    }

    // Convert to sorted list for the chart
    final sortedDates = dailyTotals.keys.toList()
      ..sort((a, b) => a.compareTo(b));

    if (sortedDates.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    // Create spots for line chart
    final spots = <FlSpot>[];
    for (int i = 0; i < sortedDates.length; i++) {
      final date = sortedDates[i];
      spots.add(FlSpot(i.toDouble(), dailyTotals[date]!));
    }

    // Find max value for scaling
    double maxValue = 0;
    dailyTotals.forEach((_, value) {
      if (value > maxValue) maxValue = value;
    });

    // Ensure we have a non-zero maxValue
    maxValue = maxValue > 0 ? maxValue : 100;

    // Date formatter for x-axis
    final dateFormat = DateFormat('dd MMM');

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: maxValue / 5,
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: Colors.grey.withOpacity(0.3),
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
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final style = TextStyle(
                  color: const Color(0xff68737d),
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                );

                final int index = value.toInt();
                if (index >= 0 && index < sortedDates.length) {
                  // Show dates at regular intervals
                  if (sortedDates.length <= 10 || index % (sortedDates.length ~/ 5) == 0) {
                    return Text(
                      dateFormat.format(sortedDates[index]),
                      style: style,
                    );
                  }
                }
                return const SizedBox();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 40,
              getTitlesWidget: (value, meta) {
                final style = TextStyle(
                  color: const Color(0xff67727d),
                  fontWeight: FontWeight.bold,
                  fontSize: 10,
                );

                // Format currency values
                String text = '';
                if (value == 0) {
                  text = '₹0';
                } else if (maxValue > 10000) {
                  // Show in thousands for large numbers
                  if (value % (maxValue / 5).round() == 0) {
                    text = '₹${(value / 1000).toStringAsFixed(0)}K';
                  }
                } else if (value % (maxValue / 5).round() == 0) {
                  text = '₹${value.toInt()}';
                }

                if (text.isEmpty) {
                  return const SizedBox();
                }

                return Text(text, style: style);
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
            bottom: BorderSide(color: const Color(0xff4e4965).withOpacity(0.4), width: 1),
            left: BorderSide(color: const Color(0xff4e4965).withOpacity(0.4), width: 1),
          ),
        ),
        minX: 0,
        maxX: (sortedDates.length - 1).toDouble(),
        minY: 0,
        maxY: maxValue * 1.2,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blue,
            barWidth: 3,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: spots.length < 15, // Only show dots if we have few data points
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: Colors.blue,
                  strokeWidth: 1,
                  strokeColor: Colors.white,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blue.withOpacity(0.2),
              gradient: LinearGradient(
                colors: [
                  Colors.blue.withOpacity(0.3),
                  Colors.blue.withOpacity(0.1),
                ],
                stops: [0.5, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: Colors.blueAccent.withOpacity(0.8),
            getTooltipItems: (touchedSpots) {
              return touchedSpots.map((touchedSpot) {
                final index = touchedSpot.x.toInt();
                if (index >= 0 && index < sortedDates.length) {
                  final date = sortedDates[index];
                  final amount = dailyTotals[date]!;
                  final formattedAmount = NumberFormat.currency(
                    symbol: '₹',
                    decimalDigits: 2,
                  ).format(amount);

                  return LineTooltipItem(
                    '${dateFormat.format(date)}\n$formattedAmount',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  );
                }
                return null;
              }).toList();
            },
          ),
          handleBuiltInTouches: true,
          touchSpotThreshold: 20,
        ),
      ),
    );
  }
}