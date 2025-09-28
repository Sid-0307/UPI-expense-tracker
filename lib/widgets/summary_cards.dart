import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:upi_expense_tracker/models/transaction.dart';
import 'package:upi_expense_tracker/utils/category_utils.dart';

class SummaryCards extends StatefulWidget {
  final List<Transaction> transactions;

  const SummaryCards({
    Key? key,
    required this.transactions,
  }) : super(key: key);

  @override
  State<SummaryCards> createState() => _SummaryCardsState();
}

class _SummaryCardsState extends State<SummaryCards> {
  bool _showLegends = false;

  @override
  Widget build(BuildContext context) {


    final scheme = Theme.of(context).colorScheme;

    // Calculate all metrics
    final metrics = _calculateMetrics();
    final symbol = metrics.totalSpent < 0 ? '' : '+ ';
    final currencyFormat = NumberFormat.currency(
    symbol: '₹',
    decimalDigits: 2,
    locale: 'en_IN',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Cards Grid
        GridView.count(
          crossAxisCount: 2,
          crossAxisSpacing: 10,
          mainAxisSpacing: 10,
          childAspectRatio: 1.5,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            // Row 1
            _buildSummaryCard(
              context,
              title: 'Total Spent',
              value: symbol+currencyFormat.format(metrics.totalSpent.abs()),
              icon: Icons.account_balance_wallet,
              color: Colors.blue,
              onTap: () => _onCardTap('total_spent'),
            ),
            _buildSummaryCard(
              context,
              title: 'Transactions',
              value: metrics.transactionCount.toString(),
              icon: Icons.receipt_long,
              color: Colors.green,
              onTap: () => _onCardTap('transactions'),
            ),
            _buildSummaryCard(
              context,
              title: 'Median Spend',
              value: currencyFormat.format(metrics.medianSpend),
              subtitle: '${metrics.nonSpendDays} non-spend days',
              icon: Icons.trending_flat,
              color: Colors.teal,
              onTap: () => _onCardTap('median_spend'),
            ),

            // Row 2
            _buildSummaryCard(
              context,
              title: 'Highest Spend',
              value: currencyFormat.format(metrics.highestSpend),
              subtitle: metrics.highestSpendDate != null
                  ? DateFormat('dd MMM').format(metrics.highestSpendDate!)
                  : '',
              icon: Icons.trending_up,
              color: Colors.red,
              onTap: () => _onCardTap('highest_spend'),
            ),
            _buildSummaryCard(
              context,
              title: 'Top Category',
              value: metrics.topCategory != null
                  ? getCategoryName(metrics.topCategory!)
                  : 'N/A',
              subtitle: metrics.topCategoryAmount != null
                  ? currencyFormat.format(metrics.topCategoryAmount!)
                  : '',
              icon: metrics.topCategory != null
                  ? getCategoryIcon(metrics.topCategory!)
                  : Icons.category,
              color: metrics.topCategory != null
                  ? (metrics.topCategory == SpendCategory.others
                  ? getCategoryColor(metrics.topCategory!, colorScheme: scheme)
                  : getCategoryColor(metrics.topCategory!))
                  : Colors.grey,
              onTap: () => _onCardTap('top_category'),
            ),
            _buildSummaryCard(
              context,
              title: 'Top Merchant',
              value: metrics.topMerchant ?? 'N/A',
              subtitle: metrics.topMerchantAmount != null
                  ? currencyFormat.format(metrics.topMerchantAmount!)
                  : '',
              icon: Icons.store,
              color: Colors.indigo,
              onTap: () => _onCardTap('top_merchant'),
            ),

            // Row 3
            _buildSummaryCard(
              context,
              title: 'Weekly split',
              value: '${metrics.weekdayPercentage.toStringAsFixed(0)}% / ${metrics.weekendPercentage.toStringAsFixed(0)}%',
              subtitle: 'Weekday vs Weekend',
              icon: Icons.calendar_view_week,
              color: Colors.purple,
              onTap: () => _onCardTap('weekday_weekend'),
            ),
            _buildSummaryCard(
              context,
              title: 'Big Spends',
              value: '₹${metrics.bigSpendsAmount.toStringAsFixed(0)} (${metrics.bigSpendsPercentage.toStringAsFixed(1)}%)',
              subtitle: '${metrics.bigSpendsCount} spends > ₹1K',
              icon: Icons.local_atm,
              color: Colors.deepOrange,
              onTap: () => _onCardTap('big_spends'),
            ),
          ],
        ),

        // Merchant Distribution Chart
        // if (metrics.topMerchants.isNotEmpty) ...[
        //   _buildMerchantDistributionChart(context, metrics),
        // ],
      ],
    );
  }

  Widget _buildMerchantDistributionChart(BuildContext context, _MetricsData metrics) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.store, color: Colors.grey[600], size: 18),
              const SizedBox(width: 8),
              Text(
                'Top 3 Merchant Distribution',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const Spacer(),
              GestureDetector(
                onTap: () {
                  setState(() {
                    _showLegends = !_showLegends;
                  });
                },
                child: Icon(
                  _showLegends ? Icons.visibility_off : Icons.visibility,
                  color: Theme.of(context).primaryColor,
                  size: 18,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Stacked Bar - Clickable
          GestureDetector(
            onTap: () {
              setState(() {
                _showLegends = !_showLegends;
              });
            },
            child: Container(
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _showLegends
                      ? Theme.of(context).primaryColor
                      : Colors.grey[300]!,
                  width: _showLegends ? 2 : 1,
                ),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  children: _buildBarSegments(metrics),
                ),
              ),
            ),
          ),

          // Animated Legend
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            height: _showLegends ? null : 0,
            child: AnimatedOpacity(
              duration: const Duration(milliseconds: 300),
              opacity: _showLegends ? 1.0 : 0.0,
              child: _showLegends
                  ? Column(
                children: [
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    children: _buildLegendItems(metrics),
                  ),
                ],
              )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildBarSegments(_MetricsData metrics) {
    final colors = [
      Colors.blue[600]!,
      Colors.green[600]!,
      Colors.orange[600]!,
      Colors.grey[400]!,
    ];

    List<Widget> segments = [];

    for (int i = 0; i < metrics.topMerchants.length; i++) {
      final merchant = metrics.topMerchants[i];
      segments.add(
        Expanded(
          flex: (merchant.percentage * 1000).round(), // Use 1000 for better precision
          child: Container(
            color: colors[i],
            child: merchant.percentage > 0.15 // Show label if segment is large enough
                ? Center(
              child: Text(
                '${(merchant.percentage * 100).toStringAsFixed(0)}%',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            )
                : null,
          ),
        ),
      );
    }

    return segments;
  }

  List<Widget> _buildLegendItems(_MetricsData metrics) {
    final colors = [
      Colors.blue[600]!,
      Colors.green[600]!,
      Colors.orange[600]!,
      Colors.grey[400]!,
    ];

    return metrics.topMerchants.asMap().entries.map((entry) {
      final index = entry.key;
      final merchant = entry.value;

      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: colors[index],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '${merchant.name} (${(merchant.percentage * 100).toStringAsFixed(1)}%)',
            style: TextStyle(
              fontSize: 11,
              color: Colors.grey[700],
            ),
          ),
        ],
      );
    }).toList();
  }

  _MetricsData _calculateMetrics() {
    if (widget.transactions.isEmpty) return _MetricsData();

    // Filter only debit transactions for spending metrics
    final debits = widget.transactions.where((t) => t.type == "debit").toList();

    final credits = widget.transactions.where((t) => t.type == "credit").toList();


    // Basic metrics
    final totalSpent = credits.fold<double>(0, (sum, t) => sum + t.amount) - debits.fold<double>(0, (sum, t) => sum + t.amount);
    final transactionCount = debits.length;

    // Median spend
    final amounts = debits.map((t) => t.amount).toList()..sort();
    final medianSpend = amounts.isEmpty
        ? 0.0
        : (amounts.length % 2 == 1
        ? amounts[amounts.length ~/ 2]
        : (amounts[amounts.length ~/ 2 - 1] + amounts[amounts.length ~/ 2]) / 2);

    // Calculate non-spend days (only consider days with debit)
    final debitDates = debits
        .map((t) => DateTime(t.dateTime.year, t.dateTime.month, t.dateTime.day))
        .toSet();
    final firstDate = widget.transactions.map((t) => t.dateTime).reduce((a, b) => a.isBefore(b) ? a : b);
    final lastDate = widget.transactions.map((t) => t.dateTime).reduce((a, b) => a.isAfter(b) ? a : b);
    final totalDays = lastDate.difference(firstDate).inDays + 1;
    final nonSpendDays = totalDays - debitDates.length;

    // Highest spend
    double highestSpend = 0;
    DateTime? highestSpendDate;
    for (final t in debits) {
      if (t.amount > highestSpend) {
        highestSpend = t.amount;
        highestSpendDate = t.dateTime;
      }
    }

    // Top category
    final Map<SpendCategory, double> totalsByCategory = {};
    for (final t in debits) {
      final category = getCategoryForMerchant(t.merchant);
      totalsByCategory[category] = (totalsByCategory[category] ?? 0) + t.amount;
    }

    SpendCategory? topCategory;
    double? topCategoryAmount;
    if (totalsByCategory.isNotEmpty) {
      final topEntry = totalsByCategory.entries.reduce((a, b) => a.value > b.value ? a : b);
      topCategory = topEntry.key;
      topCategoryAmount = topEntry.value;
    }

    // Top merchant
    final Map<String, double> totalsByMerchant = {};
    for (final t in debits) {
      totalsByMerchant[t.merchant] = (totalsByMerchant[t.merchant] ?? 0) + t.amount;
    }

    String? topMerchant;
    double? topMerchantAmount;
    if (totalsByMerchant.isNotEmpty) {
      final topEntry = totalsByMerchant.entries.reduce((a, b) => a.value > b.value ? a : b);
      topMerchant = topEntry.key;
      topMerchantAmount = topEntry.value;
    }

    // Top 3 merchants for chart
    List<_MerchantData> topMerchants = [];
    if (totalsByMerchant.isNotEmpty) {
      final merchantList = totalsByMerchant.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      double top3Amount = 0;
      for (int i = 0; i < 3 && i < merchantList.length; i++) {
        final entry = merchantList[i];
        final percentage = entry.value / totalSpent;
        topMerchants.add(_MerchantData(
          name: entry.key.length > 15 ? '${entry.key.substring(0, 15)}...' : entry.key,
          amount: entry.value,
          percentage: percentage,
        ));
        top3Amount += entry.value;
      }

      // Add "Others" if there are more than 3 merchants
      if (merchantList.length > 3) {
        final othersAmount = totalSpent - top3Amount;
        final othersPercentage = othersAmount / totalSpent;
        topMerchants.add(_MerchantData(
          name: 'Others',
          amount: othersAmount,
          percentage: othersPercentage,
        ));
      }
    }

    // Weekday vs Weekend split
    double weekdaySpend = 0;
    double weekendSpend = 0;
    for (final t in debits) {
      if (t.dateTime.weekday >= 6) {
        weekendSpend += t.amount;
      } else {
        weekdaySpend += t.amount;
      }
    }
    final weekdayPercentage = totalSpent > 0 ? (weekdaySpend / totalSpent) * 100.0 : 0.0;
    final weekendPercentage = totalSpent > 0 ? (weekendSpend / totalSpent) * 100.0 : 0.0;

    // Big spends (> ₹1000)
    final bigSpends = debits.where((t) => t.amount > 1000).toList();
    final bigSpendsCount = bigSpends.length;
    final bigSpendsAmount = bigSpends.fold<double>(0, (sum, t) => sum + t.amount);
    final bigSpendsPercentage = totalSpent > 0 ? (bigSpendsAmount / totalSpent) * 100.0 : 0.0;

    return _MetricsData(
      totalSpent: totalSpent,
      transactionCount: transactionCount,
      medianSpend: medianSpend,
      nonSpendDays: nonSpendDays,
      highestSpend: highestSpend,
      highestSpendDate: highestSpendDate,
      topCategory: topCategory,
      topCategoryAmount: topCategoryAmount,
      topMerchant: topMerchant,
      topMerchantAmount: topMerchantAmount,
      topMerchants: topMerchants,
      weekdayPercentage: weekdayPercentage,
      weekendPercentage: weekendPercentage,
      bigSpendsCount: bigSpendsCount,
      bigSpendsAmount: bigSpendsAmount,
      bigSpendsPercentage: bigSpendsPercentage,
    );
  }

  Widget _buildSummaryCard(
      BuildContext context, {
        required String title,
        required String value,
        String subtitle = '',
        required IconData icon,
        required Color color,
        VoidCallback? onTap,
      }) {
    final scheme = Theme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
        child: Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: scheme.primary.withValues(alpha: 0.5),
              width: 1.5,
            ),
          ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.transparent,
                color.withOpacity(0.3),
              ],
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: color,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: scheme.onSurface,
                          letterSpacing: 0.5
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.bold,
                  height: 1.5,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10,
                    color: scheme.onSurface.withOpacity(0.7),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  // Placeholder function for card tap handling
  void _onCardTap(String cardType) {
    // TODO: Implement drill-down functionality for each card type
    print('Tapped card: $cardType');
  }
}

class _MetricsData {
  final double totalSpent;
  final int transactionCount;
  final double medianSpend;
  final int nonSpendDays;
  final double highestSpend;
  final DateTime? highestSpendDate;
  final SpendCategory? topCategory;
  final double? topCategoryAmount;
  final String? topMerchant;
  final double? topMerchantAmount;
  final List<_MerchantData> topMerchants;
  final double weekdayPercentage;
  final double weekendPercentage;
  final int bigSpendsCount;
  final double bigSpendsPercentage;
  final double bigSpendsAmount;

  _MetricsData({
    this.totalSpent = 0.0,
    this.transactionCount = 0,
    this.medianSpend = 0.0,
    this.nonSpendDays = 0,
    this.highestSpend = 0.0,
    this.highestSpendDate,
    this.topCategory,
    this.topCategoryAmount,
    this.topMerchant,
    this.topMerchantAmount,
    this.topMerchants = const [],
    this.weekdayPercentage = 0.0,
    this.weekendPercentage = 0.0,
    this.bigSpendsCount = 0,
    this.bigSpendsAmount = 0.0,
    this.bigSpendsPercentage = 0.0,
  });
}

class _MerchantData {
  final String name;
  final double amount;
  final double percentage;

  _MerchantData({
    required this.name,
    required this.amount,
    required this.percentage,
  });
}