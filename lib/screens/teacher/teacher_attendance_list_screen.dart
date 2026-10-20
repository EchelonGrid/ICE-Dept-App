import 'package:flutter/material.dart';
import '../../core/theme/app_theme.dart';
import '../../models/routine_model.dart';
import '../../models/student_profile_model.dart';
import '../../services/attendance_service.dart';
import '../../services/db_service.dart';
import '../../widgets/skeleton_loader.dart';

class TeacherAttendanceListScreen extends StatefulWidget {
  final RoutineModel routine;

  const TeacherAttendanceListScreen({super.key, required this.routine});

  @override
  State<TeacherAttendanceListScreen> createState() => _TeacherAttendanceListScreenState();
}

class _TeacherAttendanceListScreenState extends State<TeacherAttendanceListScreen> {
  final DbService _dbService = DbService();
  final AttendanceService _attendanceService = AttendanceService();

  List<StudentProfileModel> _batchStudents = [];
  Map<String, String> _attendanceMap = {}; // student_id -> 'present' | 'absent'
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadStudentsAndAttendance();
  }

  Future<void> _loadStudentsAndAttendance() async {
    setState(() => _isLoading = true);
    try {
      final students = await _dbService.getStudents(batchId: widget.routine.batchId);
      final existingAttendance = await _attendanceService.getClassAttendance(widget.routine.id);

      final Map<String, String> map = {};
      for (final att in existingAttendance) {
        map[att.studentId] = att.status;
      }

      if (mounted) {
        setState(() {
          _batchStudents = students;
          _attendanceMap = map;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _toggleStudentAttendance(String studentId) async {
    final currentStatus = _attendanceMap[studentId] ?? 'absent';
    final newStatus = currentStatus == 'present' ? 'absent' : 'present';

    setState(() {
      _attendanceMap[studentId] = newStatus;
    });

    try {
      await _attendanceService.markAttendanceManually(
        classId: widget.routine.id,
        studentId: studentId,
        status: newStatus,
      );
    } catch (e) {
      // Revert if error
      setState(() {
        _attendanceMap[studentId] = currentStatus;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error marking attendance: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final presentCount = _attendanceMap.values.where((s) => s == 'present').length;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Manual Attendance Checklist', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('${widget.routine.courseName} • Batch ${widget.routine.batchNumber ?? ''}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
      ),
      body: _isLoading
          ? SkeletonLoader.listSkeleton(count: 6)
          : Column(
              children: [
                // Summary Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  color: AppTheme.surface,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total: ${_batchStudents.length} Students',
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '$presentCount Present',
                          style: const TextStyle(color: AppTheme.success, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),

                Expanded(
                  child: ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: _batchStudents.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final student = _batchStudents[index];
                      final isPresent = _attendanceMap[student.userId] == 'present';

                      return Card(
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          leading: CircleAvatar(
                            backgroundColor: isPresent ? AppTheme.success.withValues(alpha: 0.15) : const Color(0xFFF1F5F9),
                            child: Text(
                              student.studentIdRoll.length >= 3 ? student.studentIdRoll.substring(student.studentIdRoll.length - 3) : student.studentIdRoll,
                              style: TextStyle(
                                color: isPresent ? AppTheme.success : AppTheme.textSecondary,
                                fontWeight: FontWeight.bold,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Text(student.userName ?? 'Student', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                              if (student.isCr) ...[
                                const SizedBox(width: 6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: AppTheme.accent.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: const Text('CR', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 10)),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Text('Roll: ${student.studentIdRoll}', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                          trailing: IconButton(
                            icon: Icon(
                              isPresent ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: isPresent ? AppTheme.success : AppTheme.textMuted,
                              size: 28,
                            ),
                            onPressed: () => _toggleStudentAttendance(student.userId),
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
