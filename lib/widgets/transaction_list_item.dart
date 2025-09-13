import 'package:flutter/material.dart';
import 'package:upi_expense_tracker/models/transaction.dart';
import 'package:upi_expense_tracker/utils/date_formatter.dart';
import 'package:upi_expense_tracker/utils/category_utils.dart';

class TransactionListItem extends StatelessWidget {
  final Transaction transaction;
  final bool isCurrentMonth;
  final bool showTransactionCount;

  const TransactionListItem({
    Key? key,
    required this.transaction,
    this.isCurrentMonth = true,
    this.showTransactionCount = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final category = getCategoryForMerchant(transaction.merchant);
    final scheme = Theme.of(context).colorScheme;
    final categoryColor = category == SpendCategory.others
        ? getCategoryColor(category, colorScheme: scheme)
        : getCategoryColor(category);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border(
            left: BorderSide(
              color: categoryColor,
              width: 5,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.light
                  ? scheme.primary.withOpacity(0.05)
                  : scheme.primary.withOpacity(0.12),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(12.0),
          child: Row(
            children: [
              // Transaction details
              SizedBox(width: 4,),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Row(
                          children: [
                            Text(
                              transaction.merchant,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                            SizedBox(width: 8,),
                            if (showTransactionCount && transaction.transactionCount != null)
                              Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                              decoration: BoxDecoration(
                                color: scheme.primary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: scheme.primary.withOpacity(0.3),
                                  width: 1,
                                ),
                              ),
                              child: Text(
                                '${transaction.transactionCount}x',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ]
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormatter.formatDateTime(transaction.dateTime),
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: categoryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            getCategoryIcon(category),
                            size: 12,
                            color: categoryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            getCategoryName(category),
                            style: TextStyle(
                              fontSize: 11,
                              color: categoryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              const SizedBox(width: 12),
              
              // Amount
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    '₹${transaction.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: Colors.red[700],
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Debit',
                    style: TextStyle(
                      fontSize: 10,
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}