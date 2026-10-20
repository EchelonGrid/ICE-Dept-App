import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_time_helper.dart';
import '../../models/notice_model.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/skeleton_loader.dart';

class StudentNoticesScreen extends StatefulWidget {
  final Function(int)? onNavigateToChat;

  const StudentNoticesScreen({super.key, this.onNavigateToChat});

  @override
  State<StudentNoticesScreen> createState() => _StudentNoticesScreenState();
}

class _StudentNoticesScreenState extends State<StudentNoticesScreen> {
  final DbService _dbService = DbService();
  List<NoticeModel> _notices = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadNotices();
  }

  Future<void> _loadNotices() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final batchId = authService.studentProfile?.batchId;

      final notices = await _dbService.getNotices(batchId: batchId);
      if (mounted) {
        setState(() {
          _notices = notices;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPostNoticeModal(String batchId) {
    final titleController = TextEditingController();
    final contentController = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Publish CR Notice',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 6),
            const Text(
              'As Class Representative, your post will be broadcast to all batch members.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 20),
            AppTextField(
              controller: titleController,
              label: 'Title',
              hint: 'e.g. Tomorrow\'s Lab Submission Reminder',
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: contentController,
              label: 'Notice Content',
              hint: 'Write clear and concise details...',
              maxLines: 4,
            ),
            const SizedBox(height: 20),
            AppButton(
              text: 'Broadcast Notice',
              onPressed: () async {
                if (titleController.text.trim().isNotEmpty && contentController.text.trim().isNotEmpty) {
                  Navigator.pop(ctx);
                  await _dbService.createNotice(
                    title: titleController.text.trim(),
                    content: contentController.text.trim(),
                    batchId: batchId,
                    isCrNotice: true,
                  );
                  _loadNotices();
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final isCr = authService.studentProfile?.isCr ?? false;
    final batchId = authService.studentProfile?.batchId;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Department & Batch Notices', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      floatingActionButton: isCr && batchId != null
          ? FloatingActionButton.extended(
              onPressed: () => _showPostNoticeModal(batchId),
              backgroundColor: AppTheme.primary,
              icon: const Icon(Icons.campaign, color: AppTheme.accent),
              label: const Text('Post CR Notice', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: _loadNotices,
        child: _isLoading
            ? SkeletonLoader.listSkeleton(count: 3)
            : _notices.isEmpty
                ? const EmptyStateView(
                    icon: Icons.notifications_none,
                    title: 'No Notices Yet',
                    description: 'No announcements have been posted for your batch or department.',
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _notices.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final notice = _notices[index];
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(18.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: notice.isCrNotice
                                          ? AppTheme.accent.withValues(alpha: 0.12)
                                          : AppTheme.primary.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      notice.isCrNotice ? 'CR NOTICE' : (notice.isDepartmentWide ? 'DEPT GLOBAL' : 'FACULTY'),
                                      style: TextStyle(
                                        color: notice.isCrNotice ? AppTheme.accent : AppTheme.primary,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  if (notice.createdAt != null)
                                    Text(
                                      DateTimeHelper.formatShortDateTime(notice.createdAt!),
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Text(
                                notice.title,
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                notice.content,
                                style: const TextStyle(fontSize: 14, color: AppTheme.textSecondary, height: 1.5),
                              ),
                              const SizedBox(height: 16),
                              const Divider(height: 1),
                              const SizedBox(height: 10),

                              // Redirection feedback notice
                              Row(
                                children: [
                                  const Icon(Icons.forum_outlined, size: 16, color: AppTheme.textMuted),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      'Discuss this in Batch Common Chat',
                                      style: TextStyle(fontSize: 12, color: AppTheme.accent.withValues(alpha: 0.9), fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  if (widget.onNavigateToChat != null)
                                    InkWell(
                                      onTap: () => widget.onNavigateToChat!(3), // Switch to tab 3 (Chat)
                                      child: const Text(
                                        'Open Chat →',
                                        style: TextStyle(fontSize: 12, color: AppTheme.accent, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
      ),
    );
  }
}
