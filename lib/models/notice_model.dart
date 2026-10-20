class NoticeModel {
  final String id;
  final String authorId;
  final String? batchId; // Nullable for department-wide notices
  final String title;
  final String content;
  final bool isCrNotice;
  final DateTime? createdAt;

  // Joined fields
  final String? authorName;
  final String? authorRole;
  final int? batchNumber;

  NoticeModel({
    required this.id,
    required this.authorId,
    this.batchId,
    required this.title,
    required this.content,
    this.isCrNotice = false,
    this.createdAt,
    this.authorName,
    this.authorRole,
    this.batchNumber,
  });

  bool get isDepartmentWide => batchId == null;

  factory NoticeModel.fromJson(Map<String, dynamic> json) {
    String? aName;
    String? aRole;
    if (json['users'] != null && json['users'] is Map) {
      aName = json['users']['name'] as String?;
      aRole = json['users']['role'] as String?;
    }

    int? bNum;
    if (json['batches'] != null && json['batches'] is Map) {
      bNum = json['batches']['batch_number'] as int?;
    }

    return NoticeModel(
      id: json['id'] as String,
      authorId: json['author_id'] as String,
      batchId: json['batch_id'] as String?,
      title: json['title'] as String? ?? '',
      content: json['content'] as String? ?? '',
      isCrNotice: json['is_cr_notice'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      authorName: aName ?? json['author_name'] as String?,
      authorRole: aRole ?? json['author_role'] as String?,
      batchNumber: bNum ?? json['batch_number'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'author_id': authorId,
      'batch_id': batchId,
      'title': title,
      'content': content,
      'is_cr_notice': isCrNotice,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
    };
  }
}
