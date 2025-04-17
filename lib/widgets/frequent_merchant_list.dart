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
    if (transactions.isEmpty) {
      return const Center(child: Text('No transaction data available'));
    }

    // Calculate merchant frequency and spending
    final Map<String, List<Transaction>> merchantData = {};
    for (var transaction in transactions) {
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
      final average = total / count;

      // Find most recent transaction date
      final mostRecent = merchantTransactions
          .map((t) => t.dateTime)
          .reduce((a, b) => a.isAfter(b) ? a : b);

      return {
        'name': merchantName,
        'count': count,
        'total': total,
        'average': average,
        'lastTransaction': mostRecent,
      };
    }).toList();

    // Sort by frequency (most frequent first)
    merchants.sort((a, b) => (b['count'] as int).compareTo(a['count'] as int));

    // Take top merchants based on displayCount
    final topMerchants = merchants.take(displayCount).toList();

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: topMerchants.length,
      itemBuilder: (context, index) {
        final merchant = topMerchants[index];
        final name = merchant['name'] as String;
        final count = merchant['count'] as int;
        final total = merchant['total'] as double;
        final average = merchant['average'] as double;
        final lastDate = merchant['lastTransaction'] as DateTime;

        // Calculate days since last transaction
        final daysSince = DateTime.now().difference(lastDate).inDays;

        return Card(
          elevation: 2,
          margin: const EdgeInsets.symmetric(vertical: 4),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // Circle with count
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.blue.withOpacity(0.8),
                  ),
                  child: Center(
                    child: Text(
                      count.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
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
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: DefaultTextStyle.of(context).style,
                                children: [
                                  const TextSpan(
                                    text: 'Total: ',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '₹${total.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          Expanded(
                            child: RichText(
                              text: TextSpan(
                                style: DefaultTextStyle.of(context).style,
                                children: [
                                  const TextSpan(
                                    text: 'Avg: ',
                                    style: TextStyle(
                                      color: Colors.grey,
                                      fontSize: 12,
                                    ),
                                  ),
                                  TextSpan(
                                    text: '₹${average.toStringAsFixed(2)}',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Days since last transaction
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    daysSince == 0
                        ? 'Today'
                        : daysSince == 1
                        ? 'Yesterday'
                        : '$daysSince days ago',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}