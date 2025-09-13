import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:upi_expense_tracker/models/transaction.dart';

class HourlySpendChart extends StatelessWidget {
  final List<Transaction> transactions;

  const HourlySpendChart({Key? key, required this.transactions}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final List<double> hourlyTotals = List.filled(24, 0.0);
    for (final t in transactions) {
      final hour = t.dateTime.hour; // 0-23
      hourlyTotals[hour] += t.amount;
    }

    final double maxY = (hourlyTotals.reduce((a, b) => a > b ? a : b)) * 1.2 + 1;

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceBetween,
        maxY: maxY,
        titlesData: FlTitlesData(
          show: true,
          leftTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 40),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (value, meta) {
                final i = value.toInt();
                if (i % 3 == 0) {
                  return Text('$i');
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(
          show: true,
          border: const Border(
            bottom: BorderSide(color: Colors.black12),
            left: BorderSide(color: Colors.black12),
          ),
        ),
        barGroups: List.generate(24, (index) {
          return BarChartGroupData(x: index, barRods: [
            BarChartRodData(
              toY: hourlyTotals[index],
              width: 10,
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(4),
                topRight: Radius.circular(4),
              ),
              gradient: const LinearGradient(
                colors: [Color(0xFF42A5F5), Color(0xFF1976D2)],
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
              ),
              backDrawRodData: BackgroundBarChartRodData(
                show: true,
                toY: maxY,
                color: Colors.grey.withOpacity(0.08),
              ),
            ),
          ]);
        }),
        barTouchData: BarTouchData(
          enabled: true,
          touchTooltipData: BarTouchTooltipData(
            tooltipBgColor: Colors.blueGrey,
            getTooltipItem: (group, groupIndex, rod, rodIndex) {
              final hour = group.x.toInt();
              return BarTooltipItem(
                '${hour.toString().padLeft(2, '0')}:00\n₹${hourlyTotals[hour].toStringAsFixed(2)}',
                const TextStyle(color: Colors.white),
              );
            },
          ),
        ),
      ),
    );
  }
}

