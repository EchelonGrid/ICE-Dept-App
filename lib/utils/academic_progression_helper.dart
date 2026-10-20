class AcademicProgressionHelper {
  /// The standard 8-semester sequence in ICE department
  static const List<String> semesterOrder = [
    '1-1',
    '1-2',
    '2-1',
    '2-2',
    '3-1',
    '3-2',
    '4-1',
    '4-2',
  ];

  /// Returns the next semester in the sequence, or null if graduating/invalid
  static String? getNextSemester(String current) {
    final clean = current.trim();
    final index = semesterOrder.indexOf(clean);
    if (index == -1 || index == semesterOrder.length - 1) {
      return null; // 4-2 reaches graduation
    }
    return semesterOrder[index + 1];
  }

  /// Returns true if the batch is in its final academic term (4-2) and will graduate on next promotion
  static bool isGraduating(String current) => current.trim() == '4-2';

  /// Calculates odd/even parity based on the semester start date baseline
  static String calculateParity(DateTime startDate, [DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    final diffDays = now.difference(startDate).inDays;
    final weekNumber = (diffDays / 7).floor() + 1;
    return (weekNumber % 2 != 0) ? 'odd' : 'even';
  }

  /// Calculates the 1-based academic week number from semester start
  static int calculateAcademicWeek(DateTime startDate, [DateTime? referenceDate]) {
    final now = referenceDate ?? DateTime.now();
    final diffDays = now.difference(startDate).inDays;
    final weekNumber = (diffDays / 7).floor() + 1;
    return weekNumber < 1 ? 1 : weekNumber;
  }
}
