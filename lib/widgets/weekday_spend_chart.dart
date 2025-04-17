import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:upi_expense_tracker/models/transaction.dart';
import 'package:intl/intl.dart';

class WeekdaySpendChart extends StatelessWidget {
  final List<Transaction> transactions;

  const WeekdaySpendChart({Key? key, required this.transactions}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Initialize spending by day of week
    List<double> weekdaySums = List.filled(7, 0.0);
    List<int> weekdayCounts = List.filled(7, 0);

    // Group transactions by day of week
    for (var transaction in transactions) {
      final weekday = transaction.dateTime.weekday - 1; // 0-6 (Monday-Sunday)
      weekdaySums[weekday] += transaction.amount;
      weekdayCounts[weekday]++;
    }

    // Calculate average spending per day
    List<double> weekdayAvgs = List.filled(7, 0.0);
    for (int i = 0; i < 7; i++) {
      weekdayAvgs[i] = weekdayCounts[i] > 0 ? weekdaySums[i] / weekdayCounts[i] : 0.0;
    }

    // Get max value for scaling
    double maxSum = weekdaySums.reduce((a, b) => a > b ? a : b);
    double maxAvg = weekdayAvgs.reduce((a, b) => a > b ? a : b);

    // Skip chart if no data
    if (maxSum == 0) {
      return const Center(child: Text('No data available'));
    }

    // Get weekday names
    final weekdayNames = [
      'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'
    ];

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceEvenly,
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final weekday = weekdayNames[group.x.toInt()];
              final sum = weekdaySums[group.x.toInt()];
              final count = weekdayCounts[group.x.toInt()];
              final avg = weekdayAvgs[group.x.toInt()];

              return BarTooltipItem(
                '$weekday\n₹${sum.toStringAsFixed(2)} total\n$count transactions\nAvg: ₹${avg.toStringAsFixed(2)}',
                const TextStyle(color: Colors.white),
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
                  return Text(
                    weekdayNames[value.toInt()],
                    style: const TextStyle(
                      color: Colors.black,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
              reservedSize: 30,
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                // Format currency values on Y axis
                String text = '';
                if (value == 0) {
                  text = '₹0';
                } else if (maxSum > 10000) {
                  // Show in thousands for large numbers
                  text = '₹${(value / 1000).toStringAsFixed(0)}K';
                } else {
                  text = '₹${value.toInt()}';
                }

                return Text(
                  text,
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 10,
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
          border: const Border(
            bottom: BorderSide(color: Colors.black12, width: 1),
            left: BorderSide(color: Colors.black12, width: 1),
          ),
        ),
        gridData: FlGridData(
          show: true,
          checkToShowHorizontalLine: (value) => value % (maxSum / 5).round() == 0,
          getDrawingHorizontalLine: (value) => FlLine(
            color: Colors.black12,
            strokeWidth: 1,
            dashArray: [5, 5],
          ),
        ),
        barGroups: List.generate(7, (i) {
          // Create a group for each weekday
          return BarChartGroupData(
            x: i,
            barRods: [
              BarChartRodData(
                toY: weekdaySums[i],
                color: Colors.blue,
                width: 16,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
                gradient: LinearGradient(
                  colors: [
                    Color.fromRGBO(33, 150, 243, 0.7), // Light blue
                    Color.fromRGBO(33, 150, 243, 1),   // Blue
                  ],
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxSum * 1.1,
                  color: Colors.grey.withOpacity(0.1),
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}