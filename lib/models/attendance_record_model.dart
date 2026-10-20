import 'package:intl/intl.dart';

class AttendanceRecordModel {
  final String id;
  final String sessionId;
  final String? studentId;
  final String studentRoll;
  final String studentName;
  final String status; // 'PRESENT', 'ABSENT'
  final DateTime? scannedAt;

  AttendanceRecordModel({
    required this.id,
    required this.sessionId,
    this.studentId,
    required this.studentRoll,
    required this.studentName,
    this.status = 'PRESENT',
    this.scannedAt,
  });

  bool get isPresent => status.toUpperCase() == 'PRESENT';

  String get checkInTimeFormatted {
    if (scannedAt == null) {
      return isPresent ? 'Manual entry' : 'Absent';
    }
    return DateFormat('hh:mm a').format(scannedAt!.toLocal());
  }

  factory AttendanceRecordModel.fromJson(Map<String, dynamic> json) {
    return AttendanceRecordModel(
      id: json['id'] as String,
      sessionId: json['session_id'] as String? ?? '',
      studentId: json['student_id'] as String?,
      studentRoll: (json['student_roll'] as String? ?? '').trim(),
      studentName: (json['student_name'] as String? ?? '').trim(),
      status: (json['status'] as String? ?? 'PRESENT').toUpperCase().trim(),
      scannedAt: json['scanned_at'] != null
          ? DateTime.tryParse(json['scanned_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'session_id': sessionId,
      if (studentId != null) 'student_id': studentId,
      'student_roll': studentRoll,
      'student_name': studentName,
      'status': status.toUpperCase(),
      if (scannedAt != null) 'scanned_at': scannedAt!.toIso8601String(),
    };
  }

  AttendanceRecordModel copyWith({
    String? id,
    String? sessionId,
    String? studentId,
    String? studentRoll,
    String? studentName,
    String? status,
    DateTime? scannedAt,
    bool clearScannedAt = false,
  }) {
    return AttendanceRecordModel(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      studentId: studentId ?? this.studentId,
      studentRoll: studentRoll ?? this.studentRoll,
      studentName: studentName ?? this.studentName,
      status: status ?? this.status,
      scannedAt: clearScannedAt ? null : (scannedAt ?? this.scannedAt),
    );
  }
}
