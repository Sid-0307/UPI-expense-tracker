import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:upi_expense_tracker/models/transaction.dart';

class SpendDistributionChart extends StatefulWidget {
  final List<Transaction> transactions;
  final int topCount;

  const SpendDistributionChart({
    Key? key,
    required this.transactions,
    this.topCount = 6,
  }) : super(key: key);

  @override
  State<SpendDistributionChart> createState() => _SpendDistributionChartState();
}

class _SpendDistributionChartState extends State<SpendDistributionChart> {
  int? touchedIndex;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final screenSize = MediaQuery.of(context).size;
    final screenWidth = screenSize.width;
    final screenHeight = screenSize.height;
    final isSmallScreen = screenHeight < 700 || screenWidth < 400;
    final isVerySmallScreen = screenHeight < 600 || screenWidth < 350;

    if (widget.transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sentiment_dissatisfied,
              size: isSmallScreen ? 40 : 48,
              color: scheme.onSurface.withOpacity(0.3),
            ),
            SizedBox(height: isSmallScreen ? 8 : 12),
            Text(
              'No data available',
              style: TextStyle(
                color: scheme.onSurface.withOpacity(0.6),
                fontSize: isSmallScreen ? 14 : 16,
              ),
            ),
          ],
        ),
      );
    }

    // Calculate merchant totals (only debit transactions)
    final Map<String, double> totalsByMerchant = {};
    for (final t in widget.transactions) {
      if (t.type == 'debit') {
        totalsByMerchant[t.merchant] = (totalsByMerchant[t.merchant] ?? 0) + t.amount;
      }
    }

    final entries = totalsByMerchant.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final top = entries.take(widget.topCount).toList();
    final othersTotal = entries.skip(widget.topCount).fold<double>(0.0, (sum, e) => sum + e.value);

    final totalSpent = entries.fold<double>(0.0, (sum, e) => sum + e.value);

    if (totalSpent == 0) {
      return Center(
        child: Text(
          'No spending data available',
          style: TextStyle(
            color: scheme.onSurface.withOpacity(0.6),
            fontSize: isSmallScreen ? 14 : 16,
          ),
        ),
      );
    }

    final List<Color> palette = [
      scheme.primary,
      const Color(0xFF26C6DA),
      const Color(0xFF66BB6A),
      const Color(0xFFFFCA28),
      const Color(0xFFEF5350),
      const Color(0xFFAB47BC),
      const Color(0xFF8D6E63),
      const Color(0xFF42A5F5),
    ];

    final sections = <PieChartSectionData>[];
    final legendItems = <_LegendItem>[];

    // Responsive pie chart dimensions
    final baseRadius = isVerySmallScreen ? 45.0 : (isSmallScreen ? 55.0 : 60.0);
    final selectedRadius = baseRadius + (isVerySmallScreen ? 8.0 : 10.0);
    final centerSpaceRadius = isVerySmallScreen ? 25.0 : (isSmallScreen ? 35.0 : 40.0);

    // Create pie sections and legend data
    for (int i = 0; i < top.length; i++) {
      final entry = top[i];
      final value = entry.value;
      final percent = (value / totalSpent) * 100;
      final isSelected = touchedIndex == i;

      sections.add(
        PieChartSectionData(
          color: palette[i % palette.length],
          value: value,
          radius: isSelected ? selectedRadius : baseRadius,
          title: percent > 5 ? '${percent.toStringAsFixed(0)}%' : '',
          titleStyle: TextStyle(
            color: Colors.white,
            fontSize: isSelected
                ? (isVerySmallScreen ? 10 : (isSmallScreen ? 12 : 14))
                : (isVerySmallScreen ? 9 : (isSmallScreen ? 10 : 12)),
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.3),
                offset: const Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
      );

      legendItems.add(_LegendItem(
        color: palette[i % palette.length],
        label: entry.key,
        value: _formatCurrency(value),
        percentage: percent,
      ));
    }

    // Add "Others" section if needed
    if (othersTotal > 0) {
      final percent = (othersTotal / totalSpent) * 100;
      final isSelected = touchedIndex == top.length;

      sections.add(
        PieChartSectionData(
          color: Colors.grey.shade400,
          value: othersTotal,
          radius: isSelected ? selectedRadius : baseRadius,
          title: percent > 5 ? '${percent.toStringAsFixed(0)}%' : '',
          titleStyle: TextStyle(
            color: Colors.white,
            fontSize: isSelected
                ? (isVerySmallScreen ? 10 : (isSmallScreen ? 12 : 14))
                : (isVerySmallScreen ? 9 : (isSmallScreen ? 10 : 12)),
            fontWeight: FontWeight.bold,
            shadows: [
              Shadow(
                color: Colors.black.withOpacity(0.3),
                offset: const Offset(1, 1),
                blurRadius: 2,
              ),
            ],
          ),
        ),
      );

      legendItems.add(_LegendItem(
        color: Colors.grey.shade400,
        label: 'Others',
        value: _formatCurrency(othersTotal),
        percentage: percent,
      ));
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableHeight = constraints.maxHeight;
        final availableWidth = constraints.maxWidth;

        // Responsive layout calculations
        final headerPadding = EdgeInsets.symmetric(
          horizontal: screenWidth * 0.04,
          vertical: isSmallScreen ? 8.0 : 12.0,
        );

        final legendPadding = EdgeInsets.symmetric(
          horizontal: screenWidth * 0.04,
          vertical: isSmallScreen ? 8.0 : 12.0,
        );

        // Calculate pie chart size based on available space
        final maxChartSize = availableWidth * (isSmallScreen ? 0.7 : 0.75);
        final chartAspectRatio = availableHeight > availableWidth ? 1.0 : 0.8;

        return Column(
          children: [
            // Header with title and total spent
            Padding(
              padding: headerPadding,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      'Total spent: ${_formatCurrency(totalSpent)}',
                      style: TextStyle(
                        fontSize: isVerySmallScreen ? 14 : (isSmallScreen ? 16 : 18),
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurface,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            // Pie Chart with flexible sizing
            Expanded(
              flex: isSmallScreen ? 3 : 2,
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: maxChartSize,
                    maxHeight: maxChartSize,
                  ),
                  child: AspectRatio(
                    aspectRatio: chartAspectRatio,
                    child: PieChart(
                      PieChartData(
                        sectionsSpace: isVerySmallScreen ? 1 : 2,
                        centerSpaceRadius: centerSpaceRadius,
                        sections: sections,
                        pieTouchData: PieTouchData(
                          touchCallback: (FlTouchEvent event, pieTouchResponse) {
                            setState(() {
                              if (!event.isInterestedForInteractions ||
                                  pieTouchResponse == null ||
                                  pieTouchResponse.touchedSection == null) {
                                touchedIndex = null;
                                return;
                              }

                              final newIndex = pieTouchResponse.touchedSection!.touchedSectionIndex;
                              if (newIndex >= 0 && newIndex < legendItems.length) {
                                touchedIndex = newIndex;
                              } else {
                                touchedIndex = null;
                              }
                            });
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Legend - Responsive wrapping layout
            Expanded(
              flex: isSmallScreen ? 2 : 1,
              child: SingleChildScrollView(
                child: Padding(
                  padding: legendPadding,
                  child: _buildResponsiveLegend(legendItems, scheme, isSmallScreen, isVerySmallScreen),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildResponsiveLegend(
      List<_LegendItem> legendItems,
      ColorScheme scheme,
      bool isSmallScreen,
      bool isVerySmallScreen
      ) {
    final itemsPerRow = isVerySmallScreen ? 1 : (isSmallScreen ? 2 : 3);
    final fontSize = isVerySmallScreen ? 10.0 : (isSmallScreen ? 11.0 : 12.0);
    final percentageFontSize = isVerySmallScreen ? 9.0 : (isSmallScreen ? 10.0 : 11.0);
    final iconSize = isVerySmallScreen ? 10.0 : 12.0;

    // Group items into rows
    final rows = <List<_LegendItem>>[];
    for (int i = 0; i < legendItems.length; i += itemsPerRow) {
      final end = (i + itemsPerRow < legendItems.length) ? i + itemsPerRow : legendItems.length;
      rows.add(legendItems.sublist(i, end));
    }

    return Column(
      children: rows.map((row) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: isVerySmallScreen ? 2 : 4),
          child: Row(
            children: row.map((item) {
              final index = legendItems.indexOf(item);
              final isHighlighted = touchedIndex == index;

              return Expanded(
                child: Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: isVerySmallScreen ? 2 : 4,
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: isVerySmallScreen ? 4 : 6,
                    vertical: isVerySmallScreen ? 3 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: isHighlighted
                        ? item.color.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(isVerySmallScreen ? 6 : 8),
                    border: isHighlighted
                        ? Border.all(color: item.color.withOpacity(0.3), width: 1)
                        : null,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: iconSize,
                        height: iconSize,
                        decoration: BoxDecoration(
                          color: item.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      SizedBox(width: isVerySmallScreen ? 4 : 6),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              item.label,
                              style: TextStyle(
                                fontSize: fontSize,
                                fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
                                color: scheme.onSurface,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              '${item.percentage.toStringAsFixed(0)}%',
                              style: TextStyle(
                                fontSize: percentageFontSize,
                                fontWeight: FontWeight.w500,
                                color: item.color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );
  }

  String _formatCurrency(double value) {
    if (value == 0) return '₹0';
    if (value >= 1000) {
      return '₹${(value / 1000).toStringAsFixed(value % 1000 == 0 ? 0 : 1)}k';
    }
    return '₹${value.toStringAsFixed(value % 1 == 0 ? 0 : 0)}';
  }
}

class _LegendItem {
  final Color color;
  final String label;
  final String value;
  final double percentage;

  _LegendItem({
    required this.color,
    required this.label,
    required this.value,
    required this.percentage,
  });
}