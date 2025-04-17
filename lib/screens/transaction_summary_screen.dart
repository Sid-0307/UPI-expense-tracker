import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:upi_expense_tracker/models/transaction.dart';
import 'package:upi_expense_tracker/utils/date_formatter.dart';
import 'package:upi_expense_tracker/widgets/daily_spend_chart.dart';
import 'package:upi_expense_tracker/widgets/merchant_chart.dart';
import 'package:upi_expense_tracker/widgets/weekday_spend_chart.dart';
import 'package:upi_expense_tracker/widgets/date_range_selector.dart';
import 'package:upi_expense_tracker/widgets/frequent_merchant_list.dart';
import 'package:upi_expense_tracker/widgets/summary_cards.dart';
import 'package:upi_expense_tracker/widgets/transaction_list_item.dart';

class TransactionSummaryScreen extends StatefulWidget {
  final List<Transaction> transactions;

  const TransactionSummaryScreen({
    Key? key,
    required this.transactions,
  }) : super(key: key);

  @override
  State<TransactionSummaryScreen> createState() => _TransactionSummaryScreenState();
}

class _TransactionSummaryScreenState extends State<TransactionSummaryScreen> with SingleTickerProviderStateMixin {
  late DateTime _startDate;
  late DateTime _endDate;
  late List<Transaction> _filteredTransactions;
  late TabController _tabController;
  bool _isAggregated = false;
  List<Transaction> _aggregatedTransactions = [];

  @override
  void initState() {
    super.initState();
    // Initialize with last 30 days
    _endDate = DateTime.now();
    _startDate = _endDate.subtract(const Duration(days: 30));
    _updateFilteredTransactions();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _updateFilteredTransactions() {
    setState(() {
      _filteredTransactions = widget.transactions.where((t) {
        return t.dateTime.isAfter(_startDate) &&
            t.dateTime.isBefore(_endDate.add(const Duration(days: 1)));
      }).toList();

      // Reset aggregation when filter changes
      _isAggregated = false;
      _updateAggregatedTransactions();
    });
  }

  void _updateAggregatedTransactions() {
    if (!_isAggregated) {
      _aggregatedTransactions = List.from(_filteredTransactions);
      return;
    }

    // Group by merchant name
    final Map<String, List<Transaction>> grouped = {};
    for (var transaction in _filteredTransactions) {
      if (!grouped.containsKey(transaction.merchant)) {
        grouped[transaction.merchant] = [];
      }
      grouped[transaction.merchant]!.add(transaction);
    }

    // Create aggregated transactions
    _aggregatedTransactions = grouped.entries.map((entry) {
      final merchantName = entry.key;
      final transactions = entry.value;

      // Sum up amounts
      final totalAmount = transactions.fold(0.0, (sum, t) => sum + t.amount);

      // Use the most recent date
      final latestDate = transactions
          .map((t) => t.dateTime)
          .reduce((a, b) => a.isAfter(b) ? a : b);

      // Create a new transaction representing the group
      return Transaction(
        amount: totalAmount,
        merchant: '$merchantName (${transactions.length} transactions)',
        dateTime: latestDate,
      );
    }).toList();

    // Sort by date (newest first)
    _aggregatedTransactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));
  }

  void _toggleAggregation() {
    setState(() {
      _isAggregated = !_isAggregated;
      _updateAggregatedTransactions();
    });
  }

  void _setDateRange(DateTime start, DateTime end) {
    setState(() {
      _startDate = start;
      _endDate = end;
      _updateFilteredTransactions();
    });
  }

  void _setQuickDateRange(int days) {
    final end = DateTime.now();
    final start = end.subtract(Duration(days: days));
    _setDateRange(start, end);
  }

  @override
  Widget build(BuildContext context) {
    // Sort transactions by date (newest first)
    _filteredTransactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction Analysis'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Analytics'),
            Tab(text: 'Transactions'),
          ],
        ),
      ),
      body: widget.transactions.isEmpty
          ? _buildEmptyState()
          : TabBarView(
        controller: _tabController,
        children: [
          _buildAnalyticsTab(),
          _buildTransactionsTab(),
        ],
      ),
    );
  }

  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DateRangeSelector(
              startDate: _startDate,
              endDate: _endDate,
              onDateRangeChanged: _setDateRange,
              onQuickRangeSelected: _setQuickDateRange,
            ),

            const SizedBox(height: 16),

            SummaryCards(transactions: _filteredTransactions),

            const SizedBox(height: 24),

            _sectionTitle('Daily Spending Trend'),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: DailySpendChart(
                  transactions: _filteredTransactions,
                  startDate: _startDate,
                  endDate: _endDate
              ),
            ),

            const SizedBox(height: 24),

            _sectionTitle('Spending by Day of Week'),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: WeekdaySpendChart(transactions: _filteredTransactions),
            ),

            const SizedBox(height: 24),

            _sectionTitle('Top Merchants'),
            const SizedBox(height: 8),
            SizedBox(
              height: 220,
              child: MerchantChart(transactions: _filteredTransactions),
            ),

            const SizedBox(height: 24),

            _sectionTitle('Frequent Merchants'),
            const SizedBox(height: 8),
            FrequentMerchantsList(transactions: _filteredTransactions),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionsTab() {
    final displayTransactions = _isAggregated ? _aggregatedTransactions : _filteredTransactions;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          DateRangeSelector(
            startDate: _startDate,
            endDate: _endDate,
            onDateRangeChanged: _setDateRange,
            onQuickRangeSelected: _setQuickDateRange,
            compactMode: true,
          ),

          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Text(
                    'Transactions',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton.icon(
                    onPressed: _toggleAggregation,
                    icon: Icon(_isAggregated ? Icons.splitscreen : Icons.group_work),
                    label: Text(_isAggregated ? 'Split' : 'Aggregate'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      textStyle: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
              Text(
                _isAggregated
                    ? '${displayTransactions.length} merchants'
                    : '${displayTransactions.length} total',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Expanded(
            child: displayTransactions.isEmpty
                ? Center(
              child: Text(
                'No transactions in selected period',
                style: TextStyle(color: Colors.grey[600]),
              ),
            )
                : ListView.builder(
              itemCount: displayTransactions.length,
              itemBuilder: (context, index) {
                return TransactionListItem(
                  transaction: displayTransactions[index],
                  isCurrentMonth: displayTransactions[index].isFromCurrentMonth(),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: const [
          Icon(Icons.search_off, size: 80, color: Colors.grey),
          SizedBox(height: 16),
          Text(
            'No UPI transactions found',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'We couldn\'t find any UPI transactions in your SMS messages.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }
}