import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:upi_expense_tracker/models/transaction.dart';

class CumulativeSpendChart extends StatelessWidget {
  final List<Transaction> transactions;
  final DateTime startDate;
  final DateTime endDate;

  const CumulativeSpendChart({
    Key? key,
    required this.transactions,
    required this.startDate,
    required this.endDate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (startDate.isAfter(endDate)) {
      return const SizedBox.shrink();
    }

    final dates = <DateTime>[];
    final int days = endDate.difference(startDate).inDays;
    for (int i = 0; i <= days; i++) {
      dates.add(DateTime(startDate.year, startDate.month, startDate.day + i));
    }

    final Map<DateTime, double> dailyTotals = {for (final d in dates) d: 0.0};
    for (final t in transactions) {
      final d = DateTime(t.dateTime.year, t.dateTime.month, t.dateTime.day);
      if (d.isBefore(startDate) || d.isAfter(endDate)) continue;
      dailyTotals[d] = (dailyTotals[d] ?? 0) + t.amount;
    }

    double running = 0.0;
    final List<FlSpot> spots = [];
    for (int i = 0; i < dates.length; i++) {
      running += dailyTotals[dates[i]] ?? 0.0;
      spots.add(FlSpot(i.toDouble(), running));
    }

    final maxY = (running == 0 ? 100 : running) * 1.2;
    final dateFormat = DateFormat('dd MMM');

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (dates.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(show: true, drawVerticalLine: false),
        borderData: FlBorderData(
          show: true,
          border: Border(
            bottom: BorderSide(color: Colors.black12),
            left: BorderSide(color: Colors.black12),
          ),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < dates.length) {
                  if (dates.length <= 10 || idx % (dates.length ~/ 5) == 0) {
                    return Text(dateFormat.format(dates[idx]), style: const TextStyle(fontSize: 10));
                  }
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: false,
            color: Colors.teal,
            barWidth: 3,
            dotData: FlDotData(show: false),
            belowBarData: BarAreaData(show: true, color: Colors.teal.withOpacity(0.15)),
          ),
        ],
        lineTouchData: LineTouchData(
          touchTooltipData: LineTouchTooltipData(
            tooltipBgColor: Colors.teal.shade400,
            getTooltipItems: (touched) {
              return touched.map((t) {
                final i = t.x.toInt();
                final date = dates[i];
                return LineTooltipItem(
                  '${dateFormat.format(date)}\n₹${t.y.toStringAsFixed(2)}',
                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                );
              }).toList();
            },
          ),
        ),
      ),
    );
  }
}

