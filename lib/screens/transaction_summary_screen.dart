import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:upi_expense_tracker/models/transaction.dart';
import 'package:upi_expense_tracker/main.dart';
import 'package:upi_expense_tracker/utils/date_formatter.dart';
import 'package:upi_expense_tracker/widgets/daily_spend_chart.dart';
import 'package:upi_expense_tracker/widgets/merchant_chart.dart';
import 'package:upi_expense_tracker/widgets/weekday_spend_chart.dart';
import 'package:upi_expense_tracker/widgets/compact_date_selector.dart';
import 'package:upi_expense_tracker/widgets/collapsible_category_filter.dart';
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

import '../widgets/date_range_selector.dart';

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
  
  // Sorting options
  String _aggregateSortBy = 'frequency_high'; // frequency_high, amount_high
  String _splitSortBy = 'amount_high'; // amount_high

  @override
  void initState() {
    super.initState();
    // Initialize with last 30 days
    _endDate = DateTime.now();
    _startDate = _endDate.subtract(const Duration(days: 30));
    _updateFilteredTransactions();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (mounted) setState(() {});
    });
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
      _sortSplitTransactions();
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
        merchant: merchantName, // Remove transaction count from name
        dateTime: latestDate,
        transactionCount: transactions.length, // Store count separately
      );
    }).toList();

    _sortAggregatedTransactions();
  }

  void _sortAggregatedTransactions() {
    switch (_aggregateSortBy) {
      case 'frequency_high':
        _aggregatedTransactions.sort((a, b) => (b.transactionCount ?? 0).compareTo(a.transactionCount ?? 0));
        break;
      case 'amount_high':
        _aggregatedTransactions.sort((a, b) => b.amount.compareTo(a.amount));
        break;
    }
  }

  void _sortSplitTransactions() {
    // Split transactions always sort by amount high to low
    _aggregatedTransactions.sort((a, b) => b.amount.compareTo(a.amount));
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

  int _getUniqueMerchantCount() {
    return _filteredTransactions.map((t) => t.merchant).toSet().length;
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
          :           Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: CompactDateSelector(
              startDate: _startDate,
              endDate: _endDate,
              onDateRangeChanged: _setDateRange,
              onQuickRangeSelected: _setQuickDateRange,
            ),
          ),
          Material(
            color: Theme.of(context).colorScheme.surface,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Trends'),
                Tab(text: 'Categories'),
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
                _buildTransactionsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _tabController.index == 2
          ? FloatingActionButton.extended(
              onPressed: () {
                // Build unique merchant names from currently filtered transactions
                final uniqueMerchants = _applyCategoryFilter(_filteredTransactions)
                    .map((t) => t.merchant)
                    .toSet()
                    .toList()
                  ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => MerchantManagerScreen(knownMerchants: uniqueMerchants)),
                );
              },
              icon: const Icon(Icons.manage_accounts),
              label: const Text('Manage Merchants'),
            )
          : null,
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

            CollapsibleCategoryFilter(
              selectedCategories: _selectedCategories,
              onCategoryToggled: _toggleCategory,
              onClearAll: () {
                setState(() {
                  _selectedCategories.clear();
                  _updateAggregatedTransactions();
                });
              },
            ),

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
            CollapsibleCategoryFilter(
              selectedCategories: _selectedCategories,
              onCategoryToggled: _toggleCategory,
              onClearAll: () {
                setState(() {
                  _selectedCategories.clear();
                  _updateAggregatedTransactions();
                });
              },
            ),
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
            const SizedBox(height: 24),
            _sectionTitle('Top Merchants'),
            const SizedBox(height: 8),
            _sectionCard(
              SizedBox(
                height: 220,
                child: MerchantChart(transactions: _applyCategoryFilter(_filteredTransactions)),
              ),
            ),
            const SizedBox(height: 24),
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
    final displayTransactions = _isAggregated
        ? _aggregatedTransactions
        : _applyCategoryFilter(_filteredTransactions);
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Horizontal Category Filter
          SizedBox(
            height: 40,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // All Categories button
                  Padding(
                    padding: const EdgeInsets.only(right: 8.0),
                    child: _buildCategoryFilterChip(
                      label: 'All',
                      icon: Icons.all_inclusive,
                      isSelected: _selectedCategories.isEmpty,
                      color: scheme.primary,
                      onTap: () {
                        setState(() {
                          _selectedCategories.clear();
                          _updateAggregatedTransactions();
                        });
                      },
                    ),
                  ),
                  // Individual category buttons
                  ...getAllCategories().map((category) {
                    final categoryColor = category == SpendCategory.others
                        ? getCategoryColor(category, colorScheme: scheme)
                        : getCategoryColor(category);

                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: _buildCategoryFilterChip(
                        label: getCategoryName(category),
                        icon: getCategoryIcon(category),
                        isSelected: _selectedCategories.contains(category),
                        color: categoryColor,
                        onTap: () {
                          setState(() {
                            if (_selectedCategories.contains(category)) {
                              _selectedCategories.remove(category);
                            } else {
                              _selectedCategories.clear();
                              _selectedCategories.add(category);
                            }
                            _updateAggregatedTransactions();
                          });
                        },
                      ),
                    );
                  }).toList(),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // View toggle and sort toggle
          Row(
            children: [
              // View Toggle Button
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _toggleAggregation,
                  icon: Icon(
                    _isAggregated ? Icons.splitscreen : Icons.group_work,
                    size: 18,
                    color: scheme.onPrimary, // Set icon color to white
                  ),
                  label: Text(_isAggregated ? 'Split View' : 'Aggregate View'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: scheme.primary,
                    foregroundColor: scheme.onPrimary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ),
              ..._isAggregated
                  ? [
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _aggregateSortBy = _aggregateSortBy == 'frequency_high'
                            ? 'amount_high'
                            : 'frequency_high';
                        _updateAggregatedTransactions();
                      });
                    },
                    icon: Icon(
                      _aggregateSortBy != 'frequency_high'
                          ? Icons.trending_up
                          : Icons.attach_money,
                      size: 18,
                      color: scheme.onPrimary,
                    ),
                    label: Text(
                      _aggregateSortBy != 'frequency_high'
                          ? 'By Frequency'
                          : 'By Amount',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: scheme.primary,
                      foregroundColor: scheme.onPrimary,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                ),
              ]
                  : [],

            ],
          ),

          const SizedBox(height: 16),

          // Transaction List
          Expanded(
            child: displayTransactions.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.receipt_long, size: 64, color: scheme.onSurfaceVariant),
                  const SizedBox(height: 16),
                  Text(
                    _selectedCategories.isEmpty
                        ? 'No transactions in selected period'
                        : 'No transactions found for selected category',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: displayTransactions.length,
              itemBuilder: (context, index) {
                return TransactionListItem(
                  transaction: displayTransactions[index],
                  isCurrentMonth: displayTransactions[index].isFromCurrentMonth(),
                  showTransactionCount: _isAggregated,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
  }) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected
              ? color.withOpacity(0.15)
              : scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? color
                : scheme.outlineVariant,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected
                  ? color
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected
                    ? color
                    : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Widget _buildTransactionsTab() {
  //   final displayTransactions = _isAggregated ? _aggregatedTransactions : _filteredTransactions;
  //   final scheme = Theme.of(context).colorScheme;
  //
  //   return Padding(
  //     padding: const EdgeInsets.all(16.0),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         // Header with transaction and merchant counts
  //         // Row(
  //         //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
  //         //   children: [
  //         //     Container(
  //         //       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  //         //       decoration: BoxDecoration(
  //         //         color: scheme.primary.withOpacity(0.1),
  //         //         borderRadius: BorderRadius.circular(16),
  //         //         border: Border.all(color: scheme.primary.withOpacity(0.3)),
  //         //       ),
  //         //       child: Text(
  //         //         '${displayTransactions.length} transactions',
  //         //         style: TextStyle(
  //         //           color: scheme.primary,
  //         //           fontSize: 12,
  //         //           fontWeight: FontWeight.w600,
  //         //         ),
  //         //       ),
  //         //     ),
  //         //     Container(
  //         //       padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
  //         //       decoration: BoxDecoration(
  //         //         color: scheme.primary.withOpacity(0.1),
  //         //         borderRadius: BorderRadius.circular(16),
  //         //         border: Border.all(color: scheme.primary.withOpacity(0.3)),
  //         //       ),
  //         //       child: Text(
  //         //         _isAggregated
  //         //             ? '${displayTransactions.length} merchants'
  //         //             : '${_getUniqueMerchantCount()} merchants',
  //         //         style: TextStyle(
  //         //           color: scheme.primary,
  //         //           fontSize: 12,
  //         //           fontWeight: FontWeight.w600,
  //         //         ),
  //         //       ),
  //         //     ),
  //         //   ],
  //         // ),
  //         // const SizedBox(height: 16),
  //
  //         // View toggle and sort toggle
  //         Row(
  //           children: [
  //             // View Toggle Button
  //             Expanded(
  //               child: ElevatedButton.icon(
  //                 onPressed: _toggleAggregation,
  //                 icon: Icon(
  //                   _isAggregated ? Icons.splitscreen : Icons.group_work,
  //                   size: 18,
  //                   color: scheme.onPrimary, // Set icon color to white
  //                 ),
  //                 label: Text(_isAggregated ? 'Split View' : 'Aggregate View'),
  //                 style: ElevatedButton.styleFrom(
  //                   backgroundColor: scheme.primary,
  //                   foregroundColor: scheme.onPrimary,
  //                   padding: const EdgeInsets.symmetric(vertical: 12),
  //                   shape: RoundedRectangleBorder(
  //                     borderRadius: BorderRadius.circular(10),
  //                   ),
  //                 ),
  //               ),
  //             ),
  //             ..._isAggregated
  //                 ? [
  //               const SizedBox(width: 12),
  //               Expanded(
  //                 child: ElevatedButton.icon(
  //                   onPressed: () {
  //                     setState(() {
  //                       _aggregateSortBy = _aggregateSortBy == 'frequency_high'
  //                           ? 'amount_high'
  //                           : 'frequency_high';
  //                       _updateAggregatedTransactions();
  //                     });
  //                   },
  //                   icon: Icon(
  //                     _aggregateSortBy != 'frequency_high'
  //                         ? Icons.trending_up
  //                         : Icons.attach_money,
  //                     size: 18,
  //                     color: scheme.onPrimary,
  //                   ),
  //                   label: Text(
  //                     _aggregateSortBy != 'frequency_high'
  //                         ? 'By Frequency'
  //                         : 'By Amount',
  //                   ),
  //                   style: ElevatedButton.styleFrom(
  //                     backgroundColor: scheme.primary,
  //                     foregroundColor: scheme.onPrimary,
  //                     padding: const EdgeInsets.symmetric(vertical: 12),
  //                     shape: RoundedRectangleBorder(
  //                       borderRadius: BorderRadius.circular(10),
  //                     ),
  //                   ),
  //                 ),
  //               ),
  //             ]
  //                 : [],
  //
  //           ],
  //         ),
  //
  //         const SizedBox(height: 16),
  //
  //         // Transaction List
  //         Expanded(
  //           child: displayTransactions.isEmpty
  //               ? Center(
  //             child: Column(
  //               mainAxisAlignment: MainAxisAlignment.center,
  //               children: [
  //                 Icon(Icons.receipt_long, size: 64, color: scheme.onSurfaceVariant),
  //                 const SizedBox(height: 16),
  //                 Text(
  //                   'No transactions in selected period',
  //                   style: TextStyle(
  //                     color: scheme.onSurfaceVariant,
  //                     fontSize: 16,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           )
  //               : ListView.builder(
  //             itemCount: displayTransactions.length,
  //             itemBuilder: (context, index) {
  //               return TransactionListItem(
  //                 transaction: displayTransactions[index],
  //                 isCurrentMonth: displayTransactions[index].isFromCurrentMonth(),
  //                 showTransactionCount: _isAggregated,
  //               );
  //             },
  //           ),
  //         ),
  //       ],
  //     ),
  //   );
  // }

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
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: EdgeInsets.zero,
      color: scheme.surface,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: scheme.outlineVariant.withOpacity(0.5),
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: child,
      ),
    );
  }
}