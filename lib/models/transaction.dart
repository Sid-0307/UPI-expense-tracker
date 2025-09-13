class Transaction {
  double amount;
  String merchant;
  DateTime dateTime;
  int? transactionCount; // For aggregated transactions

  Transaction({
    required this.amount,
    required this.merchant,
    required this.dateTime,
    this.transactionCount,
  });

  // Helper method to identify if transaction is from current month
  bool isFromCurrentMonth() {
    final now = DateTime.now();
    return dateTime.month == now.month && dateTime.year == now.year;
  }
}