import 'dart:ffi';
import 'dart:io';
import 'dart:ui';

import 'package:dropdown_button2/dropdown_button2.dart';
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
import 'package:excel/excel.dart' hide Border,BorderStyle;
import 'package:upi_expense_tracker/widgets/summary_cards.dart';
import 'package:upi_expense_tracker/widgets/transaction_list_item.dart';
import 'package:upi_expense_tracker/widgets/spend_distribution_chart.dart';
import 'package:upi_expense_tracker/widgets/hourly_spend_chart.dart';
import 'package:upi_expense_tracker/widgets/cumulative_spend_chart.dart';
import 'package:upi_expense_tracker/utils/category_utils.dart';
import 'package:upi_expense_tracker/screens/merchant_manager_screen.dart';

import '../services/custom_category.dart';
import '../services/merchant_store.dart';
import '../utils/date_formatter.dart';

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
  final Set<Object> _selectedCategories = {}; // Can hold SpendCategory or CustomCategory
  String? _selectedCustomFilterId; // Track selected custom category filter

  // Sorting options
  String _aggregateSortBy = 'frequency_high'; // frequency_high, amount_high
  String _splitSortBy = 'amount_high'; // amount_high
  String? _editingCustomCategoryId;
  Transaction? _selectedTransaction;
  SpendCategory? _editingCategory;

  @override
  void initState() {
    super.initState();
    // Initialize with last 30 days
    _initializeCustomCategories();
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


  Future<void> _initializeCustomCategories() async {
    await CustomCategoryStore.instance.initialize();
    if (mounted) setState(() {});
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
    if (_selectedCategories.isEmpty && _selectedCustomFilterId == null) return input;

    return input.where((t) {
      final merchant = t.merchant;
      final store = MerchantStore.instance;

      // Check if merchant has custom category mapping
      final customId = store.lookupCustomCategoryIdForMerchant(merchant);

      if (customId != null) {
        // Merchant is mapped to custom category
        return _selectedCustomFilterId == customId;
      } else {
        // Merchant uses default category
        final defaultCategory = getCategoryForMerchant(merchant);
        return _selectedCategories.contains(defaultCategory);
      }
    }).toList();
  }

  void _toggleCategory(SpendCategory category) {
    setState(() {
      _selectedCustomFilterId = null; // Clear custom filter
      if (_selectedCategories.contains(category)) {
        _selectedCategories.remove(category);
      } else {
        _selectedCategories.clear();
        _selectedCategories.add(category);
      }
      _updateAggregatedTransactions();
    });
  }

  void _toggleCustomCategory(String customCategoryId) {
    setState(() {
      _selectedCategories.clear(); // Clear default filters
      if (_selectedCustomFilterId == customCategoryId) {
        _selectedCustomFilterId = null;
      } else {
        _selectedCustomFilterId = customCategoryId;
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

  String _editingDropdownValueFor(String merchant, SpendCategory current) {
    final customId = MerchantStore.instance.lookupCustomCategoryIdForMerchant(merchant);
    if (customId != null) return 'custom:' + customId;
    return 'default:' + current.name;
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

    // Save the file with simplified Android version handling
    try {
      final fileBytes = excel.save();
      if (fileBytes == null) {
        throw Exception('Failed to generate Excel file');
      }

      String? filePath;
      final fileName = 'Xpense_${dateFormat.format(_startDate)}_${dateFormat.format(_endDate)}.xlsx';

      if (Platform.isAndroid) {
        // Request notification permission for Android 13+
        await Permission.notification.request();

        // Check Android SDK version using Platform.version
        final int sdkInt = _getAndroidSdkInt();

        if (sdkInt >= 29) {
          // Android 10+ (API 29+) - Use app-specific external directory
          // This doesn't require any permissions and is accessible via file manager
          final directory = await getExternalStorageDirectory();

          if (directory != null) {
            // Create a more accessible path
            final String basePath = directory.path.split('Android')[0];
            final String xpensePath = '${basePath}Documents/Xpense';

            final xpenseDir = Directory(xpensePath);
            if (!await xpenseDir.exists()) {
              await xpenseDir.create(recursive: true);
            }

            filePath = '$xpensePath/$fileName';
            final file = File(filePath);
            await file.writeAsBytes(fileBytes);
          }
        } else {
          // Android 9 and below - Request storage permission
          final status = await Permission.storage.request();
          if (!status.isGranted) {
            ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Storage permission is required'))
            );
            return;
          }

          final directory = Directory('/storage/emulated/0/Download');
          if (!await directory.exists()) {
            await directory.create(recursive: true);
          }

          filePath = '${directory.path}/$fileName';
          final file = File(filePath);
          await file.writeAsBytes(fileBytes);
        }
      } else if (Platform.isIOS) {
        final directory = await getApplicationDocumentsDirectory();
        filePath = '${directory.path}/$fileName';
        final file = File(filePath);
        await file.writeAsBytes(fileBytes);
      } else {
        final directory = await getDownloadsDirectory();
        if (directory != null) {
          filePath = '${directory.path}/$fileName';
          final file = File(filePath);
          await file.writeAsBytes(fileBytes);
        }
      }

      if (filePath != null) {
        await _showDownloadNotification(filePath, fileName);
      } else {
        throw Exception('Could not save file');
      }
    } catch (e) {
      print('Error exporting Excel: $e');
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${e.toString()}'))
      );
    }
  }

// Helper method to get Android SDK version
  int _getAndroidSdkInt() {
    try {
      // Parse SDK version from Platform.version
      // Example: "2.10.0 (stable) (Tue Oct 13 15:50:27 2020 +0200) on "android_ia32""
      final versionStr = Platform.version;
      if (versionStr.contains('android')) {
        // For Android 10+, we can safely assume API 29+
        // This is a simple heuristic - for production you might want device_info_plus
        return 29; // Default to Android 10+ behavior
      }
      return 28; // Fallback to older Android
    } catch (e) {
      return 29; // Default to modern Android
    }
  }

  // Add this method to your _TransactionSummaryScreenState class

  Future<void> _showAddCategoryDialog() async {
    final TextEditingController nameController = TextEditingController();
    final scheme = Theme.of(context).colorScheme;

    return showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Custom Category'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Category Name',
                    hintText: 'e.g., Investments, Gifts, etc.',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    prefixIcon: const Icon(Icons.category),
                  ),
                  textCapitalization: TextCapitalization.words,
                  maxLength: 20,
                ),
              ],
            ),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 40.0, vertical: 24.0),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final categoryName = nameController.text.trim();
                if (categoryName.isNotEmpty) {
                  await CustomCategoryStore.instance.addCategory(categoryName);
                  Navigator.of(context).pop();

                  setState(() {
                    _selectedTransaction = null;
                    _editingCustomCategoryId = null; // ✅ reset
                    _editingCategory = null;         // ✅ reset
                  });// Refresh UI to show new category

                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          const Icon(Icons.check_circle, color: Colors.white),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text('Category "$categoryName" added successfully'),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.green[600],
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
              ),
              child: const Text('Add Category'),
            ),
          ],
        );
      },
    );
  }

// Add this widget method to build the "Add Category" button
  Widget _buildAddCategoryButton(bool isSmallScreen, bool isVerySmallScreen) {
    final scheme = Theme.of(context).colorScheme;
    final fontSize = isVerySmallScreen ? 10.0 : (isSmallScreen ? 11.0 : 12.0);
    final iconSize = isVerySmallScreen ? 12.0 : (isSmallScreen ? 13.0 : 14.0);
    final horizontalPadding = isVerySmallScreen ? 10.0 : (isSmallScreen ? 12.0 : 16.0);
    final verticalPadding = isVerySmallScreen ? 6.0 : (isSmallScreen ? 7.0 : 8.0);

    return GestureDetector(
      onTap: _showAddCategoryDialog,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: scheme.primaryContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: scheme.primary,
            width: 1.5,
            style: BorderStyle.solid,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.add_circle_outline,
              size: iconSize,
              color: scheme.onPrimary,
            ),
            SizedBox(width: isVerySmallScreen ? 4 : 6),
            Text(
              'Add',
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: scheme.onPrimary,
              ),
            ),
          ],
        ),
      ),
    );
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
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.manage_accounts),
            onPressed: () {
              final uniqueMerchants = _applyCategoryFilter(widget.transactions)
                  .map((t) => t.merchant)
                  .toSet()
                  .toList()
                ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
              Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) =>
                      MerchantManagerScreen(knownMerchants: uniqueMerchants),
                  transitionsBuilder: (context, animation, secondaryAnimation, child) {
                    const begin = Offset(1.0, 0.0);
                    const end = Offset.zero;
                    const curve = Curves.easeInOut;
                    var tween = Tween(begin: begin, end: end).chain(
                      CurveTween(curve: curve),
                    );
                    var offsetAnimation = animation.drive(tween);
                    return SlideTransition(
                      position: offsetAnimation,
                      child: child,
                    );
                  },
                ),
              );
            },
          ),
        ],
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
                        isSelected: _selectedCategories.isEmpty && _selectedCustomFilterId == null,
                        color: scheme.primary,
                        onTap: () {
                          setState(() {
                            _selectedCategories.clear();
                            _selectedCustomFilterId = null;
                            _updateAggregatedTransactions();
                          });
                        },
                        isSmallScreen: isSmallScreen,
                        isVerySmallScreen: isVerySmallScreen,
                      ),
                    ),
                    // Default category buttons
                    ...getAllCategories().map((category) {
                      final categoryColor = category == SpendCategory.others
                          ? getCategoryColor(category, colorScheme: scheme)
                          : getCategoryColor(category);

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: _buildCategoryFilterChip(
                          label: getCategoryName(category),
                          icon: getCategoryIcon(category),
                          isSelected: _selectedCategories.contains(category) && _selectedCustomFilterId == null,
                          color: categoryColor,
                          onTap: () => _toggleCategory(category),
                          isSmallScreen: isSmallScreen,
                          isVerySmallScreen: isVerySmallScreen,
                        ),
                      );
                    }).toList(),
                    // Custom category buttons
                    ...CustomCategoryStore.instance.getAllCustomCategories().map((category) {
                      final categoryColor = getCategoryColor(category);
                      final isSelected = _selectedCustomFilterId == category.id;

                      return Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: _buildCategoryFilterChip(
                          label: getCategoryName(category),
                          icon: getCategoryIcon(category),
                          isSelected: isSelected,
                          color: categoryColor,
                          onTap: () => _toggleCustomCategory(category.id),
                          // onLongPress: () {
                          //   showDialog(
                          //     context: context,
                          //     builder: (ctx) => AlertDialog(
                          //       title: const Text('Delete category?'),
                          //       content: Text('Are you sure you want to delete "${category.name}"?'),
                          //       actions: [
                          //         TextButton(
                          //           onPressed: () => Navigator.pop(ctx),
                          //           child: const Text('Cancel'),
                          //         ),
                          //         TextButton(
                          //           onPressed: () async {
                          //             await CustomCategoryStore.instance.removeCategory(category.id);
                          //             setState(() {
                          //               if (_selectedCustomFilterId == category.id) _selectedCustomFilterId = null;
                          //             });
                          //             Navigator.pop(ctx);
                          //             ScaffoldMessenger.of(context).showSnackBar(
                          //               SnackBar(content: Text('${category.name} deleted')),
                          //             );
                          //           },
                          //           child: const Text('Delete', style: TextStyle(color: Colors.red)),
                          //         ),
                          //       ],
                          //     ),
                          //   );
                          // },
                          isSmallScreen: isSmallScreen,
                          isVerySmallScreen: isVerySmallScreen,
                        ),
                      );
                    }).toList(),
                    // Add Category button
                    Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: _buildAddCategoryButton(isSmallScreen, isVerySmallScreen),
                    ),
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

  Widget _buildEditableTransactionItem(Transaction transaction, ColorScheme scheme, bool showTransactionCount) {
    Color categoryColor;

    if (_editingCustomCategoryId != null) {
      final cc = CustomCategoryStore.instance
          .getAllCustomCategories()
          .firstWhere(
            (c) => c.id == _editingCustomCategoryId,
        orElse: () => CustomCategory(
          id: '',
          name: 'Custom',
          colorValue: const Color(0xFFBDBDBD).value,
          iconCodePoint: Icons.category.codePoint,
        ),
      );
      categoryColor = cc.color;
    } else if (_editingCategory != null) {
      categoryColor = getCategoryColor(_editingCategory!, colorScheme: scheme);
    } else {
      categoryColor = getDisplayCategoryColorForMerchant(transaction.merchant, colorScheme: scheme);
    }

    final category = getCategoryForMerchant(transaction.merchant);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8,),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: scheme.outlineVariant.withOpacity(0.5),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Theme.of(context).brightness == Brightness.light
                  ? scheme.primary.withOpacity(0.12)
                  : scheme.primary.withOpacity(0.12),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Stack(
          children: [
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 5,
                decoration: BoxDecoration(
                  color: categoryColor,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    bottomLeft: Radius.circular(20),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16.0,12,12,12),
              child: Column(
                children: [
                  Row(
                    children: [
                      const SizedBox(width: 4),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    transaction.merchant,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                const SizedBox(width: 8),
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
                          ],
                        ),
                      ),

                      const SizedBox(width: 12),

                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            '₹${transaction.amount.toStringAsFixed(2)}',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: transaction.type == 'debit'
                                  ? Colors.red[700]
                                  : Colors.green[700],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            transaction.type,
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

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        flex: 7,
                        child: DropdownButtonFormField2<String>(
                          value: _editingDropdownValueFor(transaction.merchant, _editingCategory ?? category),
                          isExpanded: true,
                          decoration: InputDecoration(
                            contentPadding: const EdgeInsets.fromLTRB(0,12,8,12),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide(color: scheme.outlineVariant),
                            ),
                          ),
                          onChanged: (v) => setState(() {
                            if (v == null) return;
                            if (v.startsWith('custom:')) {
                              final id = v.substring('custom:'.length);
                              _editingCategory = null;
                              _editingCustomCategoryId = id;
                            } else if (v.startsWith('default:')) {
                              _editingCustomCategoryId = null;
                              final name = v.substring('default:'.length);
                              _editingCategory = SpendCategory.values.firstWhere((e) => e.name == name, orElse: () => SpendCategory.others);
                            }
                          }),
                          items: [
                            ...SpendCategory.values.map((c) => DropdownMenuItem<String>(
                              value: 'default:${c.name}',
                              child: Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: getCategoryColor(c, colorScheme: scheme).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      getCategoryIcon(c),
                                      color: getCategoryColor(c, colorScheme: scheme),
                                      size: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      getCategoryName(c),
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                            ...CustomCategoryStore.instance.getAllCustomCategories().map((cc) => DropdownMenuItem<String>(
                              value: 'custom:${cc.id}',
                              child: Row(
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: cc.color.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Icon(
                                      cc.icon,
                                      color: cc.color,
                                      size: 14,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      cc.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 13),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                          ],
                          dropdownStyleData: DropdownStyleData(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                              color: scheme.surface,
                            ),
                            maxHeight: 200,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      Expanded(
                        flex: 2,
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedTransaction = null;
                              _editingCustomCategoryId = null;
                              _editingCategory = null;
                            });
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: const Icon(Icons.close, size: 18),
                        ),
                      ),

                      const SizedBox(width: 8),

                      Expanded(
                        flex: 2,
                        child: ElevatedButton(
                          onPressed: () async {
                            final store = MerchantStore.instance;
                            if (_editingCustomCategoryId != null) {
                              await store.upsertCustomMapping(transaction.merchant, _editingCustomCategoryId!);
                            } else if (_editingCategory != null) {
                              await store.upsertMapping(transaction.merchant, _editingCategory!);
                            }
                            setState(() {
                              _selectedTransaction = null;
                              _editingCustomCategoryId = null;
                              _editingCategory = null;
                            });
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Row(
                                  children: [
                                    const Icon(Icons.check_circle, color: Colors.white),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Updated ${transaction.merchant}',
                                      ),
                                    ),
                                  ],
                                ),
                                backgroundColor: Colors.green[600],
                                behavior: SnackBarBehavior.floating,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: Icon(Icons.check, size: 18, color: scheme.onPrimary),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
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

    return Stack(
      children: [
        GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () {
            if (_selectedTransaction != null) {
              setState(() {
                _selectedTransaction = null;
                _editingCustomCategoryId = null;
                _editingCategory = null;
              });
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _toggleAggregation,
                        icon: Icon(
                          _isAggregated ? Icons.splitscreen : Icons.group_work,
                          size: 18,
                          color: scheme.onPrimary,
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
                      final transaction = displayTransactions[index];
                      final isSelected = _selectedTransaction == transaction;

                      return Opacity(
                        opacity: _selectedTransaction == null || isSelected ? 1.0 : 0.3,
                        child: IgnorePointer(
                          ignoring: _selectedTransaction != null && !isSelected,
                          child: isSelected
                              ? _buildEditableTransactionItem(transaction, scheme, _isAggregated)
                              : TransactionListItem(
                            transaction: transaction,
                            isCurrentMonth: transaction.isFromCurrentMonth(),
                            showTransactionCount: _isAggregated,
                            onTap: () {
                              setState(() {
                                _selectedTransaction = transaction;
                                final customId = MerchantStore.instance.lookupCustomCategoryIdForMerchant(transaction.merchant);
                                if (customId != null) {
                                  _editingCustomCategoryId = customId;
                                  _editingCategory = null;
                                } else {
                                  _editingCustomCategoryId = null;
                                  _editingCategory = getCategoryForMerchant(transaction.merchant);
                                }
                              });
                            },
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // Widget _buildViewToggleButton(ColorScheme scheme, bool isSmallScreen) {
  //   return ElevatedButton.icon(
  //     onPressed: _toggleAggregation,
  //     icon: Icon(
  //       _isAggregated ? Icons.splitscreen : Icons.group_work,
  //       size: isSmallScreen ? 16 : 18,
  //       color: scheme.onPrimary,
  //     ),
  //     label: Text(
  //       _isAggregated ? 'Split View' : 'Aggregate View',
  //       style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
  //     ),
  //     style: ElevatedButton.styleFrom(
  //       backgroundColor: scheme.primary,
  //       foregroundColor: scheme.onPrimary,
  //       padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 10 : 12),
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  //     ),
  //   );
  // }
  //
  // Widget _buildSortToggleButton(ColorScheme scheme, bool isSmallScreen) {
  //   return ElevatedButton.icon(
  //     onPressed: () {
  //       setState(() {
  //         _aggregateSortBy = _aggregateSortBy == 'frequency_high'
  //             ? 'amount_high'
  //             : 'frequency_high';
  //         _updateAggregatedTransactions();
  //       });
  //     },
  //     icon: Icon(
  //       _aggregateSortBy != 'frequency_high'
  //           ? Icons.trending_up
  //           : Icons.attach_money,
  //       size: isSmallScreen ? 16 : 18,
  //       color: scheme.onPrimary,
  //     ),
  //     label: Text(
  //       _aggregateSortBy != 'frequency_high'
  //           ? 'By Frequency'
  //           : 'By Amount',
  //       style: TextStyle(fontSize: isSmallScreen ? 12 : 14),
  //     ),
  //     style: ElevatedButton.styleFrom(
  //       backgroundColor: scheme.primary,
  //       foregroundColor: scheme.onPrimary,
  //       padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 10 : 12),
  //       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
  //     ),
  //   );
  // }
  //
  // Widget _buildEmptyTransactionState(ColorScheme scheme, bool isSmallScreen) {
  //   return Center(
  //     child: Column(
  //       mainAxisAlignment: MainAxisAlignment.center,
  //       children: [
  //         Icon(
  //           Icons.receipt_long,
  //           size: isSmallScreen ? 48 : 64,
  //           color: scheme.onSurfaceVariant,
  //         ),
  //         SizedBox(height: isSmallScreen ? 12 : 16),
  //         Text(
  //           _selectedCategories.isEmpty
  //               ? 'No transactions in selected period'
  //               : 'No transactions found for selected category',
  //           style: TextStyle(
  //             color: scheme.onSurfaceVariant,
  //             fontSize: isSmallScreen ? 14 : 16,
  //           ),
  //           textAlign: TextAlign.center,
  //         ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildCategoryFilterChip({
    required String label,
    required IconData icon,
    required bool isSelected,
    required Color color,
    required VoidCallback onTap,
    required bool isSmallScreen,
    required bool isVerySmallScreen,
    VoidCallback? onLongPress, // optional long press callback
  }) {
    final scheme = Theme.of(context).colorScheme;

    final fontSize = isVerySmallScreen ? 10.0 : (isSmallScreen ? 11.0 : 12.0);
    final iconSize = isVerySmallScreen ? 12.0 : (isSmallScreen ? 13.0 : 14.0);
    final horizontalPadding = isVerySmallScreen ? 10.0 : (isSmallScreen ? 12.0 : 16.0);
    final verticalPadding = isVerySmallScreen ? 6.0 : (isSmallScreen ? 7.0 : 8.0);

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress, // handle long press
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: verticalPadding,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.15) : scheme.surface,
          borderRadius: BorderRadius.circular(20),
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