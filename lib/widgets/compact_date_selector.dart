import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:upi_expense_tracker/utils/date_formatter.dart';

class CompactDateSelector extends StatefulWidget {
  final DateTime startDate;
  final DateTime endDate;
  final Function(DateTime, DateTime) onDateRangeChanged;
  final Function(int) onQuickRangeSelected;

  const CompactDateSelector({
    Key? key,
    required this.startDate,
    required this.endDate,
    required this.onDateRangeChanged,
    required this.onQuickRangeSelected,
  }) : super(key: key);

  @override
  State<CompactDateSelector> createState() => _CompactDateSelectorState();
}

class _CompactDateSelectorState extends State<CompactDateSelector> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final daysDiff = widget.endDate.difference(widget.startDate).inDays;
    final dateRangeText = daysDiff == 0 
        ? DateFormat('dd MMM yyyy').format(widget.startDate)
        : '${DateFormat('dd MMM').format(widget.startDate)} - ${DateFormat('dd MMM yyyy').format(widget.endDate)}';

    return Card(
      margin: EdgeInsets.zero,
      color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: scheme.primary),
        ),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      dateRangeText,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  AnimatedRotation(
                    turns: _isExpanded ? 0.5 : 0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(Icons.keyboard_arrow_down, color: scheme.primary),
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.only(left: 8,right: 8,top: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _QuickButton('7d', 7),
                      _QuickButton('30d', 30),
                      _QuickButton('90d', 90),
                      _QuickButton('1y', 365),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Padding(
                    padding: const EdgeInsets.only(left: 8,right: 8,bottom: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: _DateField(
                            label: 'Start',
                            date: widget.startDate,
                            onChanged: (date) => widget.onDateRangeChanged(date, widget.endDate),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _DateField(
                            label: 'End',
                            date: widget.endDate,
                            onChanged: (date) => widget.onDateRangeChanged(widget.startDate, date),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _QuickButton(String label, int days) {
    final scheme = Theme.of(context).colorScheme;
    final width = MediaQuery.of(context).size.width;

    return InkWell(
      onTap: () => widget.onQuickRangeSelected(days),
      borderRadius: BorderRadius.circular(10),
      child: SizedBox(
        width: width / 5, // each button takes 1/4th of screen width
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: scheme.primary,
            borderRadius: BorderRadius.circular(10),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              color: scheme.onPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime date;
  final Function(DateTime) onChanged;

  const _DateField({
    Key? key,
    required this.label,
    required this.date,
    required this.onChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () async {
        final selectedDate = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
          builder: (context, child) {
            return Theme(
              data: Theme.of(context).copyWith(
                colorScheme: scheme,
              ),
              child: child!,
            );
          },
        );
        if (selectedDate != null) {
          onChanged(selectedDate);
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: scheme.outlineVariant),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_month, size: 16, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                DateFormat('dd MMM yyyy').format(date),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
