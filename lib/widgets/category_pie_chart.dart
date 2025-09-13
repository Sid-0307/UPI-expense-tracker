import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:upi_expense_tracker/models/transaction.dart';
import 'package:upi_expense_tracker/utils/category_utils.dart';

class CategoryPieChart extends StatelessWidget {
  final List<Transaction> transactions;

  const CategoryPieChart({Key? key, required this.transactions}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Center(child: Text('No data available'));
    }

    final Map<SpendCategory, double> totals = {};
    double grandTotal = 0.0;
    for (final t in transactions) {
      final cat = getCategoryForMerchant(t.merchant);
      totals[cat] = (totals[cat] ?? 0) + t.amount;
      grandTotal += t.amount;
    }

    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final sections = entries.map((e) {
      final info = kCategoryInfo[e.key]!;
      return PieChartSectionData(
        color: info.color,
        value: e.value,
        radius: 60,
        title: '${((e.value / grandTotal) * 100).toStringAsFixed(0)}%',
        titleStyle: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
      );
    }).toList();

    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');

    return Row(
      children: [
        Expanded(
          child: PieChart(
            PieChartData(
              sections: sections,
              sectionsSpace: 2,
              centerSpaceRadius: 44,
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 160,
          child: ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final e = entries[index];
              final info = kCategoryInfo[e.key]!;
              final percent = grandTotal == 0 ? 0.0 : (e.value / grandTotal) * 100;
              return Row(
                children: [
                  Container(width: 10, height: 10, color: info.color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(info.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 2),
                        Text('${percent.toStringAsFixed(0)}% (${currency.format(e.value)})', style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

