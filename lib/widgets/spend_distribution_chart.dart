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

    if (widget.transactions.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.sentiment_dissatisfied,
              size: 48,
              color: scheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 12),
            Text(
              'No data available',
              style: TextStyle(
                color: scheme.onSurface.withOpacity(0.6),
                fontSize: 16,
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
          style: TextStyle(color: scheme.onSurface.withOpacity(0.6)),
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
          radius: isSelected ? 70 : 60,
          title: percent > 5 ? '${percent.toStringAsFixed(0)}%' : '',
          titleStyle: TextStyle(
            color: Colors.white,
            fontSize: isSelected ? 14 : 12,
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
          radius: isSelected ? 70 : 60,
          title: percent > 5 ? '${percent.toStringAsFixed(0)}%' : '',
          titleStyle: TextStyle(
            color: Colors.white,
            fontSize: isSelected ? 14 : 12,
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

    return Column(
      children: [
        // Header with title and total spent
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'Total spent : ${_formatCurrency(totalSpent)}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),

        // Pie Chart
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1,
              child: PieChart(
                PieChartData(
                  sectionsSpace: 2,
                  centerSpaceRadius: 40,
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
                        // Ensure the touched index is valid for our legend items
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

        // Legend - Wrapping horizontal layout
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: legendItems.asMap().entries.map((entry) {
              final index = entry.key;
              final item = entry.value;
              final isHighlighted = touchedIndex == index;

              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: isHighlighted
                      ? item.color.withOpacity(0.1)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: isHighlighted
                      ? Border.all(color: item.color.withOpacity(0.3), width: 1)
                      : null,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: item.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      item.label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.w500,
                        color: scheme.onSurface,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      '(${item.percentage.toStringAsFixed(0)}%)',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: item.color,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
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