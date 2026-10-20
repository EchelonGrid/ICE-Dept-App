class DepartmentNoticeModel {
  final String id;
  final String title;
  final String content;
  final String? attachmentUrl;
  final String? attachmentName;
  final String targetBatch; // 'all', 'Batch 21', etc.
  final String priority; // 'normal', 'urgent'
  final bool isPinned;
  final String authorName;
  final DateTime createdAt;
  final DateTime? expiresAt; // null = never expires

  DepartmentNoticeModel({
    required this.id,
    required this.title,
    required this.content,
    this.attachmentUrl,
    this.attachmentName,
    this.targetBatch = 'all',
    this.priority = 'normal',
    this.isPinned = false,
    this.authorName = 'Department Office',
    required this.createdAt,
    this.expiresAt,
  });

  bool get isUrgent => priority.toLowerCase() == 'urgent' || isPinned;
  bool get isExpired => expiresAt != null && expiresAt!.isBefore(DateTime.now());
  bool get isPermanent => expiresAt == null;

  String get expiryCountdownText {
    if (expiresAt == null) return 'Permanent Notice';
    final now = DateTime.now();
    final diff = expiresAt!.difference(now);
    if (diff.isNegative) return 'Expired';
    if (diff.inDays > 0) return '⏳ Expires in ${diff.inDays} day${diff.inDays == 1 ? '' : 's'}';
    if (diff.inHours > 0) return '⏳ Expires in ${diff.inHours} hour${diff.inHours == 1 ? '' : 's'}';
    if (diff.inMinutes > 0) return '⏳ Expires in ${diff.inMinutes} min${diff.inMinutes == 1 ? '' : 's'}';
    return '⏳ Expiring soon';
  }

  factory DepartmentNoticeModel.fromJson(Map<String, dynamic> json) {
    return DepartmentNoticeModel(
      id: (json['id'] ?? '').toString(),
      title: (json['title'] ?? '').toString(),
      content: (json['content'] ?? '').toString(),
      attachmentUrl: json['attachment_url'] as String?,
      attachmentName: json['attachment_name'] as String?,
      targetBatch: (json['target_batch'] ?? 'all').toString(),
      priority: (json['priority'] ?? 'normal').toString(),
      isPinned: json['is_pinned'] == true,
      authorName: (json['author_name'] ?? 'Department Office').toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'].toString())
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'attachment_url': attachmentUrl,
      'attachment_name': attachmentName,
      'target_batch': targetBatch,
      'priority': priority,
      'is_pinned': isPinned,
      'author_name': authorName,
      'created_at': createdAt.toIso8601String(),
      if (expiresAt != null) 'expires_at': expiresAt!.toIso8601String(),
    };
  }

  DepartmentNoticeModel copyWith({
    String? id,
    String? title,
    String? content,
    String? attachmentUrl,
    String? attachmentName,
    String? targetBatch,
    String? priority,
    bool? isPinned,
    String? authorName,
    DateTime? createdAt,
    DateTime? expiresAt,
  }) {
    return DepartmentNoticeModel(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      attachmentUrl: attachmentUrl ?? this.attachmentUrl,
      attachmentName: attachmentName ?? this.attachmentName,
      targetBatch: targetBatch ?? this.targetBatch,
      priority: priority ?? this.priority,
      isPinned: isPinned ?? this.isPinned,
      authorName: authorName ?? this.authorName,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }
}
