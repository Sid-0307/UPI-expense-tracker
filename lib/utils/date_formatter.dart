import 'package:intl/intl.dart';

class DateFormatter {
  static final DateFormat _fullDateFormat = DateFormat('dd MMM yyyy, h:mm a');
  static final DateFormat _dayMonthFormat = DateFormat('dd MMM');

  // Format full date with time
  static String formatDateTime(DateTime dateTime) {
    return _fullDateFormat.format(dateTime);
  }

  // Format just day and month
  static String formatDayMonth(DateTime dateTime) {
    return _dayMonthFormat.format(dateTime);
  }

  // Get month name
  static String getMonthName(int month) {
    return DateFormat('MMMM').format(DateTime(2022, month));
  }

  // Get current month name
  static String getCurrentMonthName() {
    return getMonthName(DateTime.now().month);
  }
}