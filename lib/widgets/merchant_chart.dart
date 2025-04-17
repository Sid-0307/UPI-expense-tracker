import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:upi_expense_tracker/models/transaction.dart';

class MerchantChart extends StatelessWidget {
  final List<Transaction> transactions;

  const MerchantChart({Key? key, required this.transactions}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Group by merchant for the chart
    final Map<String, double> merchantTotals = {};
    for (var transaction in transactions) {
      merchantTotals[transaction.merchant] =
          (merchantTotals[transaction.merchant] ?? 0) + transaction.amount;
    }

    // Sort merchants by total amount spent (descending)
    final sortedEntries = merchantTotals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    // Take top 7 merchants for better visualization
    final topMerchants = sortedEntries.take(7).toList();

    if (topMerchants.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    // Calculate max value for chart scaling
    final maxValue = topMerchants.first.value;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.start,
        maxY: maxValue * 1.1, // Add some space at the top
        barTouchData: BarTouchData(
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final merchant = topMerchants[group.x.toInt()].key;
              final amount = topMerchants[group.x.toInt()].value;
              return BarTooltipItem(
                '₹${amount.toStringAsFixed(2)}\n$merchant',
                const TextStyle(color: Colors.white),
              );
            },
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                // Format currency values on Y axis
                String text = '';
                if (value == 0) {
                  text = '₹0';
                } else if (maxValue > 10000) {
                  // Show in thousands for large numbers
                  text = '₹${(value / 1000).toStringAsFixed(0)}K';
                } else if (value % (maxValue / 5).round() == 0) {
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
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (double value, TitleMeta meta) {
                final int index = value.toInt();
                if (index >= 0 && index < topMerchants.length) {
                  final String merchant = topMerchants[index].key;
                  // Truncate merchant name if too long
                  final String displayName = merchant.length > 10
                      ? '${merchant.substring(0, 10)}...'
                      : merchant;

                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Transform.rotate(
                      angle: 45 * 3.14159 / 180, // Convert degrees to radians
                      alignment: Alignment.topLeft,
                      child: Text(
                        displayName,
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 10,
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox();
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
          checkToShowHorizontalLine: (value) => value % (maxValue / 5).round() == 0,
          getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.black12,
              strokeWidth: 1,
              dashArray: [5, 5]
          ),
        ),
        barGroups: List.generate(topMerchants.length, (index) {
          final gradientColors = [
            Color.fromRGBO(33, 150, 243, 0.7), // Light blue
            Color.fromRGBO(33, 150, 243, 1),   // Blue
          ];

          return BarChartGroupData(
            x: index,
            barRods: [
              BarChartRodData(
                toY: topMerchants[index].value, // Changed from y to toY
                color: gradientColors[1],
                gradient: LinearGradient(
                  colors: gradientColors,
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                ),
                width: 18,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(6),
                  topRight: Radius.circular(6),
                ),
                backDrawRodData: BackgroundBarChartRodData(
                  show: true,
                  toY: maxValue * 1.1, // Changed from y to toY
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