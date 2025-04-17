import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class DateRangeSelector extends StatelessWidget {
  final DateTime startDate;
  final DateTime endDate;
  final Function(DateTime, DateTime) onDateRangeChanged;
  final Function(int) onQuickRangeSelected;
  final bool compactMode;

  const DateRangeSelector({
    Key? key,
    required this.startDate,
    required this.endDate,
    required this.onDateRangeChanged,
    required this.onQuickRangeSelected,
    this.compactMode = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd MMM yyyy');

    return Card(
      elevation: 2,
      child: Padding(
        padding: EdgeInsets.all(compactMode ? 8.0 : 16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!compactMode) ...[
              const Text(
                'Date Range',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Date range display and picker
            Row(
              children: [
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, true),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                        labelText: 'From',
                      ),
                      child: Text(dateFormat.format(startDate)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: InkWell(
                    onTap: () => _selectDate(context, false),
                    child: InputDecorator(
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        border: OutlineInputBorder(),
                        labelText: 'To',
                      ),
                      child: Text(dateFormat.format(endDate)),
                    ),
                  ),
                ),
              ],
            ),

            if (!compactMode) ...[
              const SizedBox(height: 16),

              // Quick filter buttons
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildQuickFilterChip('Last 7 days', 7),
                  _buildQuickFilterChip('Last 30 days', 30),
                  _buildQuickFilterChip('Last 90 days', 90),
                  _buildQuickFilterChip('This Month', -1), // Special case
                ],
              ),
            ] else ...[
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildQuickFilterChip('7 days', 7),
                    const SizedBox(width: 8),
                    _buildQuickFilterChip('30 days', 30),
                    const SizedBox(width: 8),
                    _buildQuickFilterChip('90 days', 90),
                    const SizedBox(width: 8),
                    _buildQuickFilterChip('This Month', -1),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildQuickFilterChip(String label, int days) {
    return FilterChip(
      label: Text(label),
      onSelected: (_) {
        if (days == -1) {
          // This Month special case
          final now = DateTime.now();
          final firstDayOfMonth = DateTime(now.year, now.month, 1);
          onDateRangeChanged(firstDayOfMonth, now);
        } else {
          onQuickRangeSelected(days);
        }
      },
      selected: _isChipSelected(days),
      backgroundColor: Colors.grey[200],
      selectedColor: Colors.blue[100],
    );
  }

  bool _isChipSelected(int days) {
    if (days == -1) {
      // Check if date range matches "This Month"
      final now = DateTime.now();
      final firstDayOfMonth = DateTime(now.year, now.month, 1);
      return startDate.year == firstDayOfMonth.year &&
             startDate.month == firstDayOfMonth.month &&
             startDate.day == firstDayOfMonth.day &&
             endDate.year == now.year &&
             endDate.month == now.month &&
             endDate.day == now.day;
    } else {
      // Check if the date range matches the days
      final now = DateTime.now();
      final expectedStartDate = now.subtract(Duration(days: days));
      return startDate.year == expectedStartDate.year &&
             startDate.month == expectedStartDate.month &&
             startDate.day == expectedStartDate.day &&
             endDate.year == now.year &&
             endDate.month == now.month &&
             endDate.day == now.day;
    }
  }

  Future<void> _selectDate(BuildContext context, bool isStartDate) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: isStartDate ? startDate : endDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );

    if (picked != null) {
      if (isStartDate) {
        // Ensure start date isn't after end date
        final newStartDate = picked.isAfter(endDate) ? endDate : picked;
        onDateRangeChanged(newStartDate, endDate);
      } else {
        // Ensure end date isn't before start date
        final newEndDate = picked.isBefore(startDate) ? startDate : picked;
        onDateRangeChanged(startDate, newEndDate);
      }
    }
  }
}