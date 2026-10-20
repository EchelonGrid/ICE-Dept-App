import '../utils/routine_helper.dart';
import 'routine_model.dart';

class DepartmentRoutineModel {
  final String id;
  final String batch; // e.g. 'ICE-18'
  final String dayOfWeek; // 'Saturday', 'Sunday', etc.
  final String startTime; // '09:00:00'
  final String endTime; // '10:00:00'
  final String courseCode; // 'ICE-2203'
  final String? teacherInitial; // 'MIH'
  final String? roomNumber; // '903'
  final bool isLab;
  final String weekParity; // 'odd', 'even', 'all'
  final DateTime? effectiveStartDate;
  final DateTime? createdAt;

  // Joined / looked-up display field
  final String? teacherFullName;

  /// Resolves friendly course title (e.g. 'Signals and Systems' for 'ICE-2202')
  String get courseTitle => RoutineHelper.lookupCourseTitle(courseCode);

  DepartmentRoutineModel({
    required this.id,
    required this.batch,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.courseCode,
    this.teacherInitial,
    this.roomNumber = 'TBA',
    this.isLab = false,
    this.weekParity = 'all',
    this.effectiveStartDate,
    this.createdAt,
    this.teacherFullName,
  });

  factory DepartmentRoutineModel.fromJson(Map<String, dynamic> json) {
    return DepartmentRoutineModel(
      id: json['id'] as String? ?? '',
      batch: json['batch'] as String? ?? '',
      dayOfWeek: json['day_of_week'] as String? ?? 'Sunday',
      startTime: json['start_time'] as String? ?? '09:00:00',
      endTime: json['end_time'] as String? ?? '10:00:00',
      courseCode: json['course_code'] as String? ?? '',
      teacherInitial: json['teacher_initial'] as String?,
      roomNumber: json['room_number'] as String? ?? 'TBA',
      isLab: json['is_lab'] as bool? ?? false,
      weekParity: json['week_parity'] as String? ?? 'all',
      effectiveStartDate: json['effective_start_date'] != null
          ? DateTime.tryParse(json['effective_start_date'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      teacherFullName: json['teacher_full_name'] as String?,
    );
  }

  Map<String, dynamic> toJson({bool includeId = true}) {
    final map = <String, dynamic>{
      'batch': batch,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'course_code': courseCode,
      'teacher_initial': teacherInitial,
      'room_number': roomNumber ?? 'TBA',
      'is_lab': isLab,
      'week_parity': weekParity,
      if (effectiveStartDate != null)
        'effective_start_date': effectiveStartDate!.toIso8601String().split('T').first,
    };
    if (includeId && id.isNotEmpty) {
      map['id'] = id;
    }
    return map;
  }

  DepartmentRoutineModel copyWith({
    String? id,
    String? batch,
    String? dayOfWeek,
    String? startTime,
    String? endTime,
    String? courseCode,
    String? teacherInitial,
    String? roomNumber,
    bool? isLab,
    String? weekParity,
    DateTime? effectiveStartDate,
    DateTime? createdAt,
    String? teacherFullName,
  }) {
    return DepartmentRoutineModel(
      id: id ?? this.id,
      batch: batch ?? this.batch,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      courseCode: courseCode ?? this.courseCode,
      teacherInitial: teacherInitial ?? this.teacherInitial,
      roomNumber: roomNumber ?? this.roomNumber,
      isLab: isLab ?? this.isLab,
      weekParity: weekParity ?? this.weekParity,
      effectiveStartDate: effectiveStartDate ?? this.effectiveStartDate,
      createdAt: createdAt ?? this.createdAt,
      teacherFullName: teacherFullName ?? this.teacherFullName,
    );
  }

  /// Converts this department routine to a RoutineModel for seamless interoperability
  /// with QR generator, attendance tracking, and attendance logs.
  RoutineModel toRoutineModel({String? teacherId, String? teacherName}) {
    final digits = RegExp(r'\d+').firstMatch(batch)?.group(0);
    final bNum = digits != null ? int.tryParse(digits) : null;
    return RoutineModel(
      id: id.isNotEmpty ? id : 'routine-${courseCode.toLowerCase()}-${dayOfWeek.toLowerCase()}',
      batchId: batch,
      teacherId: teacherId ?? teacherInitial ?? 'MAH',
      dayOfWeek: RoutineHelper.getWeekdayFromDayName(dayOfWeek),
      startTime: startTime,
      endTime: endTime,
      courseName: '$courseCode: $courseTitle${isLab ? " [Lab]" : ""}',
      roomNumber: roomNumber ?? 'TBA',
      teacherName: teacherName ?? teacherFullName ?? teacherInitial,
      batchNumber: bNum,
    );
  }
}
