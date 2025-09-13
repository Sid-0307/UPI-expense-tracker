import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:upi_expense_tracker/models/transaction.dart';

class SpendDistributionChart extends StatelessWidget {
  final List<Transaction> transactions;
  final int topCount;

  const SpendDistributionChart({
    Key? key,
    required this.transactions,
    this.topCount = 6,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final Map<String, double> totalsByMerchant = {};
    for (final t in transactions) {
      totalsByMerchant[t.merchant] = (totalsByMerchant[t.merchant] ?? 0) + t.amount;
    }

    final entries = totalsByMerchant.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top = entries.take(topCount).toList();
    final othersTotal = entries.skip(topCount).fold<double>(0.0, (sum, e) => sum + e.value);

    final totalSpent = entries.fold<double>(0.0, (sum, e) => sum + e.value);

    final List<Color> palette = [
      const Color(0xFF1976D2),
      const Color(0xFF26C6DA),
      const Color(0xFF66BB6A),
      const Color(0xFFFFCA28),
      const Color(0xFFEF5350),
      const Color(0xFFAB47BC),
      const Color(0xFF8D6E63),
      const Color(0xFF42A5F5),
    ];

    final sections = <PieChartSectionData>[];
    for (int i = 0; i < top.length; i++) {
      final entry = top[i];
      final value = entry.value;
      final percent = totalSpent == 0 ? 0.0 : (value / totalSpent) * 100;
      sections.add(
        PieChartSectionData(
          color: palette[i % palette.length],
          value: value,
          radius: 60,
          title: '${percent.toStringAsFixed(0)}%',
          titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    if (othersTotal > 0) {
      sections.add(
        PieChartSectionData(
          color: Colors.grey.shade400,
          value: othersTotal,
          radius: 60,
          title: '${((othersTotal / totalSpent) * 100).toStringAsFixed(0)}%',
          titleStyle: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      );
    }

    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Row(
            children: [
              Expanded(
                child: PieChart(
                  PieChartData(
                    sectionsSpace: 2,
                    centerSpaceRadius: 44,
                    sections: sections,
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {},
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              SizedBox(
                width: 140,
                child: _Legend(
                  items: [
                    ...List.generate(top.length, (i) {
                      final e = top[i];
                      final percent = totalSpent == 0 ? 0.0 : (e.value / totalSpent) * 100;
                      return _LegendItem(
                        color: palette[i % palette.length],
                        label: e.key,
                        value: '${percent.toStringAsFixed(0)}% (${currency.format(e.value)})',
                      );
                    }),
                    if (othersTotal > 0)
                      _LegendItem(
                        color: Colors.grey.shade400,
                        label: 'Others',
                        value: '${((othersTotal / totalSpent) * 100).toStringAsFixed(0)}% (${currency.format(othersTotal)})',
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.center,
          child: Column(
            children: [
              const Text('Total Spent', style: TextStyle(color: Colors.grey)),
              const SizedBox(height: 4),
              Text(
                currency.format(totalSpent),
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _Legend extends StatelessWidget {
  final List<_LegendItem> items;

  const _Legend({Key? key, required this.items}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemBuilder: (context, index) {
        final item = items[index];
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(width: 10, height: 10, color: item.color),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    item.value,
                    style: TextStyle(fontSize: 11, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ],
        );
      },
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemCount: items.length,
    );
  }
}

class _LegendItem {
  final Color color;
  final String label;
  final String value;

  _LegendItem({required this.color, required this.label, required this.value});
}

