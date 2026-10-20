import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_time_helper.dart';
import '../../models/notice_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/skeleton_loader.dart';
import 'open_group_screen.dart';

class InfoChannelScreen extends StatefulWidget {
  const InfoChannelScreen({super.key});

  @override
  State<InfoChannelScreen> createState() => _InfoChannelScreenState();
}

class _InfoChannelScreenState extends State<InfoChannelScreen> {
  final DbService _dbService = DbService();
  List<NoticeModel> _notices = [];
  bool _isLoading = true;
  String? _batchId;

  // Broadcast composer controllers for CR/Teacher
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadBatchNotices();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _loadBatchNotices() async {
    setState(() => _isLoading = true);
    final authService = Provider.of<AuthService>(context, listen: false);
    _batchId = authService.studentProfile?.batchId;

    try {
      // Strictly query notices scoped to this student's batch
      final notices = await _dbService.getNotices(batchId: _batchId);
      if (mounted) {
        setState(() {
          _notices = notices;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToComment(NoticeModel notice) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OpenGroupScreen(
          initialReferencedNoticeId: notice.id,
          initialReferencedNoticeTitle: notice.title,
        ),
      ),
    );
  }

  Future<void> _handlePostBroadcast() async {
    final title = _titleController.text.trim();
    final content = _contentController.text.trim();
    if (title.isEmpty || content.isEmpty) return;

    final authService = Provider.of<AuthService>(context, listen: false);
    final isCr = authService.studentProfile?.isCr ?? false;

    try {
      await _dbService.createNotice(
        title: title,
        content: content,
        batchId: _batchId,
        isCrNotice: isCr,
      );
      _titleController.clear();
      _contentController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Announcement broadcasted to channel!'), backgroundColor: AppTheme.success),
        );
        _loadBatchNotices();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to post: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  void _showCreateBroadcastDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Post Channel Broadcast', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _titleController,
                  decoration: const InputDecoration(
                    labelText: 'Notice Title *',
                    hintText: 'e.g. Schedule Update / Exam Venue',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _contentController,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Announcement Content *',
                    hintText: 'Write announcement details...',
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                _handlePostBroadcast();
              },
              child: const Text('Broadcast'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final profile = authService.studentProfile;
    final batchNum = profile?.batchNumber ?? 21;
    final isCr = profile?.isCr ?? false;
    final canPost = isCr || user?.role == UserRole.admin;

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
              'Batch $batchNum Information Group',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Colors.white),
            ),
            Row(
              children: [
                const Icon(Icons.campaign, size: 12, color: Color(0xFF38BDF8)),
                const SizedBox(width: 4),
                Text(
                  canPost ? 'Official Channel • CR / Admin Mode' : 'Official Channel • Read-Only Broadcast',
                  style: const TextStyle(fontSize: 10.5, color: Color(0xFF38BDF8), fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF94A3B8)),
            onPressed: _loadBatchNotices,
            tooltip: 'Refresh Channel',
          ),
          if (canPost)
            IconButton(
              icon: const Icon(Icons.add_circle_outline, color: Color(0xFF38BDF8)),
              tooltip: 'Post Announcement',
              onPressed: () => _showCreateBroadcastDialog(context),
            ),
        ],
      ),
      body: Column(
        children: [
          // Channel Broadcast Top Header Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: const BoxDecoration(
              color: Color(0xFF1E293B),
              border: Border(bottom: BorderSide(color: Color(0xFF334155), width: 1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline, size: 14, color: Color(0xFF94A3B8)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Notices posted here are permanent official broadcasts for Batch $batchNum.',
                    style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),

          // Notices Feed (Telegram Channel Post Stream)
          Expanded(
            child: _isLoading
                ? SkeletonLoader.listSkeleton(count: 3)
                : _notices.isEmpty
                    ? const EmptyStateView(
                        icon: Icons.campaign_outlined,
                        title: 'No Broadcasts Yet',
                        description: 'Official department announcements and CR notices will appear here.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _notices.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final notice = _notices[index];
                          return _buildChannelBroadcastPost(notice);
                        },
                      ),
          ),

          // ================= PERMISSIONS BOTTOM BAR =================
          if (!canPost)
            // Read-Only Student Muted Banner
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                border: Border(top: BorderSide(color: Color(0xFF334155), width: 1)),
              ),
              child: const SafeArea(
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.volume_off_outlined, color: Color(0xFF94A3B8), size: 16),
                    SizedBox(width: 8),
                    Text(
                      'Muted • Only CRs and Department Office can broadcast here',
                      style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            )
          else
            // CR / Faculty Quick Post Bar
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                border: Border(top: BorderSide(color: Color(0xFF334155), width: 1)),
              ),
              child: SafeArea(
                child: InkWell(
                  onTap: () => _showCreateBroadcastDialog(context),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: const Color(0xFF334155)),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.edit_note_outlined, color: Color(0xFF38BDF8), size: 18),
                        SizedBox(width: 10),
                        Text(
                          'Broadcast a new batch announcement...',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Telegram Channel Post Card
  Widget _buildChannelBroadcastPost(NoticeModel notice) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: notice.isCrNotice ? const Color(0xFF00B4D8).withValues(alpha: 0.4) : const Color(0xFF334155),
          width: 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Post Header: Channel / Author Tag & Relative Timestamp
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: notice.isCrNotice
                            ? const Color(0xFF00B4D8).withValues(alpha: 0.2)
                            : const Color(0xFF3B82F6).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        notice.isCrNotice ? 'CR ANNOUNCEMENT' : 'FACULTY DIRECTIVE',
                        style: TextStyle(
                          color: notice.isCrNotice ? const Color(0xFF38BDF8) : const Color(0xFF60A5FA),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    if (notice.authorName != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        'by ${notice.authorName}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                      ),
                    ],
                  ],
                ),
                if (notice.createdAt != null)
                  Text(
                    DateTimeHelper.formatRelativeTime(notice.createdAt!),
                    style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                  ),
              ],
            ),
          ),

          // Post Content
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notice.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    height: 1.3,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  notice.content,
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 13,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),

          // Divider
          const Divider(height: 1, color: Color(0xFF334155)),

          // "Leave a comment" Telegram Action
          InkWell(
            onTap: () => _navigateToComment(notice),
            borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(Icons.chat_bubble_outline, color: Color(0xFF38BDF8), size: 15),
                      SizedBox(width: 8),
                      Text(
                        'Leave a comment in Open Group',
                        style: TextStyle(
                          color: Color(0xFF38BDF8),
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                  Icon(Icons.arrow_forward_ios, color: Color(0xFF38BDF8), size: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
