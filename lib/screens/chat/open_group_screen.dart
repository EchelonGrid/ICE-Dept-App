import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:any_link_preview/any_link_preview.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:swipe_to/swipe_to.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_time_helper.dart';
import '../../models/chat_message_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/chat_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/empty_state_view.dart';
import 'reaction_menu.dart';

class OpenGroupScreen extends StatefulWidget {
  final ChatScope scope;
  final String? initialReferencedNoticeId;
  final String? initialReferencedNoticeTitle;
  final String? initialDraftText;

  const OpenGroupScreen({
    super.key,
    this.scope = ChatScope.batch,
    this.initialReferencedNoticeId,
    this.initialReferencedNoticeTitle,
    this.initialDraftText,
  });

  @override
  State<OpenGroupScreen> createState() => _OpenGroupScreenState();
}

class _OpenGroupScreenState extends State<OpenGroupScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final FocusNode _messageFocusNode = FocusNode();

  String? _batchId;
  String? _referencedNoticeId;
  String? _referencedNoticeTitle;
  late Stream<List<Map<String, dynamic>>> _chatStream;

  // Telegram-style swipe reply context state
  String? _replyToId;
  String? _replyToText;
  String? _replyToSender;

  // Attachment draft state
  PlatformFile? _selectedFile;
  Uint8List? _selectedFileBytes;
  String? _selectedFileType; // 'image' or 'file'
  bool _isUploadingAttachment = false;

  // Local memory cache for resolving sender names by senderId
  final Map<String, String> _senderNamesCache = {};

  @override
  void initState() {
    super.initState();
    _referencedNoticeId = widget.initialReferencedNoticeId;
    _referencedNoticeTitle = widget.initialReferencedNoticeTitle;

    // Pre-fill shared draft text if provided from native share intent
    if (widget.initialDraftText != null && widget.initialDraftText!.isNotEmpty) {
      _messageController.text = widget.initialDraftText!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _messageFocusNode.requestFocus();
      });
    }

    // Initialize raw realtime stream
    _chatStream = _chatService.streamMessages();

    if (_referencedNoticeTitle != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _messageFocusNode.requestFocus();
      });
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final authService = Provider.of<AuthService>(context, listen: false);
    _batchId = authService.studentProfile?.batchId;
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _messageFocusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _cancelReply() {
    setState(() {
      _replyToId = null;
      _replyToText = null;
      _replyToSender = null;
      _referencedNoticeId = null;
      _referencedNoticeTitle = null;
    });
  }

  void _cancelAttachment() {
    setState(() {
      _selectedFile = null;
      _selectedFileBytes = null;
      _selectedFileType = null;
    });
  }

  // Trigger reply context from swipe or action menu
  void _initiateReply(ChatMessageModel msg, String senderDisplayName) {
    HapticFeedback.lightImpact();
    setState(() {
      _replyToId = msg.id;
      _replyToText = msg.message.isNotEmpty
          ? msg.message
          : (msg.attachmentName != null ? '📎 ${msg.attachmentName}' : 'Attachment');
      _replyToSender = senderDisplayName;
      _referencedNoticeId = null;
      _referencedNoticeTitle = null;
    });
    _messageFocusNode.requestFocus();
  }

  // Helper regex to extract URLs from message string
  String? _extractUrl(String text) {
    final urlRegExp = RegExp(
      r'(https?:\/\/[^\s]+)',
      caseSensitive: false,
    );
    final match = urlRegExp.firstMatch(text);
    return match?.group(0);
  }

  // Resolve sender name dynamically with local memory cache
  Future<void> _fetchSenderNameIfNeeded(String senderId) async {
    if (_senderNamesCache.containsKey(senderId)) return;

    try {
      final res = await SupabaseService.instance.client
          .from('users')
          .select('name')
          .eq('id', senderId)
          .maybeSingle();

      if (res != null && res['name'] != null && mounted) {
        setState(() {
          _senderNamesCache[senderId] = res['name'] as String;
        });
      }
    } catch (_) {}
  }

  // Pick image via ImagePicker
  Future<void> _pickImage(ImageSource source) async {
    Navigator.pop(context); // Close picker sheet
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(source: source, imageQuality: 85);
      if (picked != null) {
        final bytes = await picked.readAsBytes();
        setState(() {
          _selectedFileBytes = bytes;
          _selectedFile = PlatformFile(name: picked.name, size: bytes.length, bytes: bytes);
          _selectedFileType = 'image';
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick image: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  // Pick Document or File via FilePicker
  Future<void> _pickDocument() async {
    Navigator.pop(context); // Close picker sheet
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf', 'docx', 'doc', 'txt', 'xlsx', 'zip', 'png', 'jpg', 'jpeg'],
        withData: true,
      );

      if (result != null && result.files.isNotEmpty) {
        final file = result.files.first;
        final ext = file.extension?.toLowerCase() ?? '';
        final isImage = ['png', 'jpg', 'jpeg', 'webp', 'gif'].contains(ext);

        Uint8List? bytes = file.bytes;
        if (bytes == null && !kIsWeb && file.path != null) {
          bytes = await File(file.path!).readAsBytes();
        }

        if (bytes != null) {
          setState(() {
            _selectedFileBytes = bytes;
            _selectedFile = file;
            _selectedFileType = isImage ? 'image' : 'file';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to pick file: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  // Attachment Modal Sheet
  void _showAttachmentPickerSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Share Attachment',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildAttachmentOption(
                      icon: Icons.photo_library_outlined,
                      label: 'Gallery',
                      color: const Color(0xFF38BDF8),
                      onTap: () => _pickImage(ImageSource.gallery),
                    ),
                    _buildAttachmentOption(
                      icon: Icons.camera_alt_outlined,
                      label: 'Camera',
                      color: const Color(0xFF34D399),
                      onTap: () => _pickImage(ImageSource.camera),
                    ),
                    _buildAttachmentOption(
                      icon: Icons.description_outlined,
                      label: 'Document',
                      color: const Color(0xFFF59E0B),
                      onTap: _pickDocument,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAttachmentOption({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: color.withValues(alpha: 0.2),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleSendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _selectedFile == null) return;

    final targetNoticeId = _referencedNoticeId;
    final targetNoticeTitle = _referencedNoticeTitle;
    final replyId = _replyToId;
    final replyText = _replyToText;
    final replySender = _replyToSender;

    final fileToUpload = _selectedFile;
    final fileBytes = _selectedFileBytes;
    final fileType = _selectedFileType;

    _messageController.clear();
    setState(() {
      _referencedNoticeId = null;
      _referencedNoticeTitle = null;
      _replyToId = null;
      _replyToText = null;
      _replyToSender = null;
      _selectedFile = null;
      _selectedFileBytes = null;
      _selectedFileType = null;
    });

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final effectiveBatchId = _batchId ?? authService.studentProfile?.batchId ?? 'cba1ba2e-d3ae-49c6-9d35-ae5753a224dc';
      final myName = authService.currentUser?.name;

      String? uploadedUrl;
      String? uploadedName;
      String? uploadedType;

      // Handle file upload if an attachment was selected
      if (fileToUpload != null && fileBytes != null && fileType != null) {
        setState(() => _isUploadingAttachment = true);
        final uploadResult = await _chatService.uploadAttachment(
          bytes: fileBytes,
          fileName: fileToUpload.name,
          fileType: fileType,
        );
        uploadedUrl = uploadResult['url'];
        uploadedName = uploadResult['name'];
        uploadedType = uploadResult['type'];
        setState(() => _isUploadingAttachment = false);
      }

      debugPrint('Attempting to send message: "$text" (scope: ${widget.scope.toDbValue()}, batch: $effectiveBatchId)');
      await _chatService.sendMessage(
        batchId: effectiveBatchId,
        scope: widget.scope,
        message: text,
        senderName: myName,
        referencedNoticeId: targetNoticeId,
        referencedNoticeTitle: targetNoticeTitle,
        attachmentUrl: uploadedUrl,
        attachmentName: uploadedName,
        attachmentType: uploadedType,
        replyToId: replyId,
        replyToText: replyText,
        replyToSender: replySender,
      );
      debugPrint('Message inserted successfully.');
      _scrollToBottom();
    } catch (e, stackTrace) {
      setState(() => _isUploadingAttachment = false);
      debugPrint('INSERT ERROR: $e');
      debugPrint('STACK TRACE: $stackTrace');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  // Action Menu: Reaction Menu & Options
  void _openReactionAndActionMenu(ChatMessageModel msg, bool isMe, bool isAdmin, String? currentUserId, String senderDisplayName) {
    ReactionMenu.show(
      context: context,
      message: msg,
      isMe: isMe,
      isAdmin: isAdmin,
      currentUserId: currentUserId,
      onReactionSelected: (emoji) async {
        try {
          await _chatService.toggleReaction(msg.id, emoji);
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Reaction failed: $e'), backgroundColor: AppTheme.error),
            );
          }
        }
      },
      onReplyPressed: () => _initiateReply(msg, senderDisplayName),
      onEditPressed: () => _showEditMessageDialog(msg),
      onDeletePressed: () => _confirmDeleteMessage(msg),
    );
  }

  // Dialog to Edit Message In-Place
  void _showEditMessageDialog(ChatMessageModel msg) {
    final editController = TextEditingController(text: msg.message);

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.edit_outlined, color: Color(0xFF38BDF8), size: 20),
              SizedBox(width: 8),
              Text('Edit Message', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
          content: TextField(
            controller: editController,
            autofocus: true,
            maxLines: 3,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Edit your message...',
              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
              fillColor: const Color(0xFF0F172A),
              filled: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFF334155)),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0284C7),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                final newText = editController.text.trim();
                if (newText.isEmpty || newText == msg.message) {
                  Navigator.pop(ctx);
                  return;
                }

                Navigator.pop(ctx);
                try {
                  await _chatService.editMessage(msg.id, newText);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message updated.')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to edit: $e'), backgroundColor: AppTheme.error),
                    );
                  }
                }
              },
              child: const Text('Save Changes'),
            ),
          ],
        );
      },
    );
  }

  // Delete Confirmation Dialog
  void _confirmDeleteMessage(ChatMessageModel msg) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Delete Message?', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
          content: const Text(
            'This message will be permanently removed from the group feed.',
            style: TextStyle(color: Color(0xFFCBD5E1), fontSize: 13),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF94A3B8))),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFEF4444),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  await _chatService.deleteMessage(msg.id);
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message deleted.')),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed to delete: $e'), backgroundColor: AppTheme.error),
                    );
                  }
                }
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final currentUserId = authService.currentUser?.id;
    final isAdmin = authService.currentUser?.role == UserRole.admin;
    final batchNum = authService.studentProfile?.batchNumber ?? 21;

    final (String screenTitle, String subtitle, IconData scopeIcon, Color themeAccent, String infoNotice) =
        switch (widget.scope) {
      ChatScope.batch => (
          'Batch $batchNum Open Group',
          '24h Ephemeral Open Discussion',
          Icons.auto_delete,
          const Color(0xFF34D399),
          'Open Group messages auto-purge after 24 hours.',
        ),
      ChatScope.department => (
          'Department Open Group',
          '24h Ephemeral Global Department Discussion',
          Icons.public,
          const Color(0xFF38BDF8),
          'Global department messages auto-purge after 24 hours.',
        ),
      ChatScope.cr => (
          'CR Info & Council Group',
          '7-Day Ephemeral CR & Department Council',
          Icons.verified_user,
          const Color(0xFFF59E0B),
          'CR Council messages auto-purge after 1 week (7 days).',
        ),
    };

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0F172A),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              screenTitle,
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white),
            ),
            Row(
              children: [
                Icon(scopeIcon, size: 12, color: themeAccent),
                const SizedBox(width: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 10.5, color: themeAccent, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF94A3B8)),
            tooltip: 'Refresh Stream',
            onPressed: () {
              setState(() {
                _chatStream = _chatService.streamMessages();
              });
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Scope Ephemeral Info Bar
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            color: const Color(0xFF1E293B),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.auto_delete_outlined, size: 13, color: themeAccent),
                const SizedBox(width: 6),
                Text(
                  infoNotice,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),

          // Uploading Linear Progress Bar
          if (_isUploadingAttachment)
            LinearProgressIndicator(color: themeAccent, backgroundColor: const Color(0xFF1E293B)),

          // Messages StreamBuilder wrapped in Expanded to ensure layout constraints
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _chatStream,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
                  return Center(child: CircularProgressIndicator(color: themeAccent));
                }

                final rawDocs = snapshot.data ?? [];
                final List<ChatMessageModel> filteredMessages = [];

                for (final doc in rawDocs) {
                  try {
                    final item = ChatMessageModel.fromJson(doc);

                    // Fetch sender name dynamically if missing
                    if (item.senderName == null || item.senderName!.isEmpty) {
                      _fetchSenderNameIfNeeded(item.senderId);
                    }

                    // Robust scope filtering
                    if (widget.scope == ChatScope.department) {
                      if (item.chatScope == 'department') {
                        filteredMessages.add(item);
                      }
                    } else if (widget.scope == ChatScope.cr) {
                      if (item.chatScope == 'cr') {
                        filteredMessages.add(item);
                      }
                    } else {
                      // batch scope: match batch_id or default batch scope or own messages
                      if (item.chatScope == 'batch' || (item.batchId != null && item.batchId == _batchId) || item.chatScope.isEmpty || item.senderId == currentUserId) {
                        filteredMessages.add(item);
                      }
                    }
                  } catch (_) {}
                }

                if (filteredMessages.isEmpty) {
                  return EmptyStateView(
                    icon: Icons.forum_outlined,
                    title: 'No Messages Yet',
                    description: widget.scope == ChatScope.cr
                        ? 'CR and Council messages for the upcoming week will appear here.'
                        : widget.scope == ChatScope.department
                            ? 'Global department discussions and announcements appear here.'
                            : 'Say hello to your batchmates or discuss exam topics!',
                  );
                }

                WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  itemCount: filteredMessages.length,
                  itemBuilder: (context, index) {
                    final msg = filteredMessages[index];
                    final isMe = msg.senderId == currentUserId;
                    final resolvedName = msg.senderName ?? _senderNamesCache[msg.senderId] ?? (isMe ? 'You' : 'Student');

                    // Wrap in Telegram-style SwipeTo reply gesture
                    return SwipeTo(
                      iconOnRightSwipe: Icons.reply,
                      iconColor: const Color(0xFF38BDF8),
                      onRightSwipe: (details) => _initiateReply(msg, resolvedName),
                      child: _buildMessageBubble(msg, isMe, isAdmin, currentUserId, resolvedName, themeAccent),
                    );
                  },
                );
              },
            ),
          ),

          // Telegram-Style Quoted Reply Preview Banner above input field
          if (_replyToId != null)
            _buildQuotedReplyPreviewBanner()
          else if (_referencedNoticeTitle != null)
            _buildReferencedNoticeReplyBanner(),

          // Attachment Selected Draft Preview Banner
          if (_selectedFile != null) _buildAttachmentDraftBanner(),

          // Message Input Field
          _buildMessageInputField(themeAccent),
        ],
      ),
    );
  }

  // Telegram-style swipe reply preview banner above input field
  Widget _buildQuotedReplyPreviewBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(
          top: BorderSide(color: Color(0xFF334155)),
          left: BorderSide(color: Color(0xFF38BDF8), width: 3.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.reply, size: 18, color: Color(0xFF38BDF8)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Replying to ${_replyToSender ?? "Message"}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                ),
                const SizedBox(height: 2),
                Text(
                  _replyToText ?? '',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: Color(0xFF94A3B8)),
            onPressed: _cancelReply,
            tooltip: 'Cancel Reply',
          ),
        ],
      ),
    );
  }

  // Quoted Notice Reply Banner above input field
  Widget _buildReferencedNoticeReplyBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(
          top: BorderSide(color: Color(0xFF334155)),
          left: BorderSide(color: Color(0xFF38BDF8), width: 3.5),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.campaign_outlined, size: 16, color: Color(0xFF38BDF8)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Replying to Notice:',
                  style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF38BDF8)),
                ),
                const SizedBox(height: 2),
                Text(
                  _referencedNoticeTitle!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: Color(0xFF94A3B8)),
            onPressed: _cancelReply,
            tooltip: 'Cancel Reply',
          ),
        ],
      ),
    );
  }

  // Selected Attachment Draft Preview Banner
  Widget _buildAttachmentDraftBanner() {
    final isImg = _selectedFileType == 'image';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(
          top: BorderSide(color: Color(0xFF334155)),
          left: BorderSide(color: Color(0xFF34D399), width: 3.5),
        ),
      ),
      child: Row(
        children: [
          if (isImg && _selectedFileBytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.memory(
                _selectedFileBytes!,
                width: 38,
                height: 38,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.insert_drive_file, color: Color(0xFF34D399), size: 20),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isImg ? 'Attached Photo' : 'Attached Document',
                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.bold, color: Color(0xFF34D399)),
                ),
                const SizedBox(height: 2),
                Text(
                  _selectedFile!.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 16, color: Color(0xFF94A3B8)),
            onPressed: _cancelAttachment,
            tooltip: 'Remove Attachment',
          ),
        ],
      ),
    );
  }

  // Rich URL Link Preview Widget
  Widget _buildLinkPreview(String url) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 4),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: AnyLinkPreview(
        link: url,
        displayDirection: UIDirection.uiDirectionVertical,
        showMultimedia: true,
        bodyMaxLines: 2,
        bodyTextOverflow: TextOverflow.ellipsis,
        titleStyle: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12.5,
        ),
        bodyStyle: const TextStyle(
          color: Color(0xFF94A3B8),
          fontSize: 11,
        ),
        errorWidget: Container(
          padding: const EdgeInsets.all(8),
          color: const Color(0xFF0F172A),
          child: Row(
            children: [
              const Icon(Icons.link, size: 14, color: Color(0xFF38BDF8)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  url,
                  style: const TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 11,
                    decoration: TextDecoration.underline,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
        placeholderWidget: Container(
          height: 100,
          color: const Color(0xFF0F172A),
          child: const Center(
            child: SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
            ),
          ),
        ),
        backgroundColor: const Color(0xFF0F172A),
        borderRadius: 12,
      ),
    );
  }

  // Image Attachment Preview Card in Bubble
  Widget _buildImageAttachmentCard(String url) {
    return Container(
      margin: const EdgeInsets.only(top: 6, bottom: 4),
      constraints: const BoxConstraints(maxHeight: 260),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF334155)),
      ),
      child: GestureDetector(
        onTap: () {
          // Open full-screen image viewer dialog
          showDialog(
            context: context,
            builder: (_) => Dialog(
              backgroundColor: Colors.transparent,
              insetPadding: const EdgeInsets.all(12),
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  InteractiveViewer(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.network(url, fit: BoxFit.contain),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white, size: 28),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
          );
        },
        child: Image.network(
          url,
          fit: BoxFit.cover,
          width: double.infinity,
          loadingBuilder: (ctx, child, progress) {
            if (progress == null) return child;
            return Container(
              height: 180,
              color: const Color(0xFF0F172A),
              child: const Center(
                child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF38BDF8)),
              ),
            );
          },
          errorBuilder: (_, __, ___) => Container(
            height: 120,
            color: const Color(0xFF0F172A),
            child: const Center(
              child: Icon(Icons.broken_image, color: Color(0xFF94A3B8), size: 36),
            ),
          ),
        ),
      ),
    );
  }

  // Document File Attachment Preview Card in Bubble
  Widget _buildFileAttachmentCard(String url, String? name) {
    final fileName = name ?? 'Document File';
    final isPdf = fileName.toLowerCase().endsWith('.pdf');

    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Could not open file URL.')),
            );
          }
        }
      },
      child: Container(
        margin: const EdgeInsets.only(top: 6, bottom: 4),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFF334155)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: isPdf
                    ? const Color(0xFFEF4444).withValues(alpha: 0.2)
                    : const Color(0xFF38BDF8).withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                isPdf ? Icons.picture_as_pdf : Icons.insert_drive_file,
                color: isPdf ? const Color(0xFFEF4444) : const Color(0xFF38BDF8),
                size: 22,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    'Tap to view / download file',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 10),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.download, color: Color(0xFF38BDF8), size: 18),
          ],
        ),
      ),
    );
  }

  // Message Bubble with Sender Avatar, Name Header, Attachments, Link Previews, Reactions, and Actions
  Widget _buildMessageBubble(
    ChatMessageModel msg,
    bool isMe,
    bool isAdmin,
    String? currentUserId,
    String senderDisplayName,
    Color accentColor,
  ) {
    final initialLetter = senderDisplayName.isNotEmpty ? senderDisplayName[0].toUpperCase() : 'S';
    final detectedUrl = _extractUrl(msg.message);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          // Sender Header Row with Avatar & Name (for incoming messages)
          if (!isMe)
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 9,
                    backgroundColor: const Color(0xFF334155),
                    child: Text(
                      initialLetter,
                      style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    senderDisplayName,
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11.5, color: accentColor),
                  ),
                  if (msg.isSenderCr) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF59E0B).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('CR', style: TextStyle(color: Color(0xFFF59E0B), fontSize: 8.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                  if (msg.isAdmin) ...[
                    const SizedBox(width: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF60A5FA).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text('OFFICE', style: TextStyle(color: Color(0xFF60A5FA), fontSize: 8.5, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ],
              ),
            ),

          // Tappable & Long-Pressable Message Container
          GestureDetector(
            onLongPress: () => _openReactionAndActionMenu(msg, isMe, isAdmin, currentUserId, senderDisplayName),
            child: Container(
              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.80),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe ? const Color(0xFF0284C7) : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16).copyWith(
                  bottomRight: isMe ? const Radius.circular(2) : const Radius.circular(16),
                  bottomLeft: !isMe ? const Radius.circular(2) : const Radius.circular(16),
                ),
                border: isMe ? null : Border.all(color: const Color(0xFF334155)),
              ),
              child: Column(
                crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [
                  // 1. Quoted Swipe-to-Reply Context Banner
                  if (msg.hasReply) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isMe
                            ? Colors.white.withValues(alpha: 0.15)
                            : const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(
                          left: BorderSide(
                            color: isMe ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                            width: 3.0,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.reply,
                                size: 12,
                                color: Color(0xFF38BDF8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                msg.replyToSender ?? 'Replying to message',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: isMe ? Colors.white70 : const Color(0xFF38BDF8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            msg.replyToText ?? '',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ]
                  // 2. Quoted Notice Thread Banner (if referencing a department notice)
                  else if (msg.hasReferencedNotice) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 6),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: isMe
                            ? Colors.white.withValues(alpha: 0.15)
                            : const Color(0xFF0F172A),
                        borderRadius: BorderRadius.circular(8),
                        border: Border(
                          left: BorderSide(
                            color: isMe ? const Color(0xFF38BDF8) : const Color(0xFF0284C7),
                            width: 3.0,
                          ),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.campaign_outlined,
                                size: 12,
                                color: Color(0xFF38BDF8),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'Thread / Reply',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.bold,
                                  color: isMe ? Colors.white70 : const Color(0xFF38BDF8),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            msg.referencedNoticeTitle!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  // 3. Image Attachment (if present)
                  if (msg.isImageAttachment && msg.attachmentUrl != null)
                    _buildImageAttachmentCard(msg.attachmentUrl!),

                  // 4. File Attachment (if present)
                  if (msg.isFileAttachment && msg.attachmentUrl != null)
                    _buildFileAttachmentCard(msg.attachmentUrl!, msg.attachmentName),

                  // 5. Message Text Content
                  if (msg.message.isNotEmpty) ...[
                    Text(
                      msg.message,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13.5,
                        height: 1.4,
                      ),
                    ),
                  ],

                  // 6. Rich Link Preview if a URL is detected
                  if (detectedUrl != null)
                    _buildLinkPreview(detectedUrl),

                  const SizedBox(height: 4),

                  // Bottom Info Row: Timestamp + (edited) indicator
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (msg.createdAt != null)
                        Text(
                          DateTimeHelper.formatRelativeTime(msg.createdAt!),
                          style: TextStyle(
                            fontSize: 9.5,
                            color: isMe ? Colors.white.withValues(alpha: 0.75) : const Color(0xFF94A3B8),
                          ),
                        ),
                      if (msg.isEdited) ...[
                        const SizedBox(width: 4),
                        Text(
                          '• (edited)',
                          style: TextStyle(
                            fontSize: 9.5,
                            fontStyle: FontStyle.italic,
                            color: isMe ? Colors.white.withValues(alpha: 0.75) : const Color(0xFF94A3B8),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Floating Reaction Badges Container
          _buildReactionsBadgeRow(msg, isMe, currentUserId),
        ],
      ),
    );
  }

  // Floating Reaction Badges attached to bubble
  Widget _buildReactionsBadgeRow(ChatMessageModel msg, bool isMe, String? currentUserId) {
    if (msg.reactions.isEmpty) return const SizedBox.shrink();

    final activeEntries = msg.reactions.entries.where((e) => e.value.isNotEmpty).toList();
    if (activeEntries.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Wrap(
        spacing: 4,
        runSpacing: 2,
        alignment: isMe ? WrapAlignment.end : WrapAlignment.start,
        children: activeEntries.map((entry) {
          final emoji = entry.key;
          final userList = entry.value;
          final count = userList.length;
          final hasReacted = currentUserId != null && userList.contains(currentUserId);

          return GestureDetector(
            onTap: () {
              HapticFeedback.lightImpact();
              _chatService.toggleReaction(msg.id, emoji);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: hasReacted
                    ? const Color(0xFF0284C7).withValues(alpha: 0.3)
                    : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: hasReacted ? const Color(0xFF38BDF8) : const Color(0xFF334155),
                  width: hasReacted ? 1.2 : 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 12)),
                  if (count > 1) ...[
                    const SizedBox(width: 3),
                    Text(
                      '$count',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: hasReacted ? const Color(0xFF38BDF8) : const Color(0xFF94A3B8),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // Text Input Row with Attachment Button
  Widget _buildMessageInputField(Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: const BoxDecoration(
        color: Color(0xFF1E293B),
        border: Border(top: BorderSide(color: Color(0xFF334155))),
      ),
      child: SafeArea(
        child: Row(
          children: [
            // Attachment Button
            IconButton(
              icon: const Icon(Icons.attach_file, color: Color(0xFF94A3B8), size: 22),
              tooltip: 'Attach file or image',
              onPressed: _showAttachmentPickerSheet,
            ),
            Expanded(
              child: TextField(
                controller: _messageController,
                focusNode: _messageFocusNode,
                style: const TextStyle(color: Colors.white),
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  hintText: _replyToId != null
                      ? 'Reply to ${_replyToSender ?? "message"}...'
                      : _referencedNoticeTitle != null
                          ? 'Comment on notice...'
                          : _selectedFile != null
                              ? 'Add a caption...'
                              : widget.scope == ChatScope.cr
                                  ? 'Message CR Council (7-day auto-purge)...'
                                  : widget.scope == ChatScope.department
                                      ? 'Message Department (24h ephemeral)...'
                                      : 'Message batch (24h ephemeral)...',
                  hintStyle: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                  fillColor: const Color(0xFF0F172A),
                  filled: true,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(color: Color(0xFF334155)),
                  ),
                ),
                onSubmitted: (_) => _handleSendMessage(),
              ),
            ),
            const SizedBox(width: 8),
            CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFF0284C7),
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white, size: 18),
                onPressed: _handleSendMessage,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
