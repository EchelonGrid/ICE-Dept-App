import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/theme/app_theme.dart';
import '../../core/utils/date_time_helper.dart';
import '../../models/department_notice_model.dart';
import '../../services/db_service.dart';

class ClerkNoticesScreen extends StatefulWidget {
  final List<String>? initialBatches;

  const ClerkNoticesScreen({
    super.key,
    this.initialBatches,
  });

  @override
  State<ClerkNoticesScreen> createState() => _ClerkNoticesScreenState();
}

class _ClerkNoticesScreenState extends State<ClerkNoticesScreen> {
  final DbService _dbService = DbService();
  final TextEditingController _searchController = TextEditingController();

  List<DepartmentNoticeModel> _allNotices = [];
  List<String> _batches = ['All Batches'];
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedTab = 0; // 0 = Active, 1 = Archived/Expired
  String _selectedBatchFilter = 'All Batches';

  @override
  void initState() {
    super.initState();
    _loadBatches();
    _loadNotices();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBatches() async {
    if (widget.initialBatches != null && widget.initialBatches!.isNotEmpty) {
      if (mounted) {
        setState(() {
          _batches = ['All Batches', ...widget.initialBatches!];
        });
      }
      return;
    }

    try {
      final fetched = await _dbService.getBatches();
      if (mounted) {
        setState(() {
          _batches = [
            'All Batches',
            ...fetched.map((b) => 'Batch ${b.batchNumber}'),
          ];
        });
      }
    } catch (_) {}
  }

  Future<void> _loadNotices() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final list = await _dbService.getDepartmentNotices();
      if (mounted) {
        setState(() {
          _allNotices = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load notices: $e';
          _isLoading = false;
        });
      }
    }
  }

  List<DepartmentNoticeModel> get _activeNotices =>
      _allNotices.where((n) => !n.isExpired).toList();

  List<DepartmentNoticeModel> get _expiredNotices =>
      _allNotices.where((n) => n.isExpired).toList();

  List<DepartmentNoticeModel> get _displayedNotices {
    final baseList = _selectedTab == 0 ? _activeNotices : _expiredNotices;
    final query = _searchController.text.trim().toLowerCase();

    return baseList.where((n) {
      final matchesQuery = query.isEmpty ||
          n.title.toLowerCase().contains(query) ||
          n.content.toLowerCase().contains(query) ||
          n.authorName.toLowerCase().contains(query);

      final matchesBatch = _selectedBatchFilter == 'All Batches' ||
          n.targetBatch.toLowerCase() == 'all' ||
          n.targetBatch.toLowerCase() == _selectedBatchFilter.toLowerCase();

      return matchesQuery && matchesBatch;
    }).toList();
  }

  Future<void> _togglePin(DepartmentNoticeModel notice) async {
    final newPinned = !notice.isPinned;
    setState(() {
      final idx = _allNotices.indexWhere((n) => n.id == notice.id);
      if (idx != -1) {
        _allNotices[idx] = _allNotices[idx].copyWith(isPinned: newPinned);
      }
    });

    try {
      await _dbService.togglePinDepartmentNotice(notice.id, newPinned);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              newPinned
                  ? 'Announcement pinned to top 📌'
                  : 'Announcement unpinned',
            ),
            backgroundColor: newPinned ? AppTheme.accent : AppTheme.textSecondary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          final idx = _allNotices.indexWhere((n) => n.id == notice.id);
          if (idx != -1) {
            _allNotices[idx] = _allNotices[idx].copyWith(isPinned: !newPinned);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update pin: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _deleteNotice(DepartmentNoticeModel notice) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Announcement?'),
        content: Text(
          'Are you sure you want to permanently delete "${notice.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete Notice'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _dbService.deleteDepartmentNotice(notice.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Notice deleted successfully.'),
            backgroundColor: AppTheme.warning,
          ),
        );
        _loadNotices();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete notice: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  // ==================== POST NOTICE MODAL ====================

  void _showPostNoticeModal() {
    final titleController = TextEditingController();
    final contentController = TextEditingController();
    String targetBatch = 'all';
    bool isUrgent = false;
    int expiryDays = 30; // Default 30 days
    Uint8List? attachmentBytes;
    String? attachmentName;
    bool isUploading = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (modalCtx, setModalState) {
            return Dialog(
              backgroundColor: AppTheme.surface,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Container(
                width: 640,
                padding: const EdgeInsets.all(24),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.campaign, color: AppTheme.primary, size: 24),
                              SizedBox(width: 10),
                              Text(
                                'Post Department Notice',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: AppTheme.textPrimary,
                                ),
                              ),
                            ],
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            tooltip: 'Close',
                            onPressed: () => Navigator.pop(dialogCtx),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Publish official announcements with auto-expiry and attachments.',
                        style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                      ),
                      const Divider(height: 24),

                      // Notice Title
                      const Text(
                        'Notice Title *',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: titleController,
                        decoration: const InputDecoration(
                          hintText: 'e.g., Final Exam Schedule - Summer 2026',
                          prefixIcon: Icon(Icons.title, size: 18),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Row: Target Audience & Expiry Duration
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final isNarrow = constraints.maxWidth < 450;
                          return Flex(
                            direction: isNarrow ? Axis.vertical : Axis.horizontal,
                            children: [
                              // Target Batch
                              Expanded(
                                flex: isNarrow ? 0 : 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Target Audience',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppTheme.border),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: targetBatch,
                                          isExpanded: true,
                                          items: [
                                            const DropdownMenuItem(
                                              value: 'all',
                                              child: Text('All Batches (Dept-Wide)'),
                                            ),
                                            ..._batches
                                                .where((b) => b != 'All Batches')
                                                .map(
                                                  (b) => DropdownMenuItem(
                                                    value: b,
                                                    child: Text(b),
                                                  ),
                                                ),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) {
                                              setModalState(() => targetBatch = val);
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (!isNarrow) const SizedBox(width: 16),
                              if (isNarrow) const SizedBox(height: 14),

                              // Expiry Duration
                              Expanded(
                                flex: isNarrow ? 0 : 1,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Auto-Expiry Lifecycle',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: AppTheme.border),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<int>(
                                          value: expiryDays,
                                          isExpanded: true,
                                          items: const [
                                            DropdownMenuItem(
                                              value: 7,
                                              child: Text('7 Days'),
                                            ),
                                            DropdownMenuItem(
                                              value: 15,
                                              child: Text('15 Days'),
                                            ),
                                            DropdownMenuItem(
                                              value: 30,
                                              child: Text('30 Days (Default)'),
                                            ),
                                            DropdownMenuItem(
                                              value: 90,
                                              child: Text('End of Semester (90 Days)'),
                                            ),
                                            DropdownMenuItem(
                                              value: -1,
                                              child: Text('Never (Keep Permanently)'),
                                            ),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) {
                                              setModalState(() => expiryDays = val);
                                            }
                                          },
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 16),

                      // Urgency & Pin Switch
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: isUrgent
                              ? AppTheme.accent.withValues(alpha: 0.08)
                              : Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isUrgent ? AppTheme.accent : AppTheme.border,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isUrgent ? Icons.push_pin : Icons.push_pin_outlined,
                                  color: isUrgent ? AppTheme.accent : AppTheme.textSecondary,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                const Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Mark as Urgent / Pin to top',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      'Pins announcement prominently with an urgent highlight',
                                      style: TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Switch(
                              value: isUrgent,
                              activeThumbColor: AppTheme.accent,
                              onChanged: (val) => setModalState(() => isUrgent = val),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Notice Body
                      const Text(
                        'Notice Body *',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      ),
                      const SizedBox(height: 6),
                      TextField(
                        controller: contentController,
                        maxLines: 5,
                        minLines: 4,
                        decoration: const InputDecoration(
                          hintText: 'Enter complete announcement details, instructions, or deadlines...',
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Attachment Section
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Attachment (Optional)',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          if (attachmentBytes != null)
                            TextButton.icon(
                              onPressed: () {
                                setModalState(() {
                                  attachmentBytes = null;
                                  attachmentName = null;
                                });
                              },
                              icon: const Icon(Icons.close, size: 16, color: AppTheme.error),
                              label: const Text(
                                'Remove Attachment',
                                style: TextStyle(color: AppTheme.error, fontSize: 12),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      if (attachmentBytes == null)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 44),
                            side: const BorderSide(color: AppTheme.border),
                          ),
                          icon: const Icon(Icons.attach_file, size: 18),
                          label: const Text('Attach PDF or Image File'),
                          onPressed: () async {
                            final result = await FilePicker.platform.pickFiles(
                              type: FileType.custom,
                              allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg'],
                              withData: true,
                            );
                            if (result != null && result.files.isNotEmpty) {
                              final file = result.files.first;
                              if (file.bytes != null) {
                                setModalState(() {
                                  attachmentBytes = file.bytes;
                                  attachmentName = file.name;
                                });
                              }
                            }
                          },
                        )
                      else
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppTheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: AppTheme.primary.withValues(alpha: 0.25),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                (attachmentName?.endsWith('.pdf') ?? false)
                                    ? Icons.picture_as_pdf
                                    : Icons.image,
                                color: AppTheme.primary,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      attachmentName ?? 'Attached File',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    Text(
                                      '${((attachmentBytes?.lengthInBytes ?? 0) / 1024).toStringAsFixed(1)} KB • Ready to upload',
                                      style: const TextStyle(
                                        color: AppTheme.textSecondary,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(Icons.check_circle, color: AppTheme.success, size: 18),
                            ],
                          ),
                        ),
                      const SizedBox(height: 24),

                      // Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          OutlinedButton(
                            onPressed: isUploading ? null : () => Navigator.pop(dialogCtx),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 12),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppTheme.primary,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                            icon: isUploading
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                    ),
                                  )
                                : const Icon(Icons.send, size: 18),
                            label: Text(isUploading ? 'Publishing...' : 'Publish Notice'),
                            onPressed: isUploading
                                ? null
                                : () async {
                                    final title = titleController.text.trim();
                                    final content = contentController.text.trim();

                                    if (title.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Please enter a notice title.'),
                                          backgroundColor: AppTheme.error,
                                        ),
                                      );
                                      return;
                                    }

                                    if (content.isEmpty) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        const SnackBar(
                                          content: Text('Please enter notice body content.'),
                                          backgroundColor: AppTheme.error,
                                        ),
                                      );
                                      return;
                                    }

                                    setModalState(() => isUploading = true);

                                    String? uploadedUrl;
                                    String? uploadedName;

                                    try {
                                      // Upload attachment if present
                                      if (attachmentBytes != null && attachmentName != null) {
                                        final uploadRes = await _dbService.uploadNoticeAttachment(
                                          fileBytes: attachmentBytes!,
                                          fileName: attachmentName!,
                                        );
                                        uploadedUrl = uploadRes['url'];
                                        uploadedName = uploadRes['name'];
                                      }

                                      // Calculate expiry date
                                      DateTime? expiresAt;
                                      if (expiryDays > 0) {
                                        expiresAt = DateTime.now().add(Duration(days: expiryDays));
                                      }

                                      // Insert into department_notices
                                      await _dbService.createDepartmentNotice(
                                        title: title,
                                        content: content,
                                        attachmentUrl: uploadedUrl,
                                        attachmentName: uploadedName,
                                        targetBatch: targetBatch,
                                        priority: isUrgent ? 'urgent' : 'normal',
                                        isPinned: isUrgent,
                                        expiresAt: expiresAt,
                                      );

                                      if (dialogCtx.mounted) {
                                        Navigator.pop(dialogCtx);
                                      }
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          const SnackBar(
                                            content: Text('Department notice published successfully! 📢'),
                                            backgroundColor: AppTheme.success,
                                          ),
                                        );
                                        _loadNotices();
                                      }
                                    } catch (e) {
                                      setModalState(() => isUploading = false);
                                      if (mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('Publish failed: $e'),
                                            backgroundColor: AppTheme.error,
                                          ),
                                        );
                                      }
                                    }
                                  },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  // ==================== NOTICE DETAILS MODAL ====================

  void _showNoticeDetailsDialog(DepartmentNoticeModel notice) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AppTheme.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Container(
          width: 600,
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top row badges & close
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: notice.targetBatch.toLowerCase() == 'all'
                                ? AppTheme.primary.withValues(alpha: 0.12)
                                : AppTheme.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            notice.targetBatch.toLowerCase() == 'all'
                                ? 'All Batches'
                                : notice.targetBatch,
                            style: TextStyle(
                              color: notice.targetBatch.toLowerCase() == 'all'
                                  ? AppTheme.primary
                                  : AppTheme.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        if (notice.isUrgent) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.error_outline, size: 14, color: AppTheme.error),
                                SizedBox(width: 4),
                                Text(
                                  'URGENT',
                                  style: TextStyle(
                                    color: AppTheme.error,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                        if (notice.isPinned) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.push_pin, size: 16, color: AppTheme.accent),
                        ],
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Title
                Text(
                  notice.title,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),

                // Metadata Row
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.person_outline, size: 15, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          notice.authorName,
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.calendar_today_outlined, size: 14, color: AppTheme.textSecondary),
                        const SizedBox(width: 4),
                        Text(
                          DateTimeHelper.formatDate(notice.createdAt),
                          style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: notice.isExpired
                            ? Colors.grey.shade200
                            : notice.isPermanent
                                ? AppTheme.success.withValues(alpha: 0.15)
                                : AppTheme.warning.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        notice.expiryCountdownText,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: notice.isExpired
                              ? AppTheme.textSecondary
                              : notice.isPermanent
                                  ? AppTheme.success
                                  : AppTheme.warning,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 24),

                // Content
                SelectableText(
                  notice.content,
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.6,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),

                // Attachment Section if present
                if (notice.attachmentUrl != null) ...[
                  const Divider(height: 24),
                  const Text(
                    'Attachment:',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 8),
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
                              notice.attachmentName ?? 'View Attached File',
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

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 600;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Header Row
            _buildHeaderBar(isMobile),
            const SizedBox(height: 20),

            // Search and Batch Filter Row
            _buildFilterRow(isMobile),
            const SizedBox(height: 20),

            // Segmented Tabs: Active vs Archived
            _buildTabs(),
            const SizedBox(height: 16),

            // Notice List or Empty State
            if (_isLoading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 60),
                child: Center(child: CircularProgressIndicator()),
              )
            else if (_errorMessage != null)
              _buildErrorView()
            else if (_displayedNotices.isEmpty)
              _buildEmptyState()
            else
              _buildNoticeList(),
          ],
        );
      },
    );
  }

  // ==================== SUB-WIDGETS ====================

  Widget _buildHeaderBar(bool isMobile) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Department Notices & Announcements',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.textPrimary,
                ),
                overflow: TextOverflow.ellipsis,
              ),
              SizedBox(height: 4),
              Text(
                'Publish official announcements with auto-expiry, pinned urgency, and attachments',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 12 : 18,
              vertical: 12,
            ),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          icon: const Icon(Icons.add, size: 18),
          label: Text(
            isMobile ? 'Post' : 'Post Notice',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: _showPostNoticeModal,
        ),
      ],
    );
  }

  Widget _buildFilterRow(bool isMobile) {
    if (isMobile) {
      return Column(
        children: [
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search notices by title, content, or author...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedBatchFilter,
                isExpanded: true,
                items: _batches.map((b) {
                  return DropdownMenuItem(
                    value: b,
                    child: Text(b, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedBatchFilter = val);
                  }
                },
              ),
            ),
          ),
        ],
      );
    }

    return Row(
      children: [
        // Search field
        Expanded(
          flex: 3,
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search notices by title, content, or author...',
              prefixIcon: const Icon(Icons.search, size: 20),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                        });
                      },
                    )
                  : null,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
            ),
            onChanged: (_) => setState(() {}),
          ),
        ),
        const SizedBox(width: 12),

        // Batch audience filter
        Expanded(
          flex: 2,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.border),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: _selectedBatchFilter,
                isExpanded: true,
                items: _batches.map((b) {
                  return DropdownMenuItem(
                    value: b,
                    child: Text(b, overflow: TextOverflow.ellipsis),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedBatchFilter = val);
                  }
                },
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _buildTabItem(
              index: 0,
              label: 'Active Notices',
              count: _activeNotices.length,
              icon: Icons.campaign,
            ),
            const SizedBox(width: 8),
            _buildTabItem(
              index: 1,
              label: 'Archived / Expired',
              count: _expiredNotices.length,
              icon: Icons.archive_outlined,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem({
    required int index,
    required String label,
    required int count,
    required IconData icon,
  }) {
    final isSelected = _selectedTab == index;
    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          border: Border(
            bottom: BorderSide(
              color: isSelected ? AppTheme.primary : Colors.transparent,
              width: 2.5,
            ),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                fontSize: 14,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppTheme.primary.withValues(alpha: 0.12)
                    : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? AppTheme.primary : AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNoticeList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _displayedNotices.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final notice = _displayedNotices[index];
        return _buildNoticeCard(notice);
      },
    );
  }

  Widget _buildNoticeCard(DepartmentNoticeModel notice) {
    return SizedBox(
      width: double.infinity,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: notice.isPinned
                ? AppTheme.accent.withValues(alpha: 0.6)
                : AppTheme.border,
            width: notice.isPinned ? 1.5 : 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Badges & Actions Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        // Target Batch Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: notice.targetBatch.toLowerCase() == 'all'
                                ? AppTheme.primary.withValues(alpha: 0.12)
                                : AppTheme.accent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            notice.targetBatch.toLowerCase() == 'all'
                                ? 'All Batches'
                                : notice.targetBatch,
                            style: TextStyle(
                              color: notice.targetBatch.toLowerCase() == 'all'
                                  ? AppTheme.primary
                                  : AppTheme.accent,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),

                        // Urgent Badge
                        if (notice.isUrgent)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.error.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.error_outline, size: 12, color: AppTheme.error),
                                SizedBox(width: 4),
                                Text(
                                  'URGENT',
                                  style: TextStyle(
                                    color: AppTheme.error,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Pinned Indicator
                        if (notice.isPinned)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.push_pin, size: 12, color: AppTheme.accent),
                                SizedBox(width: 4),
                                Text(
                                  'PINNED',
                                  style: TextStyle(
                                    color: AppTheme.accent,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Action Buttons: Pin, View Details, Delete
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          notice.isPinned ? Icons.push_pin : Icons.push_pin_outlined,
                          color: notice.isPinned ? AppTheme.accent : AppTheme.textMuted,
                          size: 19,
                        ),
                        tooltip: notice.isPinned ? 'Unpin announcement' : 'Pin to top',
                        onPressed: () => _togglePin(notice),
                      ),
                      IconButton(
                        icon: const Icon(Icons.visibility_outlined, size: 19, color: AppTheme.primary),
                        tooltip: 'View Notice Details',
                        onPressed: () => _showNoticeDetailsDialog(notice),
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 19, color: AppTheme.error),
                        tooltip: 'Delete Announcement',
                        onPressed: () => _deleteNotice(notice),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 10),

              // Title
              InkWell(
                onTap: () => _showNoticeDetailsDialog(notice),
                child: Text(
                  notice.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(height: 6),

              // Body Excerpt
              Text(
                notice.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.4,
                ),
              ),

              // Attachment Chip if present
              if (notice.attachmentUrl != null) ...[
                const SizedBox(height: 10),
                InkWell(
                  onTap: () async {
                    final uri = Uri.parse(notice.attachmentUrl!);
                    if (await canLaunchUrl(uri)) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          (notice.attachmentName?.endsWith('.pdf') ?? false)
                              ? Icons.picture_as_pdf
                              : Icons.image,
                          size: 15,
                          color: AppTheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          notice.attachmentName ?? 'View Attachment',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.primary,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(Icons.open_in_new, size: 13, color: AppTheme.primary),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),

              // Metadata Row: Published date, Author, Countdown chip
              Wrap(
                spacing: 12,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.person_outline, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        notice.authorName,
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        DateTimeHelper.formatDate(notice.createdAt),
                        style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),

                  // Countdown Chip
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: notice.isExpired
                          ? Colors.grey.shade200
                          : notice.isPermanent
                              ? AppTheme.success.withValues(alpha: 0.12)
                              : AppTheme.warning.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      notice.expiryCountdownText,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: notice.isExpired
                            ? AppTheme.textSecondary
                            : notice.isPermanent
                                ? AppTheme.success
                                : AppTheme.warning,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    final isActiveTab = _selectedTab == 0;
    return SizedBox(
      width: double.infinity,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isActiveTab ? Icons.campaign_outlined : Icons.archive_outlined,
                  size: 48,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                isActiveTab
                    ? 'No official notices published yet.'
                    : 'No archived or expired notices.',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                isActiveTab
                    ? 'Use the button below to announce routine updates, exam schedules, or general circulars.'
                    : 'Notices that expire past their auto-expiry date will automatically appear here.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              ),
              if (isActiveTab) ...[
                const SizedBox(height: 20),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Post First Notice'),
                  onPressed: _showPostNoticeModal,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              style: const TextStyle(color: AppTheme.error, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadNotices,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
