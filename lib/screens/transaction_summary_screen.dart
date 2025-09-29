import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:upi_expense_tracker/models/transaction.dart';
import 'package:upi_expense_tracker/widgets/daily_spend_chart.dart';
import 'package:upi_expense_tracker/widgets/weekday_spend_chart.dart';
import 'package:upi_expense_tracker/widgets/compact_date_selector.dart';
import 'package:upi_expense_tracker/widgets/frequent_merchant_list.dart';
import 'package:excel/excel.dart';
import 'package:upi_expense_tracker/widgets/summary_cards.dart';
import 'package:upi_expense_tracker/widgets/transaction_list_item.dart';
import 'package:upi_expense_tracker/widgets/spend_distribution_chart.dart';
import 'package:upi_expense_tracker/widgets/hourly_spend_chart.dart';
import 'package:upi_expense_tracker/widgets/cumulative_spend_chart.dart';
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

      // Calculate total credit and debit amounts
      double totalCredit = 0.0;
      double totalDebit = 0.0;

      for (final transaction in transactions) {
        if (transaction.type == 'credit') {
          totalCredit += transaction.amount;
        } else if (transaction.type == 'debit') {
          totalDebit += transaction.amount;
        }
      }

      // Calculate net amount (credit - debit)
      final netAmount = totalCredit - totalDebit;

      // Determine final transaction type based on net amount
      final String finalType = netAmount >= 0 ? 'credit' : 'debit';

      // Use absolute value of net amount
      final double finalAmount = netAmount.abs();

      // Use the most recent date
      final latestDate = transactions
          .map((t) => t.dateTime)
          .reduce((a, b) => a.isAfter(b) ? a : b);

      // Create a new transaction representing the group
      return Transaction(
        amount: finalAmount,
        merchant: merchantName,
        // Remove transaction count from name
        dateTime: latestDate,
        type: finalType,
        transactionCount: transactions.length, // Store count separately
      );
    }).toList();

    _sortAggregatedTransactions();
  }

  void _sortAggregatedTransactions() {
    switch (_aggregateSortBy) {
      case 'frequency_high':
        _aggregatedTransactions.sort((a, b) =>
            (b.transactionCount ?? 0).compareTo(a.transactionCount ?? 0));
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
    return input.where((t) =>
        _selectedCategories.contains(getCategoryForMerchant(t.merchant)))
        .toList();
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
    return _filteredTransactions
        .map((t) => t.merchant)
        .toSet()
        .length;
  }

  Future<void> _showDownloadNotification(String filePath, String fileName) async {
    final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

    const AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
      'download_channel',
      'Downloads',
      channelDescription: 'Notifications for downloaded files',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
      icon: '@mipmap/ic_launcher',
    );

    const NotificationDetails notificationDetails = NotificationDetails(
      android: androidDetails,
    );

    await flutterLocalNotificationsPlugin.show(
      DateTime.now().millisecondsSinceEpoch.remainder(100000),
      'Excel Download Succesfully',
      '$fileName',
      notificationDetails,
      payload: filePath,
    );
  }

  Future<void> _exportToExcel() async {
    final filteredTransactions = _applyCategoryFilter(_filteredTransactions);

    // Create Excel file
    var excel = Excel.createExcel();

    // Rename default sheet to 'Transactions'
    excel.rename('Sheet1', 'Transactions');
    Sheet sheetObject = excel['Transactions'];

    // Format dates
    final dateFormat = DateFormat('dd MMM yyyy');
    final startDateStr = dateFormat.format(_startDate);
    final endDateStr = dateFormat.format(_endDate);

    // Column widths
    for (int i = 0; i < 5; i++) sheetObject.setColumnWidth(i, 30);

    // Styles
    CellStyle centerBold = CellStyle(bold: true, horizontalAlign: HorizontalAlign.Center);
    CellStyle center = CellStyle(horizontalAlign: HorizontalAlign.Center);
    CellStyle headerBg = CellStyle(bold: true, horizontalAlign: HorizontalAlign.Center, backgroundColorHex: ExcelColor.grey200);

    // Title Row
    sheetObject.appendRow([TextCellValue('Transaction Report')]);
    sheetObject.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 0),
    );
    sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = centerBold;

    // Period Row
    sheetObject.appendRow([TextCellValue('Period: $startDateStr to $endDateStr')]);
    sheetObject.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
      CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 1),
    );
    sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle = centerBold;

    // Column headers
    sheetObject.appendRow([
      TextCellValue('S.No'),
      TextCellValue('Merchant'),
      TextCellValue('Amount'),
      TextCellValue('Type'),
      TextCellValue('Date & Time'),
    ]);
    for (int col = 0; col < 5; col++) {
      sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 2)).cellStyle = headerBg;
    }

    // Transaction Data
    for (int i = 0; i < filteredTransactions.length; i++) {
      final t = filteredTransactions[i];
      final dateTimeStr = DateFormat('dd MMM yyyy, hh:mm a').format(t.dateTime);

      sheetObject.appendRow([
        IntCellValue(i + 1),
        TextCellValue(t.merchant),
        DoubleCellValue(t.amount),
        TextCellValue(t.type),
        TextCellValue(dateTimeStr),
      ]);

      int currentRow = i + 3;
      for (int col = 0; col < 5; col++) {
        sheetObject.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow)).cellStyle = center;
      }
    }

    // Aggregated Sheet
    Sheet aggSheet = excel['Aggregated Data'];
    for (int i = 0; i < 5; i++) aggSheet.setColumnWidth(i, 30);

    // Aggregated headers
    aggSheet.appendRow([TextCellValue('Aggregated Transactions')]);
    aggSheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 0),
    );
    aggSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = centerBold;

    aggSheet.appendRow([TextCellValue('Period: $startDateStr to $endDateStr')]);
    aggSheet.merge(
      CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
      CellIndex.indexByColumnRow(columnIndex: 4, rowIndex: 1),
    );
    aggSheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle = centerBold;

    aggSheet.appendRow([
      TextCellValue('S.No'),
      TextCellValue('Merchant'),
      TextCellValue('Total Amount'),
      TextCellValue('Transaction Count'),
      TextCellValue('Net Type'),
    ]);
    for (int col = 0; col < 5; col++) {
      aggSheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: 2)).cellStyle = headerBg;
    }

    // Aggregate by merchant
    final Map<String, List<Transaction>> grouped = {};
    for (var t in filteredTransactions) {
      grouped.putIfAbsent(t.merchant, () => []).add(t);
    }

    int idx = 0;
    grouped.entries.forEach((entry) {
      final merchant = entry.key;
      final transactions = entry.value;

      double totalCredit = 0, totalDebit = 0;
      for (var t in transactions) {
        if (t.type == 'credit') totalCredit += t.amount;
        else totalDebit += t.amount;
      }
      final netAmount = totalCredit - totalDebit;
      final String finalType = netAmount >= 0 ? 'credit' : 'debit';
      final double finalAmount = netAmount.abs();

      aggSheet.appendRow([
        IntCellValue(idx + 1),
        TextCellValue(merchant),
        DoubleCellValue(finalAmount),
        IntCellValue(transactions.length),
        TextCellValue(finalType),
      ]);

      int currentRow = idx + 3;
      for (int col = 0; col < 5; col++) {
        aggSheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: currentRow)).cellStyle = center;
      }

      idx += 1;
    });

    // Save the file
    try {
      if (Platform.isAndroid) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          final manageStatus = await Permission.manageExternalStorage.request();
          if (!manageStatus.isGranted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Storage permission denied')));
            return;
          }
        }
        await Permission.notification.request();
      }

      Directory? directory;
      if (Platform.isAndroid) {
        directory = Directory('/storage/emulated/0/Download');
        if (!await directory.exists()) directory = await getExternalStorageDirectory();
      } else if (Platform.isIOS) {
        directory = await getApplicationDocumentsDirectory();
      } else {
        directory = await getDownloadsDirectory();
      }

      if (directory == null) throw Exception('Could not access folder');

      final fileName = 'Xpense(${dateFormat.format(_startDate)}-${dateFormat.format(_endDate)}).xlsx';
      final filePath = '${directory.path}/$fileName';

      final fileBytes = excel.save();
      if (fileBytes != null) {
        File(filePath)
          ..createSync(recursive: true)
          ..writeAsBytesSync(fileBytes);

        await _showDownloadNotification(filePath, fileName);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error exporting Excel: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sort transactions by date (newest first)
    _filteredTransactions.sort((a, b) => b.dateTime.compareTo(a.dateTime));
    final scheme = Theme
        .of(context)
        .colorScheme;
    final screenSize = MediaQuery
        .of(context)
        .size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final isSmallScreen = screenHeight < 700;
    final isVerySmallScreen = screenHeight < 600;
    final isTablet = screenWidth > 600;

    // Responsive padding
    final horizontalPadding = isTablet ? 24.0 : 16.0;
    final verticalPadding = isSmallScreen ? 8.0 : 16.0;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Transaction Analysis',
          style: TextStyle(
            fontSize: isSmallScreen ? 18 : 20,
          ),
        ),
        elevation: 0,
      ),
      body: widget.transactions.isEmpty
          ? _buildEmptyState(isSmallScreen)
          : Column(
        children: [
          // Date selector with responsive padding
          Padding(
            padding: EdgeInsets.fromLTRB(
                horizontalPadding,
                isSmallScreen ? 4 : 8,
                horizontalPadding,
                isSmallScreen ? 4 : 8
            ),
            child: CompactDateSelector(
              startDate: _startDate,
              endDate: _endDate,
              onDateRangeChanged: _setDateRange,
              onQuickRangeSelected: _setQuickDateRange,
            ),
          ),

          SizedBox(height: isSmallScreen ? 2 : 4),

          // Category filters with responsive scrolling
          Padding(
            padding: EdgeInsets.fromLTRB(
                horizontalPadding, 0, horizontalPadding, 0),
            child: SizedBox(
              height: isVerySmallScreen ? 35 : (isSmallScreen ? 38 : 40),
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
                        isSmallScreen: isSmallScreen,
                        isVerySmallScreen: isVerySmallScreen,
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
                          isSmallScreen: isSmallScreen,
                          isVerySmallScreen: isVerySmallScreen,
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
          ),

          // Tab bar with responsive styling
          Material(
            color: Theme
                .of(context)
                .colorScheme
                .surface,
            child: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabAlignment: TabAlignment.center,
              labelStyle: TextStyle(
                fontSize: isSmallScreen ? 13 : 14,
                fontWeight: FontWeight.w600,
              ),
              unselectedLabelStyle: TextStyle(
                fontSize: isSmallScreen ? 13 : 14,
              ),
              tabs: const [
                Tab(text: 'Overview'),
                Tab(text: 'Trends'),
                Tab(text: 'Categories'),
                Tab(text: 'Transactions'),
              ],
            ),
          ),

          // Tab content
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(horizontalPadding, isSmallScreen),
                _buildTrendsTab(
                    horizontalPadding, isSmallScreen, isVerySmallScreen),
                _buildCategoriesTab(
                    horizontalPadding, isSmallScreen, isVerySmallScreen),
                _buildTransactionsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOverviewTab(double horizontalPadding, bool isSmallScreen) {
    final filteredTransactions = _applyCategoryFilter(_filteredTransactions);
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(right: horizontalPadding,left: horizontalPadding,bottom: horizontalPadding),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Export button
              Align(
                alignment: Alignment.center,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 4.0,vertical: 16.0),
                  child: ElevatedButton.icon(
                    onPressed: _exportToExcel,
                    icon: Icon(Icons.file_download, color: scheme.onPrimary),
                    label: Text(
                      'Export to Excel',
                      style: TextStyle(color: scheme.onPrimary),
                    ),
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      backgroundColor: scheme.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8), // reduced from default 8–12
                      ),
                    ),
                  ),
                ),
              ),
              SummaryCards(
                transactions: filteredTransactions,
                startDate: _startDate,
                endDate: _endDate,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTrendsTab(double horizontalPadding, bool isSmallScreen,
      bool isVerySmallScreen) {
    // Responsive chart height
    final chartHeight = isVerySmallScreen ? 180.0 : (isSmallScreen
        ? 200.0
        : 220.0);
    final sectionSpacing = isSmallScreen ? 16.0 : 24.0;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _sectionTitle('Daily Spend', isSmallScreen),
            SizedBox(height: isSmallScreen ? 6 : 8),
            _sectionCard(
              SizedBox(
                height: chartHeight,
                child: DailySpendChart(
                  transactions: _applyCategoryFilter(_filteredTransactions),
                  startDate: _startDate,
                  endDate: _endDate,
                ),
              ),
              isSmallScreen,
            ),
            SizedBox(height: sectionSpacing),
            _sectionTitle('Cumulative Spend', isSmallScreen),
            SizedBox(height: isSmallScreen ? 6 : 8),
            _sectionCard(
              SizedBox(
                height: chartHeight,
                child: CumulativeSpendChart(
                  transactions: _applyCategoryFilter(_filteredTransactions),
                  startDate: _startDate,
                  endDate: _endDate,
                ),
              ),
              isSmallScreen,
            ),
            SizedBox(height: sectionSpacing),
            _sectionTitle('Spending by Day of Week', isSmallScreen),
            SizedBox(height: isSmallScreen ? 6 : 8),
            _sectionCard(
              SizedBox(
                height: chartHeight,
                child: WeekdaySpendChart(
                    transactions: _applyCategoryFilter(_filteredTransactions)),
              ),
              isSmallScreen,
            ),
            SizedBox(height: sectionSpacing),
            _sectionTitle('Hourly Spend Pattern', isSmallScreen),
            SizedBox(height: isSmallScreen ? 6 : 8),
            _sectionCard(
              SizedBox(
                height: chartHeight,
                child: HourlySpendChart(
                    transactions: _applyCategoryFilter(_filteredTransactions)),
              ),
              isSmallScreen,
            ),
            SizedBox(height: sectionSpacing),
            _sectionTitle('Frequent Merchants', isSmallScreen),
            SizedBox(height: isSmallScreen ? 6 : 8),
            _sectionCard(
              FrequentMerchantsList(
                transactions: _applyCategoryFilter(_filteredTransactions),
                displayCount: 5,
              ),
              isSmallScreen,
            ),
            SizedBox(height: isSmallScreen ? 16 : 32),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoriesTab(double horizontalPadding, bool isSmallScreen,
      bool isVerySmallScreen) {
    // Responsive chart height for pie chart
    final pieChartHeight = 500.0;

    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(horizontalPadding),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Section title with Manage Merchants button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: _sectionTitle(
                      'Spend Distribution (Pie)', isSmallScreen),
                ),
                ElevatedButton.icon(
                  onPressed: () {
                    final uniqueMerchants = _applyCategoryFilter(
                        widget.transactions)
                        .map((t) => t.merchant)
                        .toSet()
                        .toList()
                      ..sort((a, b) =>
                          a.toLowerCase().compareTo(b.toLowerCase()));
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => MerchantManagerScreen(
                            knownMerchants: uniqueMerchants),
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.manage_accounts,
                    size: isSmallScreen ? 16 : 20,
                    color: Theme
                        .of(context)
                        .colorScheme
                        .surface,
                  ),
                  label: Text(
                    'Manage',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 16,
                      color: Theme
                          .of(context)
                          .colorScheme
                          .surface,
                    ),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme
                        .of(context)
                        .colorScheme
                        .primary,
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 8 : 12,
                      vertical: isSmallScreen ? 6 : 8,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 6 : 8),
            _sectionCard(
              SizedBox(
                height: pieChartHeight,
                child: SpendDistributionChart(
                  transactions: _applyCategoryFilter(_filteredTransactions),
                ),
              ),
              isSmallScreen,
            ),
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

  Widget _buildViewToggleButton(ColorScheme scheme, bool isSmallScreen) {
    return ElevatedButton.icon(
      onPressed: _toggleAggregation,
      icon: Icon(
        _isAggregated ? Icons.splitscreen : Icons.group_work,
        size: isSmallScreen ? 16 : 18,
        color: scheme.onPrimary,
      ),
      label: Text(
        _isAggregated ? 'Split View' : 'Aggregate View',
        style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 10 : 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildSortToggleButton(ColorScheme scheme, bool isSmallScreen) {
    return ElevatedButton.icon(
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
        size: isSmallScreen ? 16 : 18,
        color: scheme.onPrimary,
      ),
      label: Text(
        _aggregateSortBy != 'frequency_high'
            ? 'By Frequency'
            : 'By Amount',
        style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 10 : 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  Widget _buildEmptyTransactionState(ColorScheme scheme, bool isSmallScreen) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: isSmallScreen ? 48 : 64,
            color: scheme.onSurfaceVariant,
          ),
          SizedBox(height: isSmallScreen ? 12 : 16),
          Text(
            _selectedCategories.isEmpty
                ? 'No transactions in selected period'
                : 'No transactions found for selected category',
            style: TextStyle(
              color: scheme.onSurfaceVariant,
              fontSize: isSmallScreen ? 14 : 16,
            ),
            textAlign: TextAlign.center,
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
    required bool isSmallScreen,
    required bool isVerySmallScreen,
  }) {
    final scheme = Theme
        .of(context)
        .colorScheme;

    final fontSize = isVerySmallScreen ? 10.0 : (isSmallScreen ? 11.0 : 12.0);
    final iconSize = isVerySmallScreen ? 12.0 : (isSmallScreen ? 13.0 : 14.0);
    final horizontalPadding = isVerySmallScreen ? 10.0 : (isSmallScreen
        ? 12.0
        : 16.0);
    final verticalPadding = isVerySmallScreen ? 6.0 : (isSmallScreen
        ? 7.0
        : 8.0);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : scheme.surface,
          borderRadius: BorderRadius.circular(20),
          // border: Border.all(
          //   color: isSelected ? color : scheme.outlineVariant,
          //   width: isSelected ? 2 : 1,
          // ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: iconSize,
              color: isSelected ? color : scheme.onSurfaceVariant,
            ),
            SizedBox(width: isVerySmallScreen ? 4 : 6),
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                color: isSelected ? color : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isSmallScreen) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: isSmallScreen ? 60 : 80,
            color: Colors.grey,
          ),
          SizedBox(height: isSmallScreen ? 12 : 16),
          Text(
            'No UPI transactions found',
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: isSmallScreen ? 6 : 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 24 : 32),
            child: Text(
              'We couldn\'t find any UPI transactions in your SMS messages.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.grey,
                fontSize: isSmallScreen ? 13 : 14,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String title, bool isSmallScreen) {
    return Text(
      title,
      style: Theme
          .of(context)
          .textTheme
          .titleMedium
          ?.copyWith(
        fontWeight: FontWeight.w700,
        fontSize: isSmallScreen ? 14 : 16,
      ),
    );
  }

  Widget _sectionCard(Widget child, bool isSmallScreen) {
    final scheme = Theme
        .of(context)
        .colorScheme;
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
        padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
        child: child,
      ),
    );
  }
}