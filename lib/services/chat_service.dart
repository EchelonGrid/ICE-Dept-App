import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_message_model.dart';
import 'supabase_service.dart';

class ChatService {
  SupabaseClient get _client => SupabaseService.instance.client;

  /// Fetch messages with sender details based on chat scope
  Future<List<ChatMessageModel>> getMessages({
    String? batchId,
    ChatScope scope = ChatScope.batch,
  }) async {
    try {
      var query = _client.from('common_chat').select('*, users(name, role)');

      switch (scope) {
        case ChatScope.batch:
          if (batchId != null) {
            query = query.eq('batch_id', batchId);
          }
          break;
        case ChatScope.department:
          query = query.eq('chat_scope', 'department');
          break;
        case ChatScope.cr:
          query = query.eq('chat_scope', 'cr');
          break;
      }

      final response = await query.order('created_at', ascending: true);
      return (response as List).map((json) => ChatMessageModel.fromJson(json as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('getMessages query fallback error: $e');
      try {
        // Fallback: raw select without join if users relation is missing in select
        final fallbackResponse = await _client.from('common_chat').select().order('created_at', ascending: true);
        return (fallbackResponse as List).map((json) => ChatMessageModel.fromJson(json as Map<String, dynamic>)).toList();
      } catch (e2) {
        debugPrint('getMessages raw fallback error: $e2');
        return [];
      }
    }
  }

  /// Upload an attachment (image or file) to Supabase Storage bucket 'chat_attachments'
  Future<Map<String, String>> uploadAttachment({
    required Uint8List bytes,
    required String fileName,
    required String fileType, // 'image' or 'file'
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to upload attachments.');
    }

    final sanitizedName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storagePath = '${user.id}/${DateTime.now().millisecondsSinceEpoch}_$sanitizedName';

    debugPrint('Uploading chat attachment to storage path: $storagePath');

    await _client.storage.from('chat_attachments').uploadBinary(
      storagePath,
      bytes,
      fileOptions: const FileOptions(cacheControl: '3600', upsert: false),
    );

    final publicUrl = _client.storage.from('chat_attachments').getPublicUrl(storagePath);
    debugPrint('Chat attachment uploaded successfully. Public URL: $publicUrl');

    return {
      'url': publicUrl,
      'name': fileName,
      'type': fileType,
    };
  }

  /// Post a new chat message to the designated chat scope with optional attachments
  Future<void> sendMessage({
    String? batchId,
    required String message,
    ChatScope scope = ChatScope.batch,
    String? senderName,
    String? referencedNoticeId,
    String? referencedNoticeTitle,
    String? attachmentUrl,
    String? attachmentName,
    String? attachmentType,
    String? replyToId,
    String? replyToText,
    String? replyToSender,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw Exception('User must be authenticated to send messages.');
    }

    final resolvedSenderName = senderName ??
        user.userMetadata?['name'] as String? ??
        user.email?.split('@').first ??
        'Student';

    final payload = {
      if (batchId != null && scope == ChatScope.batch) 'batch_id': batchId,
      'sender_id': user.id,
      'sender_name': resolvedSenderName,
      'message': message.trim(),
      'chat_scope': scope.toDbValue(),
      'is_edited': false,
      'reactions': {},
      if (referencedNoticeId != null) 'referenced_notice_id': referencedNoticeId,
      if (referencedNoticeTitle != null) 'referenced_notice_title': referencedNoticeTitle,
      if (attachmentUrl != null) 'attachment_url': attachmentUrl,
      if (attachmentName != null) 'attachment_name': attachmentName,
      if (attachmentType != null) 'attachment_type': attachmentType,
      if (replyToId != null) 'reply_to_id': replyToId,
      if (replyToText != null) 'reply_to_text': replyToText,
      if (replyToSender != null) 'reply_to_sender': replyToSender,
    };

    debugPrint('Executing common_chat insert payload: $payload');
    await _client.from('common_chat').insert(payload);
  }

  /// Update an existing chat message text
  Future<void> editMessage(String messageId, String newText) async {
    debugPrint('Editing message $messageId: "$newText"');
    await _client.from('common_chat').update({
      'message': newText.trim(),
      'is_edited': true,
    }).eq('id', messageId);
  }

  /// Delete an existing chat message
  Future<void> deleteMessage(String messageId) async {
    debugPrint('Deleting message $messageId');
    await _client.from('common_chat').delete().eq('id', messageId);
  }

  /// Toggle an emoji reaction for the current user
  Future<void> toggleReaction(String messageId, String emoji) async {
    final user = _client.auth.currentUser;
    if (user == null) return;
    final userId = user.id;

    try {
      final row = await _client.from('common_chat').select('reactions').eq('id', messageId).maybeSingle();
      final Map<String, dynamic> currentReactions = {};
      if (row != null && row['reactions'] != null && row['reactions'] is Map) {
        currentReactions.addAll(Map<String, dynamic>.from(row['reactions'] as Map));
      }

      final List<dynamic> userList = List<dynamic>.from(currentReactions[emoji] as List? ?? []);
      if (userList.contains(userId)) {
        userList.remove(userId);
      } else {
        userList.add(userId);
      }

      if (userList.isEmpty) {
        currentReactions.remove(emoji);
      } else {
        currentReactions[emoji] = userList;
      }

      debugPrint('Updating reactions for $messageId: $currentReactions');
      await _client.from('common_chat').update({
        'reactions': currentReactions,
      }).eq('id', messageId);
    } catch (e) {
      debugPrint('Error toggling reaction: $e');
      rethrow;
    }
  }

  /// Stream messages in realtime using Supabase Realtime channel
  Stream<List<Map<String, dynamic>>> streamMessages() {
    return _client
        .from('common_chat')
        .stream(primaryKey: ['id'])
        .order('created_at', ascending: true);
  }
}
