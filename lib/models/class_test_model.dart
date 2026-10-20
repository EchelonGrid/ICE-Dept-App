import 'package:intl/intl.dart';

class ClassTestModel {
  final String id;
  final String batch;
  final String courseCode;
  final String title;
  final String? syllabus;
  final DateTime testDate;
  final String? testTime;
  final String? createdBy;
  final DateTime? createdAt;

  ClassTestModel({
    required this.id,
    required this.batch,
    required this.courseCode,
    required this.title,
    this.syllabus,
    required this.testDate,
    this.testTime,
    this.createdBy,
    this.createdAt,
  });

  factory ClassTestModel.fromJson(Map<String, dynamic> json) {
    return ClassTestModel(
      id: json['id'] as String,
      batch: json['batch'] as String,
      courseCode: json['course_code'] as String,
      title: json['title'] as String,
      syllabus: json['syllabus'] as String?,
      testDate: DateTime.parse(json['test_date'] as String),
      testTime: json['test_time'] as String?,
      createdBy: json['created_by'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'batch': batch,
      'course_code': courseCode,
      'title': title,
      if (syllabus != null) 'syllabus': syllabus,
      'test_date': DateFormat('yyyy-MM-dd').format(testDate),
      if (testTime != null) 'test_time': testTime,
      if (createdBy != null) 'created_by': createdBy,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  /// Calculates human-readable countdown text (e.g., "Today", "Tomorrow", "In 3 days").
  String get countdownText {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(testDate.year, testDate.month, testDate.day);
    final diffDays = target.difference(today).inDays;

    if (diffDays == 0) {
      return 'Today';
    } else if (diffDays == 1) {
      return 'Tomorrow';
    } else if (diffDays > 1) {
      return 'In $diffDays days';
    } else if (diffDays == -1) {
      return 'Yesterday';
    } else {
      return '${diffDays.abs()} days ago';
    }
  }

  /// Checks if the test date is today or in the future.
  bool get isUpcoming {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(testDate.year, testDate.month, testDate.day);
    return target.isAtSameMomentAs(today) || target.isAfter(today);
  }

  /// Formatted date string (e.g., "Thursday, Sep 10, 2026").
  String get formattedDate {
    return DateFormat('EEEE, MMM d, yyyy').format(testDate);
  }

  /// Formatted time string (e.g., "10:30 AM").
  String? get formattedTime {
    if (testTime == null || testTime!.isEmpty) return null;
    try {
      final parts = testTime!.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      final dt = DateTime(2026, 1, 1, hour, minute);
      return DateFormat('hh:mm a').format(dt);
    } catch (_) {
      return testTime;
    }
  }
}
