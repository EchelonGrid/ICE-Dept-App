import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../models/batch_model.dart';
import '../../models/student_profile_model.dart';
import '../../services/db_service.dart';
import '../../widgets/app_text_field.dart';

class BatchDetailsScreen extends StatefulWidget {
  final String? batchId;
  final int? batchNumber;
  final String? batchName;

  const BatchDetailsScreen({
    super.key,
    this.batchId,
    this.batchNumber,
    this.batchName,
  });

  @override
  State<BatchDetailsScreen> createState() => _BatchDetailsScreenState();
}

class _BatchDetailsScreenState extends State<BatchDetailsScreen> {
  final DbService _dbService = DbService();
  final TextEditingController _searchController = TextEditingController();

  List<StudentProfileModel> _students = [];
  BatchModel? _batch;
  Map<String, dynamic>? _batchInfo;
  String? _effectiveBatchId;
  bool _isLoading = true;
  String? _errorMessage;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadBatchData();
    _fetchBatchInfo();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  int? get resolvedBatchNumber {
    int? num = widget.batchNumber;
    if (num == null && widget.batchName != null) {
      final digits = RegExp(r'\d+').stringMatch(widget.batchName!);
      if (digits != null) num = int.tryParse(digits);
    }
    if (num == null && _batch != null && _batch!.batchNumber > 0) {
      num = _batch!.batchNumber;
    }
    if (num == null && widget.batchId != null) {
      final digits = RegExp(r'\d+').stringMatch(widget.batchId!);
      if (digits != null) num = int.tryParse(digits);
    }
    return num;
  }

  Future<void> _fetchBatchInfo() async {
    try {
      Map<String, dynamic>? data;
      if (widget.batchId != null &&
          widget.batchId!.isNotEmpty &&
          RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(widget.batchId!)) {
        data = await Supabase.instance.client
            .from('batches')
            .select()
            .eq('id', widget.batchId!)
            .maybeSingle();
      } else if (resolvedBatchNumber != null) {
        data = await Supabase.instance.client
            .from('batches')
            .select()
            .eq('batch_number', resolvedBatchNumber!)
            .maybeSingle();
      }
      if (data != null && mounted) {
        setState(() {
          _batchInfo = data;
          _batch = BatchModel.fromJson(data!);
        });
      }
    } catch (e) {
      debugPrint('Error loading batch metadata: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadBatchData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final batches = await _dbService.getBatches();
      BatchModel? matchedBatch;

      // 1. Try matching by UUID if provided
      if (widget.batchId != null && widget.batchId!.isNotEmpty) {
        for (final b in batches) {
          if (b.id.toLowerCase() == widget.batchId!.toLowerCase()) {
            matchedBatch = b;
            break;
          }
        }
      }

      // 2. If not matched, match by batch number or batch name string
      if (matchedBatch == null) {
        final targetNum = widget.batchNumber ??
            int.tryParse(RegExp(r'\d+').firstMatch(widget.batchName ?? widget.batchId ?? '')?.group(0) ?? '');
        if (targetNum != null) {
          for (final b in batches) {
            if (b.batchNumber == targetNum) {
              matchedBatch = b;
              break;
            }
          }
        }
      }

      // 3. Fallback to first batch if available
      if (matchedBatch == null && batches.isNotEmpty) {
        matchedBatch = batches.first;
      }

      _effectiveBatchId = matchedBatch?.id ?? widget.batchId;

      List<StudentProfileModel> students = [];
      if (_effectiveBatchId != null && _effectiveBatchId!.isNotEmpty) {
        // Defensive check: only query by batch_id if it's a valid UUID
        final isUuid = RegExp(
          r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
        ).hasMatch(_effectiveBatchId!);

        if (isUuid) {
          students = await _dbService.getStudents(batchId: _effectiveBatchId);
        } else {
          // If not UUID, fetch all students and filter by batch number in memory
          final allStudents = await _dbService.getStudents();
          final num = matchedBatch?.batchNumber ?? widget.batchNumber;
          students = allStudents.where((s) => s.batchNumber == num).toList();
        }
      }

      if (mounted) {
        setState(() {
          _batch = matchedBatch;
          if (matchedBatch != null && _batchInfo == null) {
            _batchInfo = matchedBatch.toJson();
          }
          _students = students;
          _isLoading = false;
          _errorMessage = null;
        });
        _fetchBatchInfo();
      }
    } catch (e, stack) {
      debugPrint('Error fetching batch students: $e\n$stack');
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load students: $e';
          _isLoading = false;
        });
      }
    }
  }

  String get _displayBatchTitle {
    if (widget.batchName != null && widget.batchName!.isNotEmpty) {
      return widget.batchName!;
    }
    if (_batch != null) {
      return 'Batch ${_batch!.batchNumber}';
    }
    if (widget.batchNumber != null) {
      return 'Batch ${widget.batchNumber}';
    }
    return 'Batch Roster';
  }

  List<StudentProfileModel> get _filteredStudents {
    if (_searchQuery.isEmpty) return _students;
    return _students.where((s) {
      final roll = s.studentIdRoll.toLowerCase();
      final name = (s.userName ?? '').toLowerCase();
      final email = (s.userEmail ?? '').toLowerCase();
      return roll.contains(_searchQuery) ||
          name.contains(_searchQuery) ||
          email.contains(_searchQuery);
    }).toList();
  }

  // ==================== DIALOGS & ACTIONS ====================

  void _showAddStudentDialog() {
    final nameCtrl = TextEditingController();
    final rollCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: 'ice12345');
    bool isCr = false;
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.person_add_outlined, color: AppTheme.accent),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Add Student to $_displayBatchTitle',
                  style: const TextStyle(fontSize: 18),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    controller: nameCtrl,
                    label: 'Full Name',
                    hint: 'e.g. Shakil Ahmed',
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: rollCtrl,
                    label: 'Roll / Student ID',
                    hint: 'e.g. 2108005',
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: emailCtrl,
                    label: 'Email Address',
                    hint: 'e.g. student@ice.dept',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: passCtrl,
                    label: 'Temporary Password',
                    hint: 'ice12345',
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: isCr,
                    title: const Text('Appoint as Class Representative (CR)', style: TextStyle(fontSize: 14)),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (val) => setDialogState(() => isCr = val ?? false),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final name = nameCtrl.text.trim();
                      final roll = rollCtrl.text.trim();
                      final email = emailCtrl.text.trim();
                      final pass = passCtrl.text.trim();

                      if (name.isEmpty || roll.isEmpty || email.isEmpty || pass.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please fill out all required fields.'),
                            backgroundColor: AppTheme.warning,
                          ),
                        );
                        return;
                      }

                      final targetBatchId = _effectiveBatchId ?? _batch?.id ?? widget.batchId;
                      if (targetBatchId == null || targetBatchId.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Cannot add student: Target batch record not found.'),
                            backgroundColor: AppTheme.error,
                          ),
                        );
                        return;
                      }

                      setDialogState(() => isSubmitting = true);

                      try {
                        await _dbService.createStudentUser(
                          email: email,
                          password: pass,
                          name: name,
                          batchId: targetBatchId,
                          rollNumber: roll,
                          isCr: isCr,
                        );

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('🎉 Student $name ($roll) added to $_displayBatchTitle!'),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                          _loadBatchData();
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to add student: $e'),
                              backgroundColor: AppTheme.error,
                            ),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Add Student'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditStudentDialog(StudentProfileModel student) {
    final nameCtrl = TextEditingController(text: student.userName ?? '');
    final rollCtrl = TextEditingController(text: student.studentIdRoll);
    bool isCr = student.isCr;
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit Student Details'),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 400,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(controller: nameCtrl, label: 'Full Name'),
                  const SizedBox(height: 12),
                  AppTextField(controller: rollCtrl, label: 'Roll Number'),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    value: isCr,
                    title: const Text('Class Representative (CR)'),
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    onChanged: (val) => setDialogState(() => isCr = val ?? false),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      setDialogState(() => isSaving = true);
                      try {
                        await _dbService.updateStudentProfile(
                          userId: student.userId,
                          name: nameCtrl.text.trim(),
                          rollNumber: rollCtrl.text.trim(),
                          isCr: isCr,
                        );

                        if (ctx.mounted) {
                          Navigator.pop(ctx);
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Student profile updated successfully.'),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                          _loadBatchData();
                        }
                      } catch (e) {
                        setDialogState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Update failed: $e'),
                              backgroundColor: AppTheme.error,
                            ),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }

  void _showResetPasswordDialog(StudentProfileModel student) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.lock_reset, color: AppTheme.warning),
            SizedBox(width: 8),
            Text('Reset Password'),
          ],
        ),
        content: Text(
          'Send a password reset email link to ${student.userEmail ?? 'this student'}?\n\nThey will be prompted to choose a new password upon following the link.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              if (student.userEmail == null || student.userEmail!.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Student has no email address on file.')),
                );
                return;
              }
              try {
                await _dbService.resetStudentPassword(student.userEmail!);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Password reset email dispatched to ${student.userEmail}!'),
                      backgroundColor: AppTheme.success,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Reset failed: $e'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Send Reset Link'),
          ),
        ],
      ),
    );
  }

  void _showDeleteStudentDialog(StudentProfileModel student) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.error),
            SizedBox(width: 8),
            Text('Remove Student'),
          ],
        ),
        content: Text(
          'Are you sure you want to remove ${student.userName ?? 'this student'} (Roll: ${student.studentIdRoll}) from $_displayBatchTitle?\n\nThis action will unlink the student profile.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await _dbService.deleteStudent(student.userId);
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Student removed from batch roster.'),
                      backgroundColor: AppTheme.warning,
                    ),
                  );
                  _loadBatchData();
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Removal failed: $e'),
                      backgroundColor: AppTheme.error,
                    ),
                  );
                }
              }
            },
            child: const Text('Remove Student'),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleCrStatus(StudentProfileModel student) async {
    final newIsCr = !student.isCr;
    final studentName = student.userName ?? 'Student';

    // 1. Optimistically update local state so the star turns amber/unfilled instantly
    setState(() {
      final index = _students.indexWhere((s) => s.userId == student.userId);
      if (index != -1) {
        _students[index] = _students[index].copyWith(isCr: newIsCr);
      }
    });

    try {
      // 2. Update Supabase via DbService
      await _dbService.updateCrStatus(student.userId, newIsCr);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '$studentName is now ${newIsCr ? 'a Class Representative (CR) ⭐' : 'a regular student'}.',
            ),
            backgroundColor: newIsCr ? AppTheme.accent : AppTheme.textSecondary,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      // Rollback on failure
      if (mounted) {
        setState(() {
          final index = _students.indexWhere((s) => s.userId == student.userId);
          if (index != -1) {
            _students[index] = _students[index].copyWith(isCr: !newIsCr);
          }
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update CR status: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  void _showPromoteBatchDialog(BuildContext context, String currentSem) {
    const order = ['1-1', '1-2', '2-1', '2-2', '3-1', '3-2', '4-1', '4-2'];
    final currentIndex = order.indexOf(currentSem);
    final isFinalSemester = (currentSem == '4-2');
    final nextSem = isFinalSemester
        ? 'Graduated'
        : (currentIndex != -1 && currentIndex < order.length - 1 ? order[currentIndex + 1] : null);

    final batchNum = resolvedBatchNumber;
    final batchId = _batchInfo?['id'] as String? ?? _batch?.id;
    final batchLabel = 'Batch ${batchNum ?? widget.batchName ?? ''}';
    final messenger = ScaffoldMessenger.of(context);

    if (isFinalSemester) {
      // Senior Batch Graduation, 4-2 completed
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade100,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 24),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Graduate Senior Batch',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: SizedBox(
              width: 440,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.amber.shade300),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded, color: Colors.amber.shade900, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            '$batchLabel has completed Semester 4-2.',
                            style: TextStyle(
                              color: Colors.amber.shade900,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Graduating this batch marks them as ALUMNI. They will no longer appear on active routine schedules or CT creation, but their student records will remain archived.',
                    style: TextStyle(fontSize: 14, height: 1.4, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Total Students to Archive: ${_students.length}',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(ctx);
                try {
                  final gradMap = {
                    'current_semester': 'Graduated',
                    'status': 'GRADUATED',
                  };
                  if (batchId != null) {
                    await Supabase.instance.client
                        .from('batches')
                        .update(gradMap)
                        .eq('id', batchId);
                  } else if (batchNum != null) {
                    await Supabase.instance.client
                        .from('batches')
                        .update(gradMap)
                        .eq('batch_number', batchNum);
                  }

                  if (batchId != null) {
                    await _dbService.graduateBatch(
                      batchId: batchId,
                      batchName: batchLabel,
                    );
                  }

                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('$batchLabel successfully graduated to Alumni! 🎓'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                    await _fetchBatchInfo();
                    await _loadBatchData();
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Graduation failed: $e'),
                        backgroundColor: AppTheme.error,
                      ),
                    );
                  }
                }
              },
              icon: const Icon(Icons.school, size: 18),
              label: const Text('Confirm Graduation'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber.shade800,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    } else {
      // Regular Semester Promotion (e.g. 4-1 -> 4-2)
      if (nextSem == null) return;
      DateTime selectedStartDate = DateTime.now();

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (dialogCtx, setDialogState) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6FF),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.upgrade_rounded, color: Color(0xFF1D4ED8), size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Promote $batchLabel',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: SizedBox(
                width: 440,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(fontSize: 15, color: AppTheme.textPrimary),
                        children: [
                          const TextSpan(text: 'Promoting from '),
                          TextSpan(
                            text: 'Semester $currentSem',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF1D4ED8)),
                          ),
                          const TextSpan(text: ' to '),
                          TextSpan(
                            text: 'Semester $nextSem',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.success),
                          ),
                          const TextSpan(text: '.'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Semester Start Date',
                      style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 6),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: dialogCtx,
                          initialDate: selectedStartDate,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setDialogState(() => selectedStartDate = picked);
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          border: Border.all(color: AppTheme.border),
                          borderRadius: BorderRadius.circular(10),
                          color: AppTheme.surface,
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.calendar_today, size: 18, color: Color(0xFF1D4ED8)),
                            const SizedBox(width: 10),
                            Text(
                              DateFormat('EEEE, MMM d, yyyy').format(selectedStartDate),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
                            ),
                            const Spacer(),
                            const Text(
                              'Change',
                              style: TextStyle(fontSize: 12, color: Color(0xFF1D4ED8), fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'This is required for calculating Odd/Even week rotation.',
                      style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.blue.shade200),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.info_outline, size: 18, color: Colors.blue.shade800),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Obsolete CTs from the previous semester will be cleared automatically.',
                              style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  Navigator.pop(ctx);
                  try {
                    final selectedDateStr = selectedStartDate.toIso8601String().split('T')[0];
                    final updateData = {
                      'current_semester': nextSem,
                      'semester_start_date': selectedDateStr,
                    };

                    if (batchId != null) {
                      await Supabase.instance.client
                          .from('batches')
                          .update(updateData)
                          .eq('id', batchId);
                    } else if (batchNum != null) {
                      await Supabase.instance.client
                          .from('batches')
                          .update(updateData)
                          .eq('batch_number', batchNum);
                    }

                    if (batchId != null) {
                      await _dbService.promoteBatch(
                        batchId: batchId,
                        nextSemester: nextSem,
                        newStartDate: selectedStartDate,
                        batchName: batchLabel,
                      );
                    }

                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('$batchLabel promoted to Semester $nextSem! 🚀'),
                          backgroundColor: AppTheme.success,
                        ),
                      );
                      await _fetchBatchInfo();
                      await _loadBatchData();
                    }
                  } catch (e) {
                    if (mounted) {
                      messenger.showSnackBar(
                        SnackBar(
                          content: Text('Promotion failed: $e'),
                          backgroundColor: AppTheme.error,
                        ),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.upgrade_rounded, size: 18),
                label: Text('Promote to $nextSem'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  // ==================== BUILD ====================

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back to Dashboard',
          onPressed: () => Navigator.canPop(context) ? Navigator.pop(context) : context.go('/admin'),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$_displayBatchTitle Roster',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
            Text(
              '${_students.length} Total Enrolled Students',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Roster',
            onPressed: _loadBatchData,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppTheme.accent))
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
                        const SizedBox(height: 12),
                        Text(
                          _errorMessage!,
                          style: const TextStyle(color: AppTheme.error, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: _loadBatchData,
                          icon: const Icon(Icons.refresh, size: 18),
                          label: const Text('Retry'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(120, 42),
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              : Column(
                  children: [
                    _buildBatchHeader(), // Fixed height header/stats
                    Expanded(
                      child: _students.isEmpty
                          ? _buildZeroStudentsEmptyState()
                          : _filteredStudents.isEmpty
                              ? _buildNoSearchResultsEmptyState()
                              : _buildStudentTable(), // Must be Expanded to prevent unbounded height crash
                    ),
                  ],
                ),
    );
  }

  // ==================== HEADER & CONTROLS ====================

  Widget _buildBatchHeader() {
    final currentSem = _batchInfo?['current_semester'] as String? ?? _batch?.currentSemester ?? '4-1';
    final rawStartDate = _batchInfo?['semester_start_date'] ?? (_batch?.semesterStartDate != null ? DateFormat('yyyy-MM-dd').format(_batch!.semesterStartDate!) : null);
    final startDate = rawStartDate?.toString() ?? '2026-07-15';
    final statusStr = (_batchInfo?['status'] as String?)?.toUpperCase() ?? (_batch?.isGraduated ?? false ? 'GRADUATED' : 'ACTIVE');
    final isGraduated = statusStr == 'GRADUATED' || currentSem == 'Graduated';
    final batchDisplay = 'Batch ${resolvedBatchNumber ?? widget.batchName ?? ''}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Summary & Controls Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
              boxShadow: AppTheme.softCardShadow,
            ),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isNarrow = constraints.maxWidth < 600;
                return Flex(
                  direction: isNarrow ? Axis.vertical : Axis.horizontal,
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppTheme.accent.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(Icons.groups_outlined, color: AppTheme.accent, size: 28),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    Text(
                                      batchDisplay,
                                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                                    ),
                                    if (isGraduated) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: Colors.blueGrey.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'ALUMNI',
                                          style: TextStyle(
                                            color: Colors.blueGrey.shade800,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ] else ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: AppTheme.success.withValues(alpha: 0.12),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'ACTIVE BATCH',
                                          style: TextStyle(
                                            color: AppTheme.success,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(
                                          color: const Color(0xFFE0F2FE),
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: Text(
                                          'Semester $currentSem',
                                          style: const TextStyle(
                                            color: Color(0xFF0369A1),
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${_students.length} Enrolled Students • Started: $startDate (Odd/Even Baseline)',
                                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isNarrow) const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        if (!isGraduated)
                          FilledButton.tonalIcon(
                            onPressed: () => _showPromoteBatchDialog(context, currentSem),
                            icon: const Icon(Icons.upgrade_rounded, size: 18),
                            label: const Text('Promote Batch', style: TextStyle(fontWeight: FontWeight.w600)),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xFFEFF6FF),
                              foregroundColor: const Color(0xFF1D4ED8),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ElevatedButton.icon(
                          onPressed: _showAddStudentDialog,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Add Student to Batch'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppTheme.primary,
                            foregroundColor: Colors.white,
                            minimumSize: const Size(160, 44),
                            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Search Bar Card
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  const Icon(Icons.search, color: AppTheme.textMuted, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        hintText: 'Search by student name, roll number, or email...',
                        border: InputBorder.none,
                        isDense: true,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18, color: AppTheme.textMuted),
                      tooltip: 'Clear Search',
                      onPressed: () => _searchController.clear(),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ==================== EMPTY STATES ====================

  Widget _buildZeroStudentsEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 540),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 48),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
            boxShadow: AppTheme.softCardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppTheme.accent.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.school_outlined, size: 48, color: AppTheme.accent),
              ),
              const SizedBox(height: 20),
              Text(
                'No Students Enrolled in $_displayBatchTitle',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              const Text(
                'This batch currently has no registered students.\nOnboard the first student to establish the roster for this academic batch.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13, height: 1.4),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _showAddStudentDialog,
                icon: const Icon(Icons.person_add, size: 18),
                label: const Text('+ Onboard First Student to this Batch'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.accent,
                  foregroundColor: Colors.white,
                  minimumSize: const Size(220, 44),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNoSearchResultsEmptyState() {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.border),
            boxShadow: AppTheme.softCardShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.search_off, size: 44, color: AppTheme.textMuted),
              const SizedBox(height: 14),
              Text(
                'No students matching "$_searchQuery"',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              const Text(
                'Try searching with a different name, roll number, or clear your query.',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 18),
              OutlinedButton(
                onPressed: () => _searchController.clear(),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(160, 40),
                ),
                child: const Text('Clear Search Filter'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ==================== ROSTER TABLE ====================

  Widget _buildStudentTable() {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: SizedBox(
        width: double.infinity,
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Enrolled Students (${_filteredStudents.length}${_filteredStudents.length != _students.length ? ' of ${_students.length}' : ''})',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '$_displayBatchTitle Directory',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                LayoutBuilder(
                  builder: (context, constraints) {
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: ConstrainedBox(
                        constraints: BoxConstraints(minWidth: constraints.maxWidth),
                        child: Theme(
                          data: Theme.of(context).copyWith(
                            dividerColor: Colors.grey.shade200,
                          ),
                          child: DataTable(
                            columnSpacing: 24.0,
                            horizontalMargin: 20.0,
                            headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                            columns: const [
                              DataColumn(label: Text('Roll Number', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Role / CR', style: TextStyle(fontWeight: FontWeight.bold))),
                              DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                            ],
                            rows: _filteredStudents.map((student) {
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      student.studentIdRoll,
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        CircleAvatar(
                                          radius: 14,
                                          backgroundColor: AppTheme.accent.withValues(alpha: 0.15),
                                          child: Text(
                                            (student.userName != null && student.userName!.trim().isNotEmpty)
                                                ? student.userName!.trim()[0].toUpperCase()
                                                : 'S',
                                            style: const TextStyle(
                                              color: AppTheme.accent,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Text(student.userName ?? 'Student'),
                                      ],
                                    ),
                                  ),
                                  DataCell(Text(student.userEmail ?? '-')),
                                  DataCell(
                                    student.isCr
                                        ? Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppTheme.accent.withValues(alpha: 0.12),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(Icons.star, size: 13, color: AppTheme.accent),
                                                SizedBox(width: 4),
                                                Text(
                                                  'CR',
                                                  style: TextStyle(
                                                    color: AppTheme.accent,
                                                    fontWeight: FontWeight.bold,
                                                    fontSize: 11,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          )
                                        : const Text('Student', style: TextStyle(color: AppTheme.textSecondary)),
                                  ),
                                  DataCell(
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        IconButton(
                                          icon: Icon(
                                            student.isCr ? Icons.star : Icons.star_border,
                                            color: student.isCr ? AppTheme.warning : AppTheme.textMuted,
                                            size: 20,
                                          ),
                                          tooltip: student.isCr ? 'Revoke CR Status' : 'Assign as Class Representative (CR)',
                                          onPressed: () => _toggleCrStatus(student),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.edit_outlined, size: 18, color: AppTheme.primary),
                                          tooltip: 'Edit Student',
                                          onPressed: () => _showEditStudentDialog(student),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.lock_reset_outlined, size: 18, color: AppTheme.warning),
                                          tooltip: 'Reset Password',
                                          onPressed: () => _showResetPasswordDialog(student),
                                        ),
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, size: 18, color: AppTheme.error),
                                          tooltip: 'Remove Student',
                                          onPressed: () => _showDeleteStudentDialog(student),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
