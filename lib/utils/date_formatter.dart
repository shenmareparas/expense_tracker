import 'package:intl/intl.dart';

class DateFormatter {
  static final _dateFormat = DateFormat('MMM d, yyyy');
  static final _timeFormat = DateFormat.jm();

  static String formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateToCheck = DateTime(date.year, date.month, date.day);

    if (dateToCheck == today) {
      return 'Today';
    } else if (dateToCheck == yesterday) {
      return 'Yesterday';
    } else {
      return _dateFormat.format(date);
    }
  }

  static String formatDateTime(DateTime date) {
    return '${formatDate(date)}, ${_timeFormat.format(date)}';
  }
}
