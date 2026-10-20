import 'package:intl/intl.dart';
import '../core/constants/curriculum.dart';

class RoutineHelper {
  /// Default semester start date for the current academic session
  static final DateTime defaultSemesterStartDate = DateTime(2026, 7, 15);

  /// Standard academic days in ICE department routine (Saturday to Wednesday)
  static const List<String> academicDays = [
    'Saturday',
    'Sunday',
    'Monday',
    'Tuesday',
    'Wednesday',
  ];

  /// Short 3-letter day codes for official departmental routine
  static const List<String> academicDaysShort = [
    'Sat',
    'Sun',
    'Mon',
    'Tue',
    'Wed',
  ];

  /// Batch Normalizer:
  /// Maps strings like "18B", "18", "Batch 18", or 18 into the canonical format "ICE-18".
  static String normalizeBatch(dynamic input) {
    if (input == null) return 'ICE-18';
    final str = input.toString().trim();
    if (str.isEmpty) return 'ICE-18';

    // Look for integer batch numbers
    final match = RegExp(r'\d+').firstMatch(str);
    if (match != null) {
      return 'ICE-${match.group(0)}';
    }

    // If input is purely alphabetical (e.g. ICE), uppercase it
    return str.toUpperCase();
  }

  /// Dynamic Odd/Even Parity Function based on semester start date baseline
  static String calculateParity(DateTime startDate, [DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    final diffDays = now.difference(startDate).inDays;
    final weekNumber = (diffDays / 7).floor() + 1;
    return (weekNumber % 2 != 0) ? 'odd' : 'even';
  }

  /// Week Parity Calculator:
  /// Given semester start date (defaults to 2026-07-15):
  /// Week 1 = Odd, Week 2 = Even, etc.
  static String getCurrentWeekParity([DateTime? startDate, DateTime? referenceDate]) {
    final start = startDate ?? defaultSemesterStartDate;
    return calculateParity(start, referenceDate);
  }

  /// Returns the 1-based academic week number from semester start
  static int getCurrentAcademicWeek([DateTime? startDate, DateTime? referenceDate]) {
    final start = startDate ?? defaultSemesterStartDate;
    final now = referenceDate ?? DateTime.now();
    final diffDays = now.difference(start).inDays;
    return (diffDays / 7).floor() + 1;
  }

  /// Checks whether a routine slot is active for the current week parity.
  /// If [slotParity] is 'all', null, or empty, it is active every week.
  static bool isSlotActiveForWeek({
    required String? slotParity,
    DateTime? startDate,
    DateTime? referenceDate,
  }) {
    if (slotParity == null || slotParity.isEmpty || slotParity.toLowerCase() == 'all') {
      return true;
    }
    final currentParity = getCurrentWeekParity(startDate, referenceDate);
    return slotParity.toLowerCase().trim() == currentParity;
  }

  /// Formats 'HH:mm:ss' or 'HH:mm' into a readable 12-hour format: '9:00 AM' or '2:00 PM'.
  static String formatTime12Hour(String timeString) {
    try {
      final parts = timeString.trim().split(':');
      if (parts.length >= 2) {
        final hour = int.parse(parts[0]);
        final minute = int.parse(parts[1]);
        final dt = DateTime(2026, 1, 1, hour, minute);
        return DateFormat('h:mm a').format(dt);
      }
    } catch (_) {}
    return timeString;
  }

  /// Formats a time range into '9:00 AM - 10:00 AM'
  static String formatTimeRange(String startTime, String endTime) {
    final start = formatTime12Hour(startTime);
    final end = formatTime12Hour(endTime);
    return '$start - $end';
  }

  /// Maps weekday integer (DateTime.weekday: 1=Mon, ..., 6=Sat, 7=Sun) to routine Day name.
  static String getDayNameFromWeekday(int weekday) {
    switch (weekday) {
      case DateTime.saturday:
        return 'Saturday';
      case DateTime.sunday:
        return 'Sunday';
      case DateTime.monday:
        return 'Monday';
      case DateTime.tuesday:
        return 'Tuesday';
      case DateTime.wednesday:
        return 'Wednesday';
      case DateTime.thursday:
        return 'Thursday';
      case DateTime.friday:
        return 'Friday';
      default:
        return 'Sunday';
    }
  }

  /// Maps day name string to DateTime weekday integer (1=Mon ... 7=Sun)
  static int getWeekdayFromDayName(String dayName) {
    switch (dayName.toLowerCase().trim()) {
      case 'saturday':
      case 'sat':
        return DateTime.saturday;
      case 'sunday':
      case 'sun':
        return DateTime.sunday;
      case 'monday':
      case 'mon':
        return DateTime.monday;
      case 'tuesday':
      case 'tue':
        return DateTime.tuesday;
      case 'wednesday':
      case 'wed':
        return DateTime.wednesday;
      case 'thursday':
      case 'thu':
        return DateTime.thursday;
      case 'friday':
      case 'fri':
        return DateTime.friday;
      default:
        return DateTime.sunday;
    }
  }

  /// Normalizes short ('Sat') or lowercase ('saturday') day strings into canonical full day names ('Saturday').
  static String normalizeDayName(String dayName) {
    final clean = dayName.trim().toLowerCase();
    switch (clean) {
      case 'sat':
      case 'saturday':
        return 'Saturday';
      case 'sun':
      case 'sunday':
        return 'Sunday';
      case 'mon':
      case 'monday':
        return 'Monday';
      case 'tue':
      case 'tuesday':
        return 'Tuesday';
      case 'wed':
      case 'wednesday':
        return 'Wednesday';
      case 'thu':
      case 'thursday':
        return 'Thursday';
      case 'fri':
      case 'friday':
        return 'Friday';
      default:
        return dayName.trim();
    }
  }

  /// Calculates how many minutes remain until the class begins.
  /// If the class has already begun, returns negative minutes.
  static int getMinutesUntilClass(String startTime, [DateTime? referenceNow]) {
    final now = referenceNow ?? DateTime.now();
    try {
      final parts = startTime.trim().split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final classStart = DateTime(now.year, now.month, now.day, hour, minute);
      return classStart.difference(now).inMinutes;
    } catch (_) {
      return 0;
    }
  }

  /// Checks if a class is currently ongoing
  static bool isClassOngoing(String startTime, String endTime, [DateTime? referenceNow]) {
    final now = referenceNow ?? DateTime.now();
    try {
      final sParts = startTime.trim().split(':');
      final eParts = endTime.trim().split(':');
      final sDt = DateTime(now.year, now.month, now.day, int.parse(sParts[0]), int.parse(sParts[1]));
      final eDt = DateTime(now.year, now.month, now.day, int.parse(eParts[0]), int.parse(eParts[1]));
      return (now.isAfter(sDt) || now.isAtSameMomentAs(sDt)) && now.isBefore(eDt);
    } catch (_) {
      return false;
    }
  }

  /// Resolves full course title from course code, checking common department codes
  /// and the full DepartmentCurriculum catalog.
  static String lookupCourseTitle(String courseCode) {
    final cleanCode = courseCode.toUpperCase().replaceAll(RegExp(r'\s+'), '').trim();
    const directMap = {
      'ICE-1101': 'Fundamentals of ICT',
      'ICE-1102': 'Basic Electronics',
      'ICE-1103': 'Structured Programming',
      'ICE-1105': 'Structured Programming Language',
      'ICE-1106': 'Structured Programming Lab',
      'ICE-1201': 'Object Oriented Programming',
      'ICE-1202': 'Circuit Theory and Analysis',
      'ICE-1203': 'Analog Electronics',
      'ICE-2101': 'Analog Communication',
      'ICE-2102': 'Digital Electronics',
      'ICE-2201': 'Data Structure and Algorithm',
      'ICE-2202': 'Signals and Systems',
      'ICE-2203': 'Analog Communication',
      'ICE-2204': 'Analog Communication Lab',
      'ICE-2205': 'Digital Electronics',
      'ICE-2207': 'Discrete Mathematics',
      'ICE-2208': 'Digital Electronics Lab',
      'ICE-2209': 'Engineering Electromagnetics',
      'ICE-2210': 'Microwave Engineering Lab',
      'ICE-3101': 'Artificial Intelligence and Robotics',
      'ICE-3102': 'Web Programming',
      'ICE-3103': 'Database Management Systems',
      'ICE-3104': 'Electromagnetic Fields and Waves',
      'ICE-3105': 'Computer Architecture & Microcontrollers',
      'ICE-3201': 'Network Programming with Java',
      'ICE-3202': 'Antenna Engineering',
      'ICE-3203': 'Digital Communication',
      'ICE-3204': 'Digital Image & Speech Processing',
      'ICE-3205': 'Operating System',
      'ICE-4101': 'Data Communication and Networking',
      'ICE-4102': 'Machine Learning',
      'ICE-4103': 'Cryptography and Data Security',
      'ICE-4116': 'Cellular & Mobile Communication',
      'ICE-4117': 'Mobile Communication Lab',
      'ICE-4201': 'Cellular and Wireless Communication',
      'ICE-4202': 'System Analysis and Software Testing',
      'ICE-4203': 'Information Theory and Coding',
    };

    if (directMap.containsKey(cleanCode)) {
      return directMap[cleanCode]!;
    }

    for (final sem in DepartmentCurriculum.allSemesters) {
      for (final s in sem.subjects) {
        if (s.code.toUpperCase().replaceAll(RegExp(r'\s+'), '') == cleanCode) {
          return s.name;
        }
      }
    }

    return courseCode;
  }
}
