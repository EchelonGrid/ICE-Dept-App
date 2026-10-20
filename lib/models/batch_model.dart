class BatchModel {
  final String id;
  final int batchNumber;
  final String? name;
  final String? code;
  final String status; // 'active', 'graduated', 'ACTIVE', 'GRADUATED'
  final String currentSemester; // e.g. '1-1', '2-1', '4-2', 'Graduated'
  final DateTime? semesterStartDate;
  final DateTime? createdAt;

  BatchModel({
    required this.id,
    required this.batchNumber,
    this.name,
    this.code,
    this.status = 'active',
    this.currentSemester = '1-1',
    this.semesterStartDate,
    this.createdAt,
  });

  bool get isActive =>
      status.toLowerCase() == 'active' && currentSemester.toLowerCase() != 'graduated';

  bool get isGraduated =>
      status.toLowerCase() == 'graduated' || currentSemester.toLowerCase() == 'graduated';

  factory BatchModel.fromJson(Map<String, dynamic> json) {
    DateTime? startDate;
    if (json['semester_start_date'] != null) {
      startDate = DateTime.tryParse(json['semester_start_date'].toString());
    }

    return BatchModel(
      id: json['id'] as String,
      batchNumber: json['batch_number'] as int? ?? 0,
      name: json['name'] as String?,
      code: json['code'] as String?,
      status: json['status'] as String? ?? 'active',
      currentSemester: json['current_semester'] as String? ?? '1-1',
      semesterStartDate: startDate,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'batch_number': batchNumber,
      if (name != null) 'name': name,
      if (code != null) 'code': code,
      'status': status,
      'current_semester': currentSemester,
      if (semesterStartDate != null)
        'semester_start_date':
            '${semesterStartDate!.year.toString().padLeft(4, '0')}-${semesterStartDate!.month.toString().padLeft(2, '0')}-${semesterStartDate!.day.toString().padLeft(2, '0')}',
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}
