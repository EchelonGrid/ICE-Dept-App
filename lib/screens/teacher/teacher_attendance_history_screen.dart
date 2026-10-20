import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/attendance_record_model.dart';
import '../../models/attendance_session_model.dart';
import '../../services/attendance_service.dart';
import '../../services/auth_service.dart';
import '../../utils/csv_exporter.dart';
import '../../utils/routine_helper.dart';
import '../../widgets/skeleton_loader.dart';

class TeacherAttendanceHistoryScreen extends StatefulWidget {
  final String? initialBatch;

  const TeacherAttendanceHistoryScreen({super.key, this.initialBatch});

  @override
  State<TeacherAttendanceHistoryScreen> createState() =>
      _TeacherAttendanceHistoryScreenState();
}

class _TeacherAttendanceHistoryScreenState
    extends State<TeacherAttendanceHistoryScreen> {
  final AttendanceService _attendanceService = AttendanceService();
  List<AttendanceSessionModel> _sessions = [];
  String _selectedBatch = 'All';
  bool _isLoading = true;
  String _teacherInitials = 'MAH';

  @override
  void initState() {
    super.initState();
    if (widget.initialBatch != null && widget.initialBatch!.isNotEmpty) {
      _selectedBatch = widget.initialBatch!;
    }
    _loadSessions();
  }

  Future<void> _loadSessions() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      _teacherInitials = user?.initials ?? user?.displayInitials ?? 'MAH';

      final sessions = await _attendanceService.getAttendanceSessions(
        teacherInitial: _teacherInitials,
      );

      if (mounted) {
        setState(() {
          _sessions = sessions;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  List<String> get _availableBatches {
    final batches = _sessions
        .map((s) => s.batch.replaceAll('ICE-', 'Batch '))
        .toSet()
        .toList();
    batches.addAll(['Batch 14', 'Batch 16', 'Batch 18']);
    final sorted = batches.toSet().toList()..sort();
    return ['All', ...sorted];
  }

  List<AttendanceSessionModel> get _filteredSessions {
    if (_selectedBatch == 'All') return _sessions;
    return _sessions.where((s) {
      final formatted = s.batch.replaceAll('ICE-', 'Batch ');
      final selectedNum = _selectedBatch.replaceAll(RegExp(r'[^0-9]'), '');
      final sessionNum = s.batch.replaceAll(RegExp(r'[^0-9]'), '');
      return formatted.toLowerCase() == _selectedBatch.toLowerCase() ||
          s.batch.toLowerCase() == _selectedBatch.toLowerCase() ||
          (selectedNum.isNotEmpty && selectedNum == sessionNum);
    }).toList();
  }

  Future<void> _exportAllFilteredCsv() async {
    if (_filteredSessions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No attendance records to export.')),
      );
      return;
    }

    final List<AttendanceCsvRow> rows = [];
    for (final session in _filteredSessions) {
      final dateStr = DateFormat('yyyy-MM-dd').format(session.sessionDate);
      final batchStr = session.batch.replaceAll('ICE-', 'Batch ');
      List<AttendanceRecordModel> recordsToUse = session.records;
      if (recordsToUse.isEmpty && !session.isCancelled) {
        try {
          recordsToUse = await _attendanceService.getSessionRecords(session.id);
        } catch (_) {}
      }

      if (recordsToUse.isNotEmpty) {
        for (final rec in recordsToUse) {
          rows.add(AttendanceCsvRow(
            rollNumber: rec.studentRoll,
            studentName: rec.studentName,
            status: rec.status,
            courseCode: session.courseCode,
            batch: batchStr,
            date: dateStr,
          ));
        }
      } else {
        // Placeholder row for session with 0 records
        rows.add(AttendanceCsvRow(
          rollNumber: 'N/A',
          studentName: session.isCancelled ? 'Class Cancelled' : 'No Student Records',
          status: session.status,
          courseCode: session.courseCode,
          batch: batchStr,
          date: dateStr,
        ));
      }
    }

    final csvContent = buildAttendanceCsv(rows);
    final fileName =
        'attendance_export_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.csv';

    final result = await exportCsvFile(
      csvContent: csvContent,
      fileName: fileName,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result != null
                ? 'Exported ${rows.length} records to $fileName'
                : 'Failed to export CSV file',
          ),
          backgroundColor:
              result != null ? const Color(0xFF059669) : AppTheme.error,
        ),
      );
    }
  }

  Future<void> _exportSingleSessionCsv(
    AttendanceSessionModel session, [
    List<AttendanceRecordModel>? currentRecords,
  ]) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(session.sessionDate);
    final batchStr = session.batch.replaceAll('ICE-', 'Batch ');
    List<AttendanceRecordModel> recordsToUse = currentRecords ?? session.records;
    if (recordsToUse.isEmpty && !session.isCancelled) {
      try {
        recordsToUse = await _attendanceService.getSessionRecords(session.id);
      } catch (_) {}
    }

    final List<AttendanceCsvRow> rows = recordsToUse.map((rec) {
      return AttendanceCsvRow(
        rollNumber: rec.studentRoll,
        studentName: rec.studentName,
        status: rec.status,
        courseCode: session.courseCode,
        batch: batchStr,
        date: dateStr,
      );
    }).toList();

    final csvContent = buildAttendanceCsv(rows);
    final fileName =
        '${session.courseCode}_${batchStr.replaceAll(' ', '')}_$dateStr.csv';

    final result = await exportCsvFile(
      csvContent: csvContent,
      fileName: fileName,
    );

    if (mounted) {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result != null
                ? 'Exported ${rows.length} records to $fileName'
                : 'Failed to export CSV',
          ),
          backgroundColor:
              result != null ? const Color(0xFF059669) : AppTheme.error,
        ),
      );
    }
  }

  void _showSessionDetails(AttendanceSessionModel initialSession) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _SessionDetailsModal(
          session: initialSession,
          attendanceService: _attendanceService,
          onExportCsv: (records) => _exportSingleSessionCsv(initialSession, records),
          onRecordUpdated: () {
            _loadSessions();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredSessions;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Attendance Records & Logs',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            Text(
              'Comprehensive Classroom History & Verification',
              style: TextStyle(fontSize: 11, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_rounded, color: Color(0xFF0284C7)),
            tooltip: 'Export CSV',
            onPressed: _exportAllFilteredCsv,
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Refresh Records',
            onPressed: _loadSessions,
          ),
        ],
      ),
      body: _isLoading
          ? SkeletonLoader.listSkeleton(count: 6)
          : RefreshIndicator(
              onRefresh: _loadSessions,
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                children: [
                  // Batch filter pills
                  _buildBatchFilterPills(),
                  const SizedBox(height: 14),

                  // Session Stats Summary Banner
                  _buildSummaryBanner(filtered),
                  const SizedBox(height: 16),

                  // Sessions List
                  if (filtered.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(32),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: const Center(
                        child: Column(
                          children: [
                            Icon(Icons.history_toggle_off_rounded,
                                size: 40, color: Color(0xFF94A3B8)),
                            SizedBox(height: 12),
                            Text(
                              'No attendance sessions found for this filter.',
                              style: TextStyle(
                                fontSize: 13,
                                color: Color(0xFF64748B),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final session = filtered[index];
                        return _buildSessionCard(session);
                      },
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildBatchFilterPills() {
    final batches = _availableBatches;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: batches.map((batch) {
          final isSelected = _selectedBatch == batch;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(batch),
              selected: isSelected,
              selectedColor: const Color(0xFF0284C7).withValues(alpha: 0.15),
              backgroundColor: Colors.white,
              labelStyle: TextStyle(
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                color: isSelected ? const Color(0xFF0284C7) : const Color(0xFF475569),
              ),
              side: BorderSide(
                color: isSelected ? const Color(0xFF0284C7) : AppTheme.border,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedBatch = batch);
                }
              },
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSummaryBanner(List<AttendanceSessionModel> sessions) {
    int totalLogged = sessions.length;
    int totalStudentsPresent = 0;
    int totalStudentsEnrolled = 0;
    for (final s in sessions) {
      totalStudentsPresent += s.presentCount;
      totalStudentsEnrolled += s.totalStudents;
    }
    final overallRate = totalStudentsEnrolled > 0
        ? ((totalStudentsPresent / totalStudentsEnrolled) * 100).round()
        : 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildSummaryStatItem(
            label: 'Total Sessions',
            value: '$totalLogged',
            icon: Icons.event_note_rounded,
            iconColor: const Color(0xFF0284C7),
          ),
          Container(width: 1, height: 36, color: AppTheme.border),
          _buildSummaryStatItem(
            label: 'Students Present',
            value: '$totalStudentsPresent',
            icon: Icons.people_outline_rounded,
            iconColor: const Color(0xFF10B981),
          ),
          Container(width: 1, height: 36, color: AppTheme.border),
          _buildSummaryStatItem(
            label: 'Avg Attendance',
            value: '$overallRate%',
            icon: Icons.analytics_outlined,
            iconColor: const Color(0xFF8B5CF6),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStatItem({
    required String label,
    required String value,
    required IconData icon,
    required Color iconColor,
  }) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: iconColor),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: Color(0xFF0F172A),
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: Color(0xFF64748B),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildSessionCard(AttendanceSessionModel session) {
    final title = RoutineHelper.lookupCourseTitle(session.courseCode);
    final batchText = session.batch.replaceAll('ICE-', 'Batch ');
    final dateFormatted = DateFormat('EEE, MMM d, yyyy').format(session.sessionDate);

    Color statusBg = const Color(0xFF10B981).withValues(alpha: 0.12);
    Color statusColor = const Color(0xFF059669);
    String statusLabel = session.status.toUpperCase();

    if (session.isCancelled) {
      statusBg = const Color(0xFFEF4444).withValues(alpha: 0.12);
      statusColor = const Color(0xFFDC2626);
      statusLabel = 'CANCELLED';
    } else if (session.isRescheduled) {
      statusBg = const Color(0xFFF59E0B).withValues(alpha: 0.15);
      statusColor = const Color(0xFFD97706);
      statusLabel = 'RESCHEDULED';
    }

    return InkWell(
      onTap: () => _showSessionDetails(session),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.02),
              blurRadius: 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row: Course Code, Batch, Status badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Text(
                        session.courseCode,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          batchText,
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF475569),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    statusLabel,
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w800,
                      color: statusColor,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Course Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 12.5,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 12),

            // Bottom row: Date & Attendance Rate Pill & Action
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_today_outlined, size: 13, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 6),
                    Text(
                      dateFormatted,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        session.formattedAttendanceRate,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right_rounded, size: 18, color: Color(0xFF94A3B8)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionDetailsModal extends StatefulWidget {
  final AttendanceSessionModel session;
  final AttendanceService attendanceService;
  final void Function(List<AttendanceRecordModel> currentRecords) onExportCsv;
  final VoidCallback onRecordUpdated;

  const _SessionDetailsModal({
    required this.session,
    required this.attendanceService,
    required this.onExportCsv,
    required this.onRecordUpdated,
  });

  @override
  State<_SessionDetailsModal> createState() => _SessionDetailsModalState();
}

class _SessionDetailsModalState extends State<_SessionDetailsModal> {
  late List<AttendanceRecordModel> _records;
  bool _isLoadingRoster = false;

  @override
  void initState() {
    super.initState();
    _records = List.from(widget.session.records);
    if (_records.isEmpty) {
      _fetchRoster();
    }
  }

  Future<void> _fetchRoster() async {
    setState(() => _isLoadingRoster = true);
    try {
      final list = await widget.attendanceService.getSessionRecords(widget.session.id);
      if (mounted) {
        setState(() {
          _records = list;
          _isLoadingRoster = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingRoster = false);
    }
  }

  Future<void> _toggleStudentStatus(AttendanceRecordModel record) async {
    final nextStatus = record.isPresent ? 'ABSENT' : 'PRESENT';
    final updated = record.copyWith(
      status: nextStatus,
      scannedAt: nextStatus == 'PRESENT' ? (record.scannedAt ?? DateTime.now()) : null,
    );

    setState(() {
      final idx = _records.indexWhere((r) => r.id == record.id);
      if (idx >= 0) {
        _records[idx] = updated;
      }
    });

    try {
      await widget.attendanceService.updateRecordStatus(
        recordId: record.id,
        status: nextStatus,
        scannedAt: updated.scannedAt,
      );
      widget.onRecordUpdated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${record.studentName} marked $nextStatus'),
            duration: const Duration(seconds: 2),
            backgroundColor: nextStatus == 'PRESENT' ? const Color(0xFF059669) : AppTheme.error,
          ),
        );
      }
    } catch (e) {
      // Revert if error
      setState(() {
        final idx = _records.indexWhere((r) => r.id == record.id);
        if (idx >= 0) {
          _records[idx] = record;
        }
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update status: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final title = RoutineHelper.lookupCourseTitle(session.courseCode);
    final batchText = session.batch.replaceAll('ICE-', 'Batch ');
    final dateFormatted = DateFormat('EEEE, MMMM d, yyyy').format(session.sessionDate);

    final presentCount = _records.where((r) => r.isPresent).length;
    final totalCount = _records.isNotEmpty ? _records.length : session.totalStudents;
    final ratePercent = totalCount > 0 ? ((presentCount / totalCount) * 100).round() : 0;

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              Center(
                child: Container(
                  margin: const EdgeInsets.only(top: 10, bottom: 8),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // Modal Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                session.courseCode,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w900,
                                  color: Color(0xFF0F172A),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF0284C7).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  batchText,
                                  style: const TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF0284C7),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 2),
                          Text(
                            title,
                            style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            dateFormatted,
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF94A3B8), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ElevatedButton.icon(
                          onPressed: () => widget.onExportCsv(_records),
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text('Export CSV', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF0284C7),
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            elevation: 0,
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Roster Summary Banner
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Text(
                      'Enrolled: $totalCount',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: Color(0xFF475569)),
                    ),
                    Text(
                      'Present: $presentCount',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF059669)),
                    ),
                    Text(
                      'Absent: ${totalCount - presentCount}',
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFFDC2626)),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981).withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '$ratePercent%',
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 12, color: Color(0xFF047857)),
                      ),
                    ),
                  ],
                ),
              ),

              // Student Roster Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Student Roster',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: Color(0xFF0F172A)),
                    ),
                    Text(
                      'Tap switch to toggle status',
                      style: TextStyle(fontSize: 11, color: Colors.grey[600], fontStyle: FontStyle.italic),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 6),

              // Student Roster List
              Expanded(
                child: _isLoadingRoster
                    ? const Center(child: CircularProgressIndicator())
                    : _records.isEmpty
                        ? const Center(
                            child: Text(
                              'No student records logged for this session.',
                              style: TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                            ),
                          )
                        : ListView.separated(
                            controller: scrollController,
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                            itemCount: _records.length,
                            separatorBuilder: (_, __) => const Divider(height: 1),
                            itemBuilder: (context, idx) {
                              final rec = _records[idx];
                              return _buildStudentRosterItem(rec);
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStudentRosterItem(AttendanceRecordModel rec) {
    final isPresent = rec.isPresent;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          // Roll Number Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: Text(
              rec.studentRoll,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: Color(0xFF0F172A),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // Student Name & Check-in Time
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  rec.studentName,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF0F172A),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Time: ${rec.checkInTimeFormatted}',
                  style: const TextStyle(
                    fontSize: 11,
                    color: Color(0xFF94A3B8),
                  ),
                ),
              ],
            ),
          ),

          // Status Badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: isPresent
                  ? const Color(0xFF10B981).withValues(alpha: 0.12)
                  : const Color(0xFFEF4444).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              isPresent ? 'PRESENT' : 'ABSENT',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w900,
                color: isPresent ? const Color(0xFF059669) : const Color(0xFFDC2626),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Manual Toggle Icon Button
          IconButton(
            icon: Icon(
              isPresent ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: isPresent ? const Color(0xFF10B981) : const Color(0xFFEF4444),
              size: 24,
            ),
            tooltip: isPresent ? 'Mark Absent' : 'Mark Present',
            onPressed: () => _toggleStudentStatus(rec),
          ),
        ],
      ),
    );
  }
}
