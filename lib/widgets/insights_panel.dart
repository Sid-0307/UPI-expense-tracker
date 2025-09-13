import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:upi_expense_tracker/models/transaction.dart';
import 'package:upi_expense_tracker/utils/category_utils.dart';

class InsightsPanel extends StatelessWidget {
  final List<Transaction> transactions;
  final DateTime? startDate;
  final DateTime? endDate;

  const InsightsPanel({Key? key, required this.transactions, this.startDate, this.endDate}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const SizedBox.shrink();
    }

    final currency = NumberFormat.currency(symbol: '₹', decimalDigits: 0, locale: 'en_IN');

    final double total = transactions.fold(0.0, (s, t) => s + t.amount);

    // Daily stats
    final Map<DateTime, double> daily = {};
    for (final t in transactions) {
      final d = DateTime(t.dateTime.year, t.dateTime.month, t.dateTime.day);
      daily[d] = (daily[d] ?? 0) + t.amount;
    }
    final avgDaily = daily.isEmpty ? 0.0 : daily.values.reduce((a, b) => a + b) / daily.length;
    final peakDayAmount = daily.isEmpty ? 0.0 : daily.values.reduce((a, b) => a > b ? a : b);
    final peakDay = daily.entries.firstWhere((e) => e.value == peakDayAmount, orElse: () => MapEntry(DateTime.now(), 0.0)).key;

    // Top merchant
    final Map<String, double> byMerchant = {};
    for (final t in transactions) {
      byMerchant[t.merchant] = (byMerchant[t.merchant] ?? 0) + t.amount;
    }
    final topMerchant = byMerchant.entries.isEmpty
        ? null
        : (byMerchant.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first;

    // Top category
    final Map<SpendCategory, double> byCategory = {};
    for (final t in transactions) {
      final cat = getCategoryForMerchant(t.merchant);
      byCategory[cat] = (byCategory[cat] ?? 0) + t.amount;
    }
    final topCategory = byCategory.entries.isEmpty
        ? null
        : (byCategory.entries.toList()..sort((a, b) => b.value.compareTo(a.value))).first;

    // Recency
    final latest = transactions.map((t) => t.dateTime).reduce((a, b) => a.isAfter(b) ? a : b);
    final daysSince = DateTime.now().difference(latest).inDays;

    // Spending velocity: last 7 days vs previous 7 days
    final now = DateTime.now();
    final startCurrent = now.subtract(const Duration(days: 7));
    final startPrev = now.subtract(const Duration(days: 14));
    double sumCurrent = 0, sumPrev = 0;
    for (final t in transactions) {
      if (t.dateTime.isAfter(startCurrent)) {
        sumCurrent += t.amount;
      } else if (t.dateTime.isAfter(startPrev) && t.dateTime.isBefore(startCurrent)) {
        sumPrev += t.amount;
      }
    }
    final velocityChange = sumPrev == 0 ? null : ((sumCurrent - sumPrev) / sumPrev) * 100;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (startDate != null && endDate != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              'Range: ${DateFormat('dd MMM').format(startDate!)} - ${DateFormat('dd MMM').format(endDate!)}',
              style: TextStyle(color: Colors.grey[600], fontSize: 12),
            ),
          ),
        _insightTile(
          icon: Icons.auto_graph,
          color: Colors.indigo,
          title: 'Average daily spend',
          value: currency.format(avgDaily),
        ),
        const SizedBox(height: 8),
        _insightTile(
          icon: Icons.calendar_today,
          color: Colors.purple,
          title: 'Peak spend day',
          value: '${DateFormat('EEE, dd MMM').format(peakDay)} · ${currency.format(peakDayAmount)}',
        ),
        const SizedBox(height: 8),
        if (topMerchant != null)
          _insightTile(
            icon: Icons.store,
            color: Colors.teal,
            title: 'Top merchant',
            value: '${topMerchant.key} · ${currency.format(topMerchant.value)}',
          ),
        if (topMerchant != null) const SizedBox(height: 8),
        if (topCategory != null)
          _insightTile(
            icon: getCategoryIcon(topCategory.key),
            color: getCategoryColor(topCategory.key),
            title: 'Top category',
            value: '${getCategoryName(topCategory.key)} · ${currency.format(topCategory.value)}',
          ),
        if (topCategory != null) const SizedBox(height: 8),
        _insightTile(
          icon: Icons.schedule,
          color: Colors.orange,
          title: 'Last transaction',
          value: daysSince == 0 ? 'Today' : daysSince == 1 ? 'Yesterday' : '$daysSince days ago',
        ),
        const SizedBox(height: 8),
        _insightTile(
          icon: Icons.speed,
          color: Colors.redAccent,
          title: 'Spending velocity (7d)',
          value: velocityChange == null
              ? 'No prior data'
              : '${velocityChange > 0 ? '+' : ''}${velocityChange.toStringAsFixed(0)}% vs prev 7d',
        ),
        const SizedBox(height: 8),
        _insightTile(
          icon: Icons.do_not_disturb_on_total_silence,
          color: Colors.grey,
          title: 'No-spend days',
          value: _noSpendDaysText(daily, startDate: startDate, endDate: endDate),
        ),
      ],
    );
  }

  String _noSpendDaysText(Map<DateTime, double> daily, {DateTime? startDate, DateTime? endDate}) {
    if (startDate == null || endDate == null) {
      return '${daily.values.where((v) => v == 0).length} days';
    }
    int count = 0;
    for (DateTime d = DateTime(startDate.year, startDate.month, startDate.day);
        !d.isAfter(endDate);
        d = d.add(const Duration(days: 1))) {
      if (!(daily[d] != null && daily[d]! > 0)) count++;
    }
    return '$count days';
  }

  Widget _insightTile({
    required IconData icon,
    required Color color,
    required String title,
    required String value,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(color: color.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: Colors.grey[700], fontSize: 12)),
                const SizedBox(height: 2),
                Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

