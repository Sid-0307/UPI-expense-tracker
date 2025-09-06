import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:upi_expense_tracker/models/transaction.dart';
import 'package:upi_expense_tracker/main.dart';
import 'package:upi_expense_tracker/utils/date_formatter.dart';
import 'package:upi_expense_tracker/widgets/daily_spend_chart.dart';
import 'package:upi_expense_tracker/widgets/merchant_chart.dart';
import 'package:upi_expense_tracker/widgets/weekday_spend_chart.dart';
import 'package:upi_expense_tracker/widgets/date_range_selector.dart';
import 'package:upi_expense_tracker/widgets/frequent_merchant_list.dart';
import 'package:upi_expense_tracker/widgets/summary_cards.dart';
import 'package:upi_expense_tracker/widgets/transaction_list_item.dart';
import 'package:upi_expense_tracker/widgets/spend_distribution_chart.dart';
import 'package:upi_expense_tracker/widgets/hourly_spend_chart.dart';
import 'package:upi_expense_tracker/widgets/cumulative_spend_chart.dart';
import 'package:upi_expense_tracker/widgets/category_pie_chart.dart';
import 'package:upi_expense_tracker/widgets/insights_panel.dart';
import 'package:upi_expense_tracker/utils/category_utils.dart';
import 'package:upi_expense_tracker/screens/merchant_manager_screen.dart';

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
  final Set<SpendCategory> _selectedCategories = {};

  @override
  void initState() {
    super.initState();
    // Initialize with last 30 days
    _endDate = DateTime.now();
    _startDate = _endDate.subtract(const Duration(days: 30));
    _updateFilteredTransactions();
    _tabController = TabController(length: 5, vsync: this);
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
    final base = _applyCategoryFilter(_filteredTransactions);
    if (!_isAggregated) {
      _aggregatedTransactions = List.from(base);
      return;
    }

    // Group by merchant name
    final Map<String, List<Transaction>> grouped = {};
    for (var transaction in base) {
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

  List<Transaction> _applyCategoryFilter(List<Transaction> input) {
    if (_selectedCategories.isEmpty) return input;
    return input.where((t) => _selectedCategories.contains(getCategoryForMerchant(t.merchant))).toList();
  }

  void _toggleCategory(SpendCategory category) {
    setState(() {
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.add(category);
      }
      _updateAggregatedTransactions();
    });
  }

  Widget _categoryChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        FilterChip(
          label: const Text('All'),
          selected: _selectedCategories.isEmpty,
          onSelected: (_) {
            setState(() {
              _selectedCategories.clear();
              _updateAggregatedTransactions();
            });
          },
        ),
        ...SpendCategory.values.map((c) => FilterChip(
          label: Text(kCategoryInfo[c]!.name),
          selected: _selectedCategories.contains(c),
          onSelected: (_) => _toggleCategory(c),
          avatar: Icon(kCategoryInfo[c]!.icon, size: 16, color: kCategoryInfo[c]!.color),
          selectedColor: kCategoryInfo[c]!.color.withOpacity(0.15),
          checkmarkColor: kCategoryInfo[c]!.color,
        )),
      ],
    );
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
      ),
      body: widget.transactions.isEmpty
          ? _buildEmptyState()
          : Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: DateRangeSelector(
              startDate: _startDate,
              endDate: _endDate,
              onDateRangeChanged: _setDateRange,
              onQuickRangeSelected: _setQuickDateRange,
            ),
          ),
          const Divider(height: 1),
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Trends'),
                Tab(text: 'Categories'),
                Tab(text: 'Merchants'),
                Tab(text: 'Transactions'),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildTrendsTab(),
                _buildCategoriesTab(),
                _buildMerchantsTab(),
                _buildTransactionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SummaryCards(transactions: _filteredTransactions),

            const SizedBox(height: 24),

            _sectionTitle('Insights'),
            const SizedBox(height: 8),
            _sectionCard(
              InsightsPanel(transactions: _applyCategoryFilter(_filteredTransactions), startDate: _startDate, endDate: _endDate),
            ),

            const SizedBox(height: 24),

            _sectionTitle('Quick Filters'),
            const SizedBox(height: 8),
            _sectionCard(_categoryChips()),

            const SizedBox(height: 24),

            _sectionTitle('Daily Spending Trend'),
            const SizedBox(height: 8),
            _sectionCard(
              SizedBox(
                height: 220,
                child: DailySpendChart(
                    transactions: _applyCategoryFilter(_filteredTransactions),
                    startDate: _startDate,
                    endDate: _endDate
                ),
              ),
            ),

            const SizedBox(height: 24),

            _sectionTitle('Highlights'),
            const SizedBox(height: 8),
            _sectionCard(FrequentMerchantsList(transactions: _applyCategoryFilter(_filteredTransactions))),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildTrendsTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Cumulative Spend'),
            const SizedBox(height: 8),
            _sectionCard(
              SizedBox(
                height: 220,
                child: CumulativeSpendChart(
                  transactions: _applyCategoryFilter(_filteredTransactions),
                  startDate: _startDate,
                  endDate: _endDate,
                ),
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('Spending by Day of Week'),
            const SizedBox(height: 8),
            _sectionCard(
              SizedBox(
                height: 220,
                child: WeekdaySpendChart(transactions: _applyCategoryFilter(_filteredTransactions)),
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('Hourly Spend Pattern'),
            const SizedBox(height: 8),
            _sectionCard(
              SizedBox(
                height: 220,
                child: HourlySpendChart(transactions: _applyCategoryFilter(_filteredTransactions)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Filter by Category'),
            const SizedBox(height: 8),
            _sectionCard(_categoryChips()),
            const SizedBox(height: 16),
            _sectionTitle('Spend Distribution (Pie)'),
            const SizedBox(height: 8),
            _sectionCard(
              SizedBox(
                height: 240,
                child: SpendDistributionChart(transactions: _applyCategoryFilter(_filteredTransactions)),
              ),
            ),
            const SizedBox(height: 24),
            _sectionTitle('Category Breakdown'),
            const SizedBox(height: 8),
            _sectionCard(
              SizedBox(
                height: 240,
                child: CategoryPieChart(transactions: _applyCategoryFilter(_filteredTransactions)),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMerchantsTab() {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Top Merchants (Bar)'),
            const SizedBox(height: 8),
            _sectionCard(
              SizedBox(
                height: 220,
                child: MerchantChart(transactions: _applyCategoryFilter(_filteredTransactions)),
              ),
            ),
            const SizedBox(height: 24),
            Align(
              alignment: Alignment.centerRight,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const MerchantManagerScreen()),
                  );
                },
                icon: const Icon(Icons.manage_accounts),
                label: const Text('Manage Merchants'),
              ),
            ),
            const SizedBox(height: 8),
            _sectionTitle('Frequent Merchants'),
            const SizedBox(height: 8),
            _sectionCard(FrequentMerchantsList(transactions: _applyCategoryFilter(_filteredTransactions))),
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
      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    );
  }

  Widget _sectionCard(Widget child) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: child,
      ),
    );
  }
}