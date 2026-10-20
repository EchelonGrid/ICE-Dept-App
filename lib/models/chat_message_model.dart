enum ChatScope {
  batch,
  department,
  cr;

  static ChatScope fromString(String? value) {
    return switch (value?.toLowerCase()) {
      'department' || 'global' => ChatScope.department,
      'cr' => ChatScope.cr,
      _ => ChatScope.batch,
    };
  }

  String toDbValue() {
    return switch (this) {
      ChatScope.batch => 'batch',
      ChatScope.department => 'department',
      ChatScope.cr => 'cr',
    };
  }
}

class ChatMessageModel {
  final String id;
  final String? batchId;
  final String senderId;
  final String message;
  final String chatScope; // 'batch', 'department', 'cr'
  final bool isEdited;
  final Map<String, List<String>> reactions; // emoji -> list of user IDs
  final String? attachmentUrl;
  final String? attachmentName;
  final String? attachmentType; // 'image' or 'file'
  final String? replyToId;
  final String? replyToText;
  final String? replyToSender;
  final DateTime? createdAt;

  // Joined / Referenced fields
  final String? senderName;
  final String? senderRole;
  final bool isSenderCr;
  final String? referencedNoticeId;
  final String? referencedNoticeTitle;

  ChatMessageModel({
    required this.id,
    this.batchId,
    required this.senderId,
    required this.message,
    this.chatScope = 'batch',
    this.isEdited = false,
    this.reactions = const {},
    this.attachmentUrl,
    this.attachmentName,
    this.attachmentType,
    this.replyToId,
    this.replyToText,
    this.replyToSender,
    this.createdAt,
    this.senderName,
    this.senderRole,
    this.isSenderCr = false,
    this.referencedNoticeId,
    this.referencedNoticeTitle,
  });

  bool get isTeacher => senderRole == 'teacher';
  bool get isAdmin => senderRole == 'admin';
  bool get hasReferencedNotice => referencedNoticeTitle != null && referencedNoticeTitle!.isNotEmpty;
  bool get hasReply => replyToId != null && replyToId!.isNotEmpty;
  ChatScope get scopeEnum => ChatScope.fromString(chatScope);

  bool get hasAttachment => attachmentUrl != null && attachmentUrl!.isNotEmpty;
  bool get isImageAttachment => attachmentType == 'image';
  bool get isFileAttachment => attachmentType == 'file';

  bool hasReacted(String emoji, String? userId) {
    if (userId == null) return false;
    return reactions[emoji]?.contains(userId) ?? false;
  }

  int get totalReactionsCount =>
      reactions.values.fold(0, (sum, userList) => sum + userList.length);

  factory ChatMessageModel.fromJson(Map<String, dynamic> json) {
    String? sName;
    String? sRole;
    if (json['users'] != null && json['users'] is Map) {
      sName = json['users']['name']?.toString();
      sRole = json['users']['role']?.toString();
    }

    final Map<String, List<String>> parsedReactions = {};
    if (json['reactions'] != null && json['reactions'] is Map) {
      final rawReactions = json['reactions'] as Map;
      rawReactions.forEach((key, val) {
        if (val is List) {
          parsedReactions[key.toString()] = val.map((e) => e.toString()).toList();
        }
      });
    }

    return ChatMessageModel(
      id: json['id']?.toString() ?? '',
      batchId: json['batch_id']?.toString(),
      senderId: json['sender_id']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      chatScope: json['chat_scope']?.toString() ?? 'batch',
      isEdited: json['is_edited'] == true,
      reactions: parsedReactions,
      attachmentUrl: json['attachment_url']?.toString(),
      attachmentName: json['attachment_name']?.toString(),
      attachmentType: json['attachment_type']?.toString(),
      replyToId: json['reply_to_id']?.toString(),
      replyToText: json['reply_to_text']?.toString(),
      replyToSender: json['reply_to_sender']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString())
          : null,
      senderName: sName ?? json['sender_name']?.toString(),
      senderRole: sRole ?? json['sender_role']?.toString(),
      isSenderCr: json['is_cr'] == true,
      referencedNoticeId: json['referenced_notice_id']?.toString(),
      referencedNoticeTitle: json['referenced_notice_title']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      if (batchId != null) 'batch_id': batchId,
      'sender_id': senderId,
      'message': message,
      'chat_scope': chatScope,
      'is_edited': isEdited,
      'reactions': reactions,
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      if (attachmentName != null) 'attachment_name': attachmentName,
      if (attachmentType != null) 'attachment_type': attachmentType,
      if (replyToId != null) 'reply_to_id': replyToId,
      if (replyToText != null) 'reply_to_text': replyToText,
      if (replyToSender != null) 'reply_to_sender': replyToSender,
      if (senderName != null) 'sender_name': senderName,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (referencedNoticeId != null) 'referenced_notice_id': referencedNoticeId,
      if (referencedNoticeTitle != null) 'referenced_notice_title': referencedNoticeTitle,
    };
  }
}
