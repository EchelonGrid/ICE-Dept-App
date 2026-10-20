import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_time_helper.dart';
import '../../models/class_test_model.dart';
import '../../models/department_notice_model.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/profile_avatar_button.dart';
import '../../widgets/home_next_class_card.dart';
import 'student_qr_scanner_screen.dart';
import 'class_test_modal.dart';

class StudentHomeScreen extends StatefulWidget {
  final Function(int) onNavigateTab;

  const StudentHomeScreen({super.key, required this.onNavigateTab});

  @override
  State<StudentHomeScreen> createState() => _StudentHomeScreenState();
}

class _StudentHomeScreenState extends State<StudentHomeScreen> {
  final DbService _dbService = DbService();

  List<DepartmentNoticeModel> _recentNotices = [];
  List<ClassTestModel> _upcomingClassTests = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadHomeData();
  }

  Future<void> _loadHomeData() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final studentProfile = authService.studentProfile;
      final studentBatch = studentProfile?.batchNumber != null
          ? 'Batch ${studentProfile!.batchNumber}'
          : 'Batch 21';

      // Auto-purge expired CTs before loading active tests
      try {
        await _dbService.purgeExpiredClassTests();
      } catch (e) {
        debugPrint('Purge notice: $e');
      }

      final notices = await _dbService.getActiveDepartmentNoticesForBatch(
        batch: studentBatch,
        limit: 5,
      );
      final classTests = await _dbService.getUpcomingClassTestsForBatch(
        batch: studentBatch,
        autoPurge: false,
      );

      if (mounted) {
        setState(() {
          _recentNotices = notices;
          _upcomingClassTests = classTests;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final student = authService.studentProfile;
    final studentBatch = student?.batchNumber != null
        ? 'Batch ${student!.batchNumber}'
        : 'Batch 21';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              user?.name ?? 'Student',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            Text(
              'Batch ${student?.batchNumber ?? 'ICE'} • Roll ${student?.studentIdRoll ?? ''}${student?.isCr == true ? " • CR" : ""}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.qr_code_scanner, color: AppTheme.accent),
            tooltip: 'Scan Attendance QR',
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StudentQRScannerScreen()),
              );
              if (result == true) {
                _loadHomeData();
              }
            },
          ),
          const ProfileAvatarButton(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadHomeData,
        child: _isLoading
            ? SkeletonLoader.listSkeleton(count: 3)
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Dynamic Routine Card (Next Class / Tomorrow's Schedule)
                    HomeNextClassCard(
                      onViewSchedule: () => widget.onNavigateTab(1),
                    ),
                    const SizedBox(height: 20),

                    // Quick QR Attendance CTA
                    _buildQuickScanCTA(),
                    const SizedBox(height: 20),

                    // CT & Exam Countdown Widget
                    _buildCTCountdownWidget(student?.isCr ?? false, studentBatch),
                    const SizedBox(height: 24),

                    // Recent Announcements Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Latest Announcements',
                          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700, color: AppTheme.textPrimary),
                        ),
                        TextButton(
                          onPressed: () => widget.onNavigateTab(3), // Navigate to Batch Chat & Notices Channel
                          child: const Text('View All', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600)),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (_recentNotices.isEmpty)
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppTheme.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.notifications_none, color: AppTheme.textMuted),
                            SizedBox(width: 12),
                            Text('No recent notices for your batch.', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                          ],
                        ),
                      )
                    else
                      ..._recentNotices.map((notice) => _buildNoticePreviewCard(notice)),
                  ],
                ),
              ),
      ),
    );
  }


  Widget _buildQuickScanCTA() {
    return InkWell(
      onTap: () async {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const StudentQRScannerScreen()),
        );
        if (result == true) _loadHomeData();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4), width: 1.5),
          boxShadow: AppTheme.softCardShadow,
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.qr_code_scanner, color: AppTheme.accent, size: 28),
            ),
            const SizedBox(width: 16),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Scan Attendance QR',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Scan teacher\'s 10-second rolling token',
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios, size: 16, color: AppTheme.textMuted),
          ],
        ),
      ),
    );
  }

  Widget _buildCTCountdownWidget(bool isCr, String studentBatch) {
    final tests = _upcomingClassTests;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softCardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              const Icon(Icons.timer_outlined, color: AppTheme.warning, size: 20),
              const SizedBox(width: 8),
              Flexible(
                child: Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    const Text(
                      'Upcoming Class Test / CT',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                    ),
                    if (tests.length > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.amber.shade100,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${tests.length} Scheduled',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                          ),
                        ),
                      ),
                    if (isCr)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppTheme.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('CR Managed', style: TextStyle(fontSize: 10, color: AppTheme.accent, fontWeight: FontWeight.bold)),
                      ),
                  ],
                ),
              ),
              const Spacer(),
              if (isCr)
                FilledButton.tonalIcon(
                  onPressed: () => ClassTestModal.show(
                    context,
                    batch: studentBatch,
                    onSaved: _loadHomeData,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: Text(
                    tests.isEmpty ? 'Schedule CT' : 'Add CT',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 14),

          // Content body
          if (tests.isEmpty) ...[
            // Empty State
            const Text(
              'No upcoming class tests scheduled 🎉',
              style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppTheme.textPrimary),
            ),
            const SizedBox(height: 4),
            const Text(
              'All tests completed or none announced yet for this batch.',
              style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            if (isCr) ...[
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: () => ClassTestModal.show(
                  context,
                  batch: studentBatch,
                  onSaved: _loadHomeData,
                ),
                icon: const Icon(Icons.add, size: 16, color: AppTheme.accent),
                label: const Text(
                  '+ Schedule First Class Test',
                  style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w600),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: AppTheme.accent.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ] else if (tests.length == 1) ...[
            // Single Test View
            _buildSingleTestView(tests.first, isCr, studentBatch),
          ] else ...[
            // Multi-Test View: clean vertical stack of compact cards
            _buildMultiTestView(tests, isCr, studentBatch),
          ],
        ],
      ),
    );
  }

  Widget _buildSingleTestView(ClassTestModel test, bool isCr, String studentBatch) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                '${test.courseCode}: ${test.title}',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                overflow: TextOverflow.ellipsis,
                maxLines: 1,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
              ),
              child: Text(
                test.countdownText,
                style: const TextStyle(
                  color: Color(0xFFB45309),
                  fontWeight: FontWeight.bold,
                  fontSize: 11,
                ),
              ),
            ),
            if (isCr) ...[
              const SizedBox(width: 4),
              IconButton(
                icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.accent),
                tooltip: 'Edit Class Test',
                visualDensity: VisualDensity.compact,
                onPressed: () => ClassTestModal.show(
                  context,
                  existingTest: test,
                  batch: studentBatch,
                  onSaved: _loadHomeData,
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Scheduled for ${test.formattedDate}${test.formattedTime != null ? " at ${test.formattedTime}" : ""}${test.syllabus != null && test.syllabus!.isNotEmpty ? " • Syllabus: ${test.syllabus}" : ""}',
          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
          overflow: TextOverflow.ellipsis,
          maxLines: 2,
        ),
      ],
    );
  }

  Widget _buildMultiTestView(List<ClassTestModel> tests, bool isCr, String studentBatch) {
    return Column(
      children: tests.asMap().entries.map((entry) {
        final index = entry.key;
        final test = entry.value;
        final isLast = index == tests.length - 1;

        return Container(
          margin: EdgeInsets.only(bottom: isLast ? 0 : 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppTheme.background,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppTheme.border.withValues(alpha: 0.6)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppTheme.accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      test.courseCode,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      test.title,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: AppTheme.textPrimary),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppTheme.warning.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      test.countdownText,
                      style: const TextStyle(
                        color: Color(0xFFB45309),
                        fontWeight: FontWeight.bold,
                        fontSize: 10,
                      ),
                    ),
                  ),
                  if (isCr) ...[
                    const SizedBox(width: 4),
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 16, color: AppTheme.accent),
                      tooltip: 'Edit Class Test',
                      visualDensity: VisualDensity.compact,
                      onPressed: () => ClassTestModal.show(
                        context,
                        existingTest: test,
                        batch: studentBatch,
                        onSaved: _loadHomeData,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.calendar_today_outlined, size: 13, color: AppTheme.textMuted),
                  const SizedBox(width: 6),
                  Text(
                    '${test.formattedDate}${test.formattedTime != null ? " • ${test.formattedTime}" : ""}',
                    style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
                  ),
                ],
              ),
              if (test.syllabus != null && test.syllabus!.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  'Syllabus: ${test.syllabus}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildNoticePreviewCard(DepartmentNoticeModel notice) {
    final isUrgent = notice.isPinned || notice.priority.toLowerCase() == 'urgent';
    final isOfficial = notice.authorName == 'Department Office' ||
        notice.authorName.toLowerCase().contains('office') ||
        notice.authorName.toLowerCase().contains('department');

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: isUrgent ? AppTheme.accent.withValues(alpha: 0.6) : AppTheme.border,
          width: isUrgent ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _showNoticeDetailsDialog(notice),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: isUrgent
                              ? AppTheme.error.withValues(alpha: 0.12)
                              : isOfficial
                                  ? AppTheme.primary.withValues(alpha: 0.12)
                                  : AppTheme.accent.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (isUrgent) ...[
                              const Icon(Icons.error_outline, size: 12, color: AppTheme.error),
                              const SizedBox(width: 4),
                              const Text(
                                'Urgent',
                                style: TextStyle(
                                  color: AppTheme.error,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ] else ...[
                              Icon(
                                isOfficial ? Icons.verified : Icons.campaign,
                                size: 12,
                                color: isOfficial ? AppTheme.primary : AppTheme.accent,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                isOfficial ? 'Official Notice' : 'Announcement',
                                style: TextStyle(
                                  color: isOfficial ? AppTheme.primary : AppTheme.accent,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (notice.isPinned && !isUrgent) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.push_pin, size: 14, color: AppTheme.accent),
                      ],
                    ],
                  ),
                  Text(
                    DateTimeHelper.formatRelativeTime(notice.createdAt),
                    style: const TextStyle(fontSize: 11, color: AppTheme.textMuted),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                notice.title,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
              ),
              const SizedBox(height: 4),
              Text(
                notice.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, height: 1.4),
              ),
              if (notice.attachmentUrl != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      (notice.attachmentName?.endsWith('.pdf') ?? false)
                          ? Icons.picture_as_pdf
                          : Icons.attachment,
                      size: 14,
                      color: AppTheme.primary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      notice.attachmentName ?? 'View Attachment',
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showNoticeDetailsDialog(DepartmentNoticeModel notice) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          width: 560,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        notice.targetBatch.toLowerCase() == 'all'
                            ? 'All Batches'
                            : notice.targetBatch,
                        style: const TextStyle(
                          color: AppTheme.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  notice.title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.person_outline, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      notice.authorName,
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(width: 12),
                    const Icon(Icons.schedule, size: 14, color: AppTheme.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      DateTimeHelper.formatDate(notice.createdAt),
                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
                const Divider(height: 24),
                SelectableText(
                  notice.content,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: AppTheme.textPrimary,
                  ),
                ),
                if (notice.attachmentUrl != null) ...[
                  const Divider(height: 24),
                  InkWell(
                    onTap: () async {
                      final uri = Uri.parse(notice.attachmentUrl!);
                      if (await canLaunchUrl(uri)) {
                        await launchUrl(uri, mode: LaunchMode.externalApplication);
                      }
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            (notice.attachmentName?.endsWith('.pdf') ?? false)
                                ? Icons.picture_as_pdf
                                : Icons.image,
                            color: AppTheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              notice.attachmentName ?? 'View Attached Document',
                              style: const TextStyle(
                                color: AppTheme.primary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Icon(Icons.open_in_new, size: 16, color: AppTheme.primary),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerRight,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
