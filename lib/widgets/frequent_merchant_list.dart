import 'package:flutter/material.dart';
import 'package:upi_expense_tracker/models/transaction.dart';
import 'package:intl/intl.dart';

class FrequentMerchantsList extends StatelessWidget {
  final List<Transaction> transactions;
  final int displayCount;

  const FrequentMerchantsList({
    Key? key,
    required this.transactions,
    this.displayCount = 5,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    // Filter for debit transactions only
    final debitTransactions = transactions.where((t) => t.type == 'debit').toList();

    if (debitTransactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sentiment_dissatisfied,
              size: 48,
              color: scheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No data available',
              style: TextStyle(
                color: scheme.onSurface.withOpacity(0.6),
                fontSize: 16,
              ),
            ),
          ],
        ),
      );
    }

    // Calculate merchant frequency and spending
    final Map<String, List<Transaction>> merchantData = {};
    for (var transaction in debitTransactions) {
      if (!merchantData.containsKey(transaction.merchant)) {
        merchantData[transaction.merchant] = [];
      }
      merchantData[transaction.merchant]!.add(transaction);
    }

    // Create list of merchants with their stats
    final merchants = merchantData.entries.map((entry) {
      final merchantName = entry.key;
      final merchantTransactions = entry.value;
      final count = merchantTransactions.length;
      final total = merchantTransactions.fold<double>(
          0, (sum, transaction) => sum + transaction.amount);

      // Calculate median spend
      final amounts = merchantTransactions.map((t) => t.amount).toList()..sort();
      final median = amounts.length % 2 == 0
          ? (amounts[amounts.length ~/ 2 - 1] + amounts[amounts.length ~/ 2]) / 2
          : amounts[amounts.length ~/ 2];

      return {
        'name': merchantName,
        'count': count,
        'total': total,
        'median': median,
      };
    }).toList();

    // Sort by frequency first (highest first), then by total amount for same frequency
    merchants.sort((a, b) {
      final countA = a['count'] as int;
      final countB = b['count'] as int;

      if (countA != countB) {
        return countB.compareTo(countA); // Higher frequency first
      }

      // If same frequency, sort by total amount (higher first)
      final totalA = a['total'] as double;
      final totalB = b['total'] as double;
      return totalB.compareTo(totalA);
    });

    // Take top merchants based on displayCount
    final topMerchants = merchants.take(displayCount).toList();

    return Column(
      children: List.generate(topMerchants.length, (index) {
        final merchant = topMerchants[index];
        final name = merchant['name'] as String;
        final count = merchant['count'] as int;
        final total = merchant['total'] as double;
        final median = merchant['median'] as double;

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.primary.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: scheme.outline.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Transaction count circle
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary.withOpacity(0.3),
                    border: Border.all(
                      color: scheme.primary.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Center(
                    child: Text(
                      '$count',
                      style: TextStyle(
                        color: scheme.primary,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Merchant details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: scheme.onSurface,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Median Spend - ${_formatCurrency(median)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurface.withOpacity(0.6),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Total amount
                Text(
                  _formatCurrency(total),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        );
      }),
    );
  }

  String _formatCurrency(double value) {
    if (value == 0) return '₹0';
    if (value >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k';
    }
    return '₹${value.toStringAsFixed(value % 1 == 0 ? 0 : 0)}';
  }
}