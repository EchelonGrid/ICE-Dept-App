import 'package:intl/intl.dart';

class DateTimeHelper {
  static final DateFormat _timeFormat = DateFormat('h:mm a');
  static final DateFormat _dateFormat = DateFormat('EEE, MMM d, yyyy');
  static final DateFormat _shortDateFormat = DateFormat('MMM d, h:mm a');

  static String formatTime(String timeString) {
    try {
      final parts = timeString.split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final now = DateTime.now();
        final dt = DateTime(now.year, now.month, now.day, hour, minute);
        return _timeFormat.format(dt);
      }
    } catch (_) {}
    return timeString;
  }

  static String formatDate(DateTime dateTime) {
    return _dateFormat.format(dateTime);
  }

  static String formatShortDateTime(DateTime dateTime) {
    return _shortDateFormat.format(dateTime);
  }

  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 45) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  static String getDayName(int dayOfWeek) {
    switch (dayOfWeek) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      case 6:
        return 'Saturday';
      case 7:
        return 'Sunday';
      default:
        return 'Unknown';
    }
  }

  static int getEffectiveRoutineDay() {
    final now = DateTime.now();
    // In Dart DateTime.weekday: 1 is Mon, 7 is Sun
    if (now.hour >= 18) {
      // Past 6:00 PM, show tomorrow's schedule
      final tomorrow = now.add(const Duration(days: 1));
      return tomorrow.weekday;
    }
    return now.weekday;
  }

  static bool isViewingTomorrowSchedule() {
    return DateTime.now().hour >= 18;
  }
}
