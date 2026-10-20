import 'attendance_record_model.dart';

class AttendanceSessionModel {
  final String id;
  final String courseCode;
  final String batch;
  final String teacherInitial;
  final DateTime sessionDate;
  final String? startTime;
  final String status; // 'COMPLETED', 'ACTIVE', 'CANCELLED', 'RESCHEDULED'
  final DateTime? createdAt;
  final int totalStudents;
  final int presentCount;
  final List<AttendanceRecordModel> records;

  AttendanceSessionModel({
    required this.id,
    required this.courseCode,
    required this.batch,
    required this.teacherInitial,
    required this.sessionDate,
    this.startTime,
    this.status = 'COMPLETED',
    this.createdAt,
    this.totalStudents = 0,
    this.presentCount = 0,
    this.records = const [],
  });

  bool get isCancelled => status.toUpperCase() == 'CANCELLED';
  bool get isRescheduled => status.toUpperCase() == 'RESCHEDULED';
  bool get isActive => status.toUpperCase() == 'ACTIVE';

  int get absentCount => (totalStudents - presentCount).clamp(0, totalStudents);

  int get attendancePercentage {
    if (totalStudents <= 0) return 0;
    return ((presentCount / totalStudents) * 100).round();
  }

  String get formattedAttendanceRate {
    if (totalStudents <= 0) return 'No students';
    return '$presentCount/$totalStudents Present ($attendancePercentage%)';
  }

  factory AttendanceSessionModel.fromJson(
    Map<String, dynamic> json, {
    List<AttendanceRecordModel>? records,
  }) {
    final parsedRecords = records ??
        (json['attendance_records'] as List<dynamic>?)
            ?.map((r) => AttendanceRecordModel.fromJson(r as Map<String, dynamic>))
            .toList() ??
        [];

    final totalCount = json['total_students'] as int? ??
        json['total_records'] as int? ??
        parsedRecords.length;

    final presCount = json['present_count'] as int? ??
        parsedRecords.where((r) => r.isPresent).length;

    return AttendanceSessionModel(
      id: json['id'] as String,
      courseCode: (json['course_code'] as String? ?? '').trim(),
      batch: (json['batch'] as String? ?? '').trim(),
      teacherInitial: (json['teacher_initial'] as String? ?? '').trim(),
      sessionDate: json['session_date'] != null
          ? DateTime.tryParse(json['session_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      startTime: json['start_time'] as String?,
      status: (json['status'] as String? ?? 'COMPLETED').trim(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      totalStudents: totalCount,
      presentCount: presCount,
      records: parsedRecords,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'course_code': courseCode,
      'batch': batch,
      'teacher_initial': teacherInitial,
      'session_date':
          "${sessionDate.year.toString().padLeft(4, '0')}-${sessionDate.month.toString().padLeft(2, '0')}-${sessionDate.day.toString().padLeft(2, '0')}",
      if (startTime != null) 'start_time': startTime,
      'status': status,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  AttendanceSessionModel copyWith({
    String? id,
    String? courseCode,
    String? batch,
    String? teacherInitial,
    DateTime? sessionDate,
    String? startTime,
    String? status,
    DateTime? createdAt,
    int? totalStudents,
    int? presentCount,
    List<AttendanceRecordModel>? records,
  }) {
    return AttendanceSessionModel(
      id: id ?? this.id,
      courseCode: courseCode ?? this.courseCode,
      batch: batch ?? this.batch,
      teacherInitial: teacherInitial ?? this.teacherInitial,
      sessionDate: sessionDate ?? this.sessionDate,
      startTime: startTime ?? this.startTime,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      totalStudents: totalStudents ?? this.totalStudents,
      presentCount: presentCount ?? this.presentCount,
      records: records ?? this.records,
    );
  }
}
