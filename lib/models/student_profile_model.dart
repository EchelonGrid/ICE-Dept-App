class StudentProfileModel {
  final String userId;
  final String batchId;
  final bool isCr;
  final String studentIdRoll;
  final DateTime? createdAt;
  final String currentSemester; // e.g. '1-1', '3-1', '4-2'
  
  // Joined fields for UI convenience
  final String? userName;
  final String? userEmail;
  final int? batchNumber;

  StudentProfileModel({
    required this.userId,
    required this.batchId,
    this.isCr = false,
    required this.studentIdRoll,
    this.createdAt,
    this.currentSemester = '3-1',
    this.userName,
    this.userEmail,
    this.batchNumber,
  });

  factory StudentProfileModel.fromJson(Map<String, dynamic> json) {
    String? name;
    String? email;
    if (json['users'] != null && json['users'] is Map) {
      final u = json['users'] as Map;
      name = (u['full_name'] ?? u['name']) as String?;
      email = u['email'] as String?;
    }
    
    int? batchNum;
    if (json['batches'] != null && json['batches'] is Map) {
      final b = json['batches'] as Map;
      batchNum = (b['batch_number'] ?? b['number']) as int?;
    }

    final rawName = name ?? json['full_name'] ?? json['name'] ?? 'Unnamed Student';
    final rawRoll = json['student_id_roll'] ?? json['roll_number'] ?? json['roll'] ?? json['id'] ?? '-';
    final rawEmail = email ?? json['email'] ?? '';
    final rawIsCr = json['is_cr'] == true || json['role'] == 'CR';

    return StudentProfileModel(
      userId: (json['user_id'] ?? json['id'] ?? '') as String,
      batchId: (json['batch_id'] ?? json['batch'] ?? '') as String,
      isCr: rawIsCr,
      studentIdRoll: rawRoll.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      currentSemester: (json['current_semester'] ?? '3-1').toString(),
      userName: rawName.toString(),
      userEmail: rawEmail.toString(),
      batchNumber: batchNum ?? (json['batch_number'] as int?),
    );
  }

  StudentProfileModel copyWith({
    String? userId,
    String? batchId,
    bool? isCr,
    String? studentIdRoll,
    DateTime? createdAt,
    String? currentSemester,
    String? userName,
    String? userEmail,
    int? batchNumber,
  }) {
    return StudentProfileModel(
      userId: userId ?? this.userId,
      batchId: batchId ?? this.batchId,
      isCr: isCr ?? this.isCr,
      studentIdRoll: studentIdRoll ?? this.studentIdRoll,
      createdAt: createdAt ?? this.createdAt,
      currentSemester: currentSemester ?? this.currentSemester,
      userName: userName ?? this.userName,
      userEmail: userEmail ?? this.userEmail,
      batchNumber: batchNumber ?? this.batchNumber,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'user_id': userId,
      'batch_id': batchId,
      'is_cr': isCr,
      'student_id_roll': studentIdRoll,
      'current_semester': currentSemester,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}
