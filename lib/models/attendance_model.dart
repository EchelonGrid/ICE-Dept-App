class AttendanceModel {
  final String id;
  final String classId;
  final String studentId;
  final DateTime date;
  final String status; // 'present', 'absent'
  final DateTime? createdAt;

  // Joined fields
  final String? studentName;
  final String? studentRoll;
  final String? courseName;

  AttendanceModel({
    required this.id,
    required this.classId,
    required this.studentId,
    required this.date,
    this.status = 'present',
    this.createdAt,
    this.studentName,
    this.studentRoll,
    this.courseName,
  });

  bool get isPresent => status == 'present';

  factory AttendanceModel.fromJson(Map<String, dynamic> json) {
    String? sName;
    if (json['users'] != null && json['users'] is Map) {
      sName = json['users']['name'] as String?;
    }

    String? cName;
    if (json['class_routine'] != null && json['class_routine'] is Map) {
      cName = json['class_routine']['course_name'] as String?;
    }

    return AttendanceModel(
      id: json['id'] as String,
      classId: json['class_id'] as String,
      studentId: json['student_id'] as String,
      date: json['date'] != null
          ? DateTime.tryParse(json['date'] as String) ?? DateTime.now()
          : DateTime.now(),
      status: json['status'] as String? ?? 'present',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      studentName: sName ?? json['student_name'] as String?,
      studentRoll: json['student_roll'] as String?,
      courseName: cName ?? json['course_name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'class_id': classId,
      'student_id': studentId,
      'date': "${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}",
      'status': status,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}
