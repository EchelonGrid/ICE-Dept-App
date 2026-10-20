import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../core/constants/curriculum.dart';
import '../../core/theme/app_theme.dart';
import '../../models/class_test_model.dart';
import '../../services/db_service.dart';

class ClassTestModal extends StatefulWidget {
  final ClassTestModel? existingTest;
  final String batch;
  final VoidCallback onSaved;

  const ClassTestModal({
    super.key,
    this.existingTest,
    required this.batch,
    required this.onSaved,
  });

  static Future<void> show(
    BuildContext context, {
    ClassTestModel? existingTest,
    required String batch,
    required VoidCallback onSaved,
  }) {
    return showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => ClassTestModal(
        existingTest: existingTest,
        batch: batch,
        onSaved: onSaved,
      ),
    );
  }

  @override
  State<ClassTestModal> createState() => _ClassTestModalState();
}

class _ClassTestModalState extends State<ClassTestModal> {
  final DbService _dbService = DbService();
  final _formKey = GlobalKey<FormState>();

  late List<String> _courseCodes;
  late List<SubjectInfo> _subjects;
  late String _selectedCourse;
  late TextEditingController _titleController;
  late TextEditingController _syllabusController;
  late DateTime _selectedDate;
  TimeOfDay? _selectedTime;

  bool _isSubmitting = false;

  bool get _isEditMode => widget.existingTest != null;

  @override
  void initState() {
    super.initState();
    _subjects = DepartmentCurriculum.allSemesters
        .expand((s) => s.subjects)
        .toList();
    _courseCodes = _subjects.map((s) => s.code).toSet().toList();
    if (!_courseCodes.contains('ICE-3101')) {
      _courseCodes.insert(0, 'ICE-3101');
    }

    final test = widget.existingTest;
    if (test != null && _courseCodes.contains(test.courseCode)) {
      _selectedCourse = test.courseCode;
    } else {
      _selectedCourse = _courseCodes.first;
    }

    _titleController = TextEditingController(text: test?.title ?? '');
    _syllabusController = TextEditingController(text: test?.syllabus ?? '');

    // Default to tomorrow if scheduling new, or use existing test date
    _selectedDate = test?.testDate ?? DateTime.now().add(const Duration(days: 1));

    if (test?.testTime != null && test!.testTime!.isNotEmpty) {
      try {
        final parts = test.testTime!.split(':');
        _selectedTime = TimeOfDay(
          hour: int.parse(parts[0]),
          minute: int.parse(parts[1]),
        );
      } catch (_) {
        _selectedTime = const TimeOfDay(hour: 10, minute: 0);
      }
    } else {
      _selectedTime = const TimeOfDay(hour: 10, minute: 0);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _syllabusController.dispose();
    super.dispose();
  }

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: AppTheme.error, size: 24),
            SizedBox(width: 8),
            Text('Delete Class Test?'),
          ],
        ),
        content: Text(
          'Are you sure you want to delete "${widget.existingTest!.title}"? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.error,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSubmitting = true);

    try {
      await _dbService.deleteClassTest(widget.existingTest!.id);
      if (mounted) {
        Navigator.pop(context);
        messenger.showSnackBar(
          const SnackBar(content: Text('Class test removed successfully.')),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error deleting test: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final title = _titleController.text.trim();
    if (title.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please provide a test title')),
      );
      return;
    }

    final messenger = ScaffoldMessenger.of(context);
    setState(() => _isSubmitting = true);

    String? timeString;
    if (_selectedTime != null) {
      final h = _selectedTime!.hour.toString().padLeft(2, '0');
      final m = _selectedTime!.minute.toString().padLeft(2, '0');
      timeString = '$h:$m:00';
    }

    try {
      if (_isEditMode) {
        await _dbService.updateClassTest(
          testId: widget.existingTest!.id,
          courseCode: _selectedCourse,
          title: title,
          syllabus: _syllabusController.text.trim().isEmpty
              ? null
              : _syllabusController.text.trim(),
          testDate: _selectedDate,
          testTime: timeString,
        );
      } else {
        await _dbService.createClassTest(
          batch: widget.batch,
          courseCode: _selectedCourse,
          title: title,
          syllabus: _syllabusController.text.trim().isEmpty
              ? null
              : _syllabusController.text.trim(),
          testDate: _selectedDate,
          testTime: timeString,
        );
      }

      if (mounted) {
        Navigator.pop(context);
        messenger.showSnackBar(
          SnackBar(
            content: Text(
              _isEditMode
                  ? 'Class test updated successfully!'
                  : 'Class test published successfully!',
            ),
            backgroundColor: AppTheme.success,
          ),
        );
        widget.onSaved();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        messenger.showSnackBar(
          SnackBar(
            content: Text('Error: $e'),
            backgroundColor: AppTheme.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
      contentPadding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
      actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(Icons.timer_outlined, color: AppTheme.warning, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _isEditMode ? 'Edit Class Test' : 'Schedule Class Test',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  _isEditMode
                      ? 'Update schedule or syllabus for ${widget.batch}'
                      : 'Publish upcoming test for ${widget.batch}',
                  style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),

                // 1. Course Code Dropdown with isExpanded & overflow protection
                const Text(
                  'Course Code',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _courseCodes.contains(_selectedCourse) ? _selectedCourse : null,
                  hint: const Text('Select Course Code'),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    isDense: true,
                  ),
                  items: _courseCodes.map((code) {
                    final sub = _subjects.firstWhere(
                      (s) => s.code == code,
                      orElse: () => SubjectInfo(name: code, code: code),
                    );
                    return DropdownMenuItem<String>(
                      value: code,
                      child: Text(
                        '$code - ${sub.name}',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                      ),
                    );
                  }).toList(),
                  onChanged: _isSubmitting
                      ? null
                      : (val) {
                          if (val != null) {
                            setState(() => _selectedCourse = val);
                          }
                        },
                ),
                const SizedBox(height: 14),

                // 2. Test Title TextField
                const Text(
                  'Test Title',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  enabled: !_isSubmitting,
                  decoration: InputDecoration(
                    hintText: 'e.g., CT 1 - Midterm Prep or DSP Quiz 1',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    isDense: true,
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Please enter a test title';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // 3. Date & Time Pickers
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Date',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: _isSubmitting
                                ? null
                                : () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate: _selectedDate,
                                      firstDate: DateTime.now().subtract(const Duration(days: 7)),
                                      lastDate: DateTime.now().add(const Duration(days: 180)),
                                    );
                                    if (picked != null) {
                                      setState(() => _selectedDate = picked);
                                    }
                                  },
                            icon: const Icon(Icons.calendar_today, size: 16),
                            label: Text(
                              DateFormat('MMM d, yyyy').format(_selectedDate),
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Time (Optional)',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          const SizedBox(height: 6),
                          OutlinedButton.icon(
                            onPressed: _isSubmitting
                                ? null
                                : () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime: _selectedTime ?? const TimeOfDay(hour: 10, minute: 0),
                                    );
                                    if (picked != null) {
                                      setState(() => _selectedTime = picked);
                                    }
                                  },
                            icon: const Icon(Icons.access_time, size: 16),
                            label: Text(
                              _selectedTime != null
                                  ? _selectedTime!.format(context)
                                  : 'Set Time',
                              style: const TextStyle(fontSize: 12),
                              overflow: TextOverflow.ellipsis,
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 4. Syllabus / Topics covered
                const Text(
                  'Syllabus / Topics Covered',
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _syllabusController,
                  enabled: !_isSubmitting,
                  maxLines: 2,
                  decoration: InputDecoration(
                    hintText: 'e.g., Chapters 1 & 2: Discrete Fourier Transform...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (_isEditMode)
          TextButton.icon(
            onPressed: _isSubmitting ? null : _handleDelete,
            icon: const Icon(Icons.delete_outline, color: AppTheme.error, size: 18),
            label: const Text('Delete', style: TextStyle(color: AppTheme.error)),
          ),
        TextButton(
          onPressed: _isSubmitting ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSubmitting ? null : _handleSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.accent,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          child: _isSubmitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(_isEditMode ? 'Save Changes' : 'Publish CT'),
        ),
      ],
    );
  }
}
