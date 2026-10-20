class RoutineModel {
  final String id;
  final String batchId;
  final String teacherId;
  final int dayOfWeek; // 1=Monday, ..., 7=Sunday
  final String startTime; // '10:00:00'
  final String endTime; // '11:30:00'
  final String courseName;
  final String roomNumber;
  final String status; // 'scheduled', 'canceled'
  final DateTime? createdAt;
  
  // Joined fields
  final String? teacherName;
  final int? batchNumber;

  RoutineModel({
    required this.id,
    required this.batchId,
    required this.teacherId,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.courseName,
    this.roomNumber = 'ICE-Room 101',
    this.status = 'scheduled',
    this.createdAt,
    this.teacherName,
    this.batchNumber,
  });

  bool get isCanceled => status == 'canceled';
  bool get isScheduled => status == 'scheduled';

  factory RoutineModel.fromJson(Map<String, dynamic> json) {
    String? tName;
    if (json['users'] != null && json['users'] is Map) {
      tName = json['users']['name'] as String?;
    }

    int? bNum;
    if (json['batches'] != null && json['batches'] is Map) {
      bNum = json['batches']['batch_number'] as int?;
    }

    return RoutineModel(
      id: json['id'] as String,
      batchId: json['batch_id'] as String,
      teacherId: json['teacher_id'] as String,
      dayOfWeek: json['day_of_week'] as int? ?? 1,
      startTime: json['start_time'] as String? ?? '09:00:00',
      endTime: json['end_time'] as String? ?? '10:30:00',
      courseName: json['course_name'] as String? ?? '',
      roomNumber: json['room_number'] as String? ?? 'ICE-Room 101',
      status: json['status'] as String? ?? 'scheduled',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      teacherName: tName ?? json['teacher_name'] as String?,
      batchNumber: bNum ?? json['batch_number'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'batch_id': batchId,
      'teacher_id': teacherId,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'course_name': courseName,
      'room_number': roomNumber,
      'status': status,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }

  RoutineModel copyWith({
    String? id,
    String? batchId,
    String? teacherId,
    int? dayOfWeek,
    String? startTime,
    String? endTime,
    String? courseName,
    String? roomNumber,
    String? status,
    DateTime? createdAt,
    String? teacherName,
    int? batchNumber,
  }) {
    return RoutineModel(
      id: id ?? this.id,
      batchId: batchId ?? this.batchId,
      teacherId: teacherId ?? this.teacherId,
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      courseName: courseName ?? this.courseName,
      roomNumber: roomNumber ?? this.roomNumber,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      teacherName: teacherName ?? this.teacherName,
      batchNumber: batchNumber ?? this.batchNumber,
    );
  }
}
