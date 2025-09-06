import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:upi_expense_tracker/models/transaction.dart';
import 'package:upi_expense_tracker/utils/category_utils.dart';

class SummaryCards extends StatelessWidget {
  final List<Transaction> transactions;

  const SummaryCards({
    Key? key,
    required this.transactions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final totalSpent = transactions.fold<double>(
        0, (sum, transaction) => sum + transaction.amount);

    final averageSpend = transactions.isEmpty
        ? 0.0
        : totalSpent / transactions.length;

    final transactionsByDay = <DateTime, double>{};

    for (var transaction in transactions) {
      // Remove time component to group by day
      final dateOnly = DateTime(
          transaction.dateTime.year,
          transaction.dateTime.month,
          transaction.dateTime.day
      );

      transactionsByDay[dateOnly] =
          (transactionsByDay[dateOnly] ?? 0) + transaction.amount;
    }

    DateTime? mostExpensiveDay;
    double highestDailySpend = 0;

    transactionsByDay.forEach((date, amount) {
      if (amount > highestDailySpend) {
        highestDailySpend = amount;
        mostExpensiveDay = date;
      }
    });

    final dateFormat = DateFormat('dd MMM yyyy');
    final currencyFormat = NumberFormat.currency(
      symbol: '₹',
      decimalDigits: 2,
      locale: 'en_IN',
    );

    // Category leader for KPI
    final Map<SpendCategory, double> totalsByCat = {};
    for (final t in transactions) {
      final c = getCategoryForMerchant(t.merchant);
      totalsByCat[c] = (totalsByCat[c] ?? 0) + t.amount;
    }
    MapEntry<SpendCategory, double>? topCatEntry;
    if (totalsByCat.isNotEmpty) {
      final list = totalsByCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
      topCatEntry = list.first;
    }

    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildSummaryCard(
          context,
          title: 'Total Spent',
          value: currencyFormat.format(totalSpent),
          icon: Icons.account_balance_wallet,
          color: Colors.blue,
        ),
        _buildSummaryCard(
          context,
          title: 'Transactions',
          value: transactions.length.toString(),
          icon: Icons.receipt_long,
          color: Colors.green,
        ),
        _buildSummaryCard(
          context,
          title: 'Average Spend',
          value: currencyFormat.format(averageSpend),
          icon: Icons.trending_up,
          color: Colors.orange,
        ),
        _buildSummaryCard(
          context,
          title: 'Highest Spend Day',
          value: mostExpensiveDay != null
              ? dateFormat.format(mostExpensiveDay!)
              : 'N/A',
          subtitle: mostExpensiveDay != null
              ? currencyFormat.format(highestDailySpend)
              : '',
          icon: Icons.calendar_today,
          color: Colors.purple,
        ),
        if (topCatEntry != null)
          _buildSummaryCard(
            context,
            title: 'Top Category',
            value: getCategoryName(topCatEntry!.key),
            subtitle: currencyFormat.format(topCatEntry!.value),
            icon: getCategoryIcon(topCatEntry!.key),
            color: getCategoryColor(topCatEntry!.key),
          ),
      ],
    );
  }

  Widget _buildSummaryCard(
      BuildContext context, {
        required String title,
        required String value,
        String subtitle = '',
        required IconData icon,
        required Color color,
      }) {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Flexible(  // Add this wrapper
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[600],
                    ),
                    overflow: TextOverflow.ellipsis,  // Add this property
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}