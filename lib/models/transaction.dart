class Transaction {
  double amount;
  String merchant;
  DateTime dateTime;

  Transaction({
    required this.amount,
    required this.merchant,
    required this.dateTime,
  });

  // Helper method to identify if transaction is from current month
  bool isFromCurrentMonth() {
    final now = DateTime.now();
    return dateTime.month == now.month && dateTime.year == now.year;
  }
}