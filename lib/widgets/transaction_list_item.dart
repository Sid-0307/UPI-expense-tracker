import 'package:flutter/material.dart';
import 'package:upi_expense_tracker/models/transaction.dart';
import 'package:upi_expense_tracker/utils/date_formatter.dart';

class TransactionListItem extends StatelessWidget {
  final Transaction transaction;
  final bool isCurrentMonth;

  const TransactionListItem({
    Key? key,
    required this.transaction,
    this.isCurrentMonth = true,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        title: Text(
          transaction.merchant,
          style: const TextStyle(fontWeight: FontWeight.bold),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(DateFormatter.formatDateTime(transaction.dateTime)),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
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
            if (!isCurrentMonth)
              Container(
                margin: const EdgeInsets.only(top: 4),
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Previous month',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[600],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}