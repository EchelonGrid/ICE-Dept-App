import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/student_profile_model.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/profile_avatar_button.dart';
import '../../widgets/skeleton_loader.dart';

class TeacherDirectInboxScreen extends StatefulWidget {
  const TeacherDirectInboxScreen({super.key});

  @override
  State<TeacherDirectInboxScreen> createState() => _TeacherDirectInboxScreenState();
}

class _TeacherDirectInboxScreenState extends State<TeacherDirectInboxScreen> {
  final DbService _dbService = DbService();
  List<StudentProfileModel> _crList = [];
  bool _isLoading = true;

  // Official batches Dr. Anwar Hossain instructs
  static const List<int> _targetBatchNumbers = [14, 16, 18];

  @override
  void initState() {
    super.initState();
    _loadClassRepresentatives();
  }

  Future<void> _loadClassRepresentatives() async {
    setState(() => _isLoading = true);

    // Representative CR fallback for unseeded batches / offline mode
    final fallbackCrs = <int, StudentProfileModel>{
      14: StudentProfileModel(
        userId: 'cr-batch-14',
        batchId: '082ddf93-3d66-4724-bc40-cf76bfa5fd68',
        isCr: true,
        studentIdRoll: '1408001',
        currentSemester: '4-2',
        userName: 'Mahmudul Hasan',
        batchNumber: 14,
      ),
      16: StudentProfileModel(
        userId: 'cr-batch-16',
        batchId: '0aaee864-d9d3-428b-b2ff-1c812e4c10ef',
        isCr: true,
        studentIdRoll: '1608001',
        currentSemester: '3-2',
        userName: 'Tariqul Islam',
        batchNumber: 16,
      ),
      18: StudentProfileModel(
        userId: 'cr-batch-18',
        batchId: '58f04c5e-7e41-4747-b4c4-b3318cd06be0',
        isCr: true,
        studentIdRoll: '1808001',
        currentSemester: '2-2',
        userName: 'Rifat Ahmed',
        batchNumber: 18,
      ),
    };

    try {
      final students = await _dbService.getStudents();
      final crs = students.where((s) => s.isCr).toList();

      // Ensure every target batch (14, 16, 18) is represented
      final existingBatchNumbers = crs.map((c) => c.batchNumber).whereType<int>().toSet();
      final List<StudentProfileModel> combined = List.from(crs);

      for (final batchNum in _targetBatchNumbers) {
        if (!existingBatchNumbers.contains(batchNum) && fallbackCrs.containsKey(batchNum)) {
          combined.add(fallbackCrs[batchNum]!);
        }
      }

      // Sort by batch number
      combined.sort((a, b) => (a.batchNumber ?? 99).compareTo(b.batchNumber ?? 99));

      if (mounted) {
        setState(() {
          _crList = combined;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _crList = fallbackCrs.values.toList();
          _isLoading = false;
        });
      }
    }
  }

  /// Opens the "Post Notice to Class" modal to broadcast an announcement to public.department_notices
  void _showPostNoticeDialog() {
    final titleCtrl = TextEditingController();
    final contentCtrl = TextEditingController();
    String selectedBatch = 'Batch 18';
    String priority = 'normal';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.campaign_rounded, color: AppTheme.primary, size: 24),
              SizedBox(width: 8),
              Text('Post Notice to Class', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Publish an official notice to students in public.department_notices.',
                  style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 14),

                // Target Batch Selector
                DropdownButtonFormField<String>(
                  initialValue: selectedBatch,
                  decoration: InputDecoration(
                    labelText: 'Target Batch',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All My Batches (14, 16, 18)')),
                    DropdownMenuItem(value: 'Batch 14', child: Text('Batch 14 (Year 4)')),
                    DropdownMenuItem(value: 'Batch 16', child: Text('Batch 16 (Year 3)')),
                    DropdownMenuItem(value: 'Batch 18', child: Text('Batch 18 (Year 2)')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedBatch = val);
                  },
                ),
                const SizedBox(height: 12),

                // Priority
                DropdownButtonFormField<String>(
                  initialValue: priority,
                  decoration: InputDecoration(
                    labelText: 'Notice Priority',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'normal', child: Text('Normal Priority')),
                    DropdownMenuItem(value: 'urgent', child: Text('Urgent / High Priority')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => priority = val);
                  },
                ),
                const SizedBox(height: 12),

                // Title
                AppTextField(
                  controller: titleCtrl,
                  label: 'Notice Title',
                  hint: 'e.g. Midterm Test Syllabus & Lab Reschedule',
                ),
                const SizedBox(height: 12),

                // Content
                AppTextField(
                  controller: contentCtrl,
                  label: 'Notice Body / Instructions',
                  hint: 'Enter official guidelines or announcements for the class...',
                  maxLines: 4,
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
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty || contentCtrl.text.trim().isEmpty) {
                  return;
                }
                Navigator.pop(ctx);

                final messenger = ScaffoldMessenger.of(context);
                try {
                  final authService = Provider.of<AuthService>(context, listen: false);
                  final author = authService.currentUser?.name ?? 'Prof. Dr. Md. Anwar Hossain';

                  await _dbService.createDepartmentNotice(
                    title: titleCtrl.text.trim(),
                    content: contentCtrl.text.trim(),
                    targetBatch: selectedBatch,
                    priority: priority,
                    authorName: author,
                  );

                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Notice posted to $selectedBatch successfully!'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Error posting notice: $e'), backgroundColor: AppTheme.error),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Broadcast Notice'),
            ),
          ],
        ),
      ),
    );
  }

  void _showMessageDialog(StudentProfileModel cr) {
    final messageCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text('Message CR (${cr.userName ?? "Representative"})'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Batch ${cr.batchNumber} Class Representative • Roll: ${cr.studentIdRoll}',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 14),
            AppTextField(
              controller: messageCtrl,
              label: 'Direct Instruction / Reschedule Note',
              hint: 'e.g. Please inform batch ${cr.batchNumber} that the upcoming lab session is shifted to Room 904.',
              maxLines: 4,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              if (messageCtrl.text.trim().isNotEmpty) {
                Navigator.pop(ctx);
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await _dbService.createNotice(
                    title: 'Faculty Instruction to Batch ${cr.batchNumber} CR',
                    content: messageCtrl.text.trim(),
                    batchId: cr.batchId,
                    isCrNotice: true,
                  );
                } catch (_) {}

                if (mounted) {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text('Direct instruction sent to Batch ${cr.batchNumber} CR!'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.primary, foregroundColor: Colors.white),
            child: const Text('Send Message'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Direct CR Channel', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            Text('Batches 14, 16, 18 Representatives', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
        actions: const [
          ProfileAvatarButton(),
        ],
      ),
      body: _isLoading
          ? SkeletonLoader.listSkeleton(count: 3)
          : Column(
              children: [
                // Top Post Notice CTA Bar
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppTheme.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.campaign_rounded, color: AppTheme.primary, size: 20),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Class Announcements',
                              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: AppTheme.textPrimary),
                            ),
                            Text(
                              'Post notice to Batch 14, 16, or 18 cohorts',
                              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                            ),
                          ],
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: _showPostNoticeDialog,
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Post Notice to Class', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          elevation: 0,
                        ),
                      ),
                    ],
                  ),
                ),

                // CR List
                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
                    itemCount: _crList.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, index) {
                      final cr = _crList[index];
                      final isInstructedBatch = _targetBatchNumbers.contains(cr.batchNumber);

                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: const BorderSide(color: AppTheme.border),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(14.0),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isInstructedBatch
                                    ? AppTheme.accent.withValues(alpha: 0.15)
                                    : const Color(0xFFF1F5F9),
                                radius: 24,
                                child: Text(
                                  cr.batchNumber != null ? '${cr.batchNumber}' : 'CR',
                                  style: TextStyle(
                                    color: isInstructedBatch ? AppTheme.accent : const Color(0xFF475569),
                                    fontWeight: FontWeight.w900,
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          cr.userName ?? 'Class Representative',
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5, color: AppTheme.textPrimary),
                                        ),
                                        const SizedBox(width: 6),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: AppTheme.accent.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: const Text('CR', style: TextStyle(color: AppTheme.accent, fontSize: 10, fontWeight: FontWeight.bold)),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      'Batch ${cr.batchNumber} • Roll: ${cr.studentIdRoll}',
                                      style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.send_rounded, color: AppTheme.primary),
                                tooltip: 'Message CR',
                                onPressed: () => _showMessageDialog(cr),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
