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
    final scheme = Theme.of(context).colorScheme;

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
      if (t.type == 'debit') {  // Only count debits for spending
        final d = DateTime(t.dateTime.year, t.dateTime.month, t.dateTime.day);
        if (d.isBefore(startDate) || d.isAfter(endDate)) continue;
        dailyTotals[d] = (dailyTotals[d] ?? 0) + t.amount;
      }
    }

    double running = 0.0;
    final List<FlSpot> spots = [];
    for (int i = 0; i < dates.length; i++) {
      running += dailyTotals[dates[i]] ?? 0.0;
      spots.add(FlSpot(i.toDouble(), running));
    }

    if (spots.isEmpty) {
      return Center(
        child: Text(
          'No data available',
          style: TextStyle(color: scheme.onSurface.withOpacity(0.6)),
        ),
      );
    }

    final maxY = (running == 0 ? 100 : running) * 1.1;
    final dateFormat = dates.length > 30
        ? DateFormat('dd/MM')
        : DateFormat('dd MMM');

    return LineChart(
      LineChartData(
        minX: 0,
        maxX: (dates.length - 1).toDouble(),
        minY: 0,
        maxY: maxY,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          horizontalInterval: _getInterval(maxY),
          getDrawingHorizontalLine: (value) {
            return FlLine(
              color: scheme.onSurface.withOpacity(0.1),
              strokeWidth: 1,
              dashArray: [5, 5],
            );
          },
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
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 20,
              interval: _getXAxisInterval(dates.length),
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < dates.length) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      dateFormat.format(dates[idx]),
                      style: TextStyle(
                        fontSize: 10,
                        color: scheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 45,
              interval: _getInterval(maxY),
              getTitlesWidget: (value, meta) {
                return Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Text(
                    _formatCurrency(value),
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.onSurface.withOpacity(0.7),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.right,
                  ),
                );
              },
            ),
          ),
          topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            curveSmoothness: 0.2,
            color: scheme.secondary,
            barWidth: 2.5,
            isStrokeCapRound: true,
            dotData: FlDotData(
              show: spots.length <= 15,
              getDotPainter: (spot, percent, barData, index) {
                return FlDotCirclePainter(
                  radius: 3,
                  color: scheme.secondary,
                  strokeWidth: 2,
                  strokeColor: scheme.surface,
                );
              },
            ),
            belowBarData: BarAreaData(
              show: true,
              gradient: LinearGradient(
                colors: [
                  scheme.secondary.withOpacity(0.25),
                  scheme.secondary.withOpacity(0.05),
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
            getTooltipItems: (touched) {
              return touched.map((t) {
                final i = t.x.toInt();
                if (i >= 0 && i < dates.length) {
                  final date = dates[i];
                  return LineTooltipItem(
                    '${DateFormat('dd MMM yyyy').format(date)}\n${_formatCurrency(t.y)}',
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
