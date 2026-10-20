import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../models/attendance_model.dart';
import '../../models/routine_model.dart';
import '../../services/attendance_service.dart';
import '../../services/qrcode_service.dart';
import '../../widgets/app_button.dart';
import 'teacher_attendance_list_screen.dart';

class TeacherQRGeneratorScreen extends StatefulWidget {
  final RoutineModel routine;

  const TeacherQRGeneratorScreen({super.key, required this.routine});

  @override
  State<TeacherQRGeneratorScreen> createState() => _TeacherQRGeneratorScreenState();
}

class _TeacherQRGeneratorScreenState extends State<TeacherQRGeneratorScreen> {
  late DynamicQRSession _qrSession;
  final AttendanceService _attendanceService = AttendanceService();
  List<AttendanceModel> _attendances = [];
  bool _isRefreshingList = false;

  @override
  void initState() {
    super.initState();
    _qrSession = DynamicQRSession(
      classId: widget.routine.id,
      courseName: widget.routine.courseName,
    );
    _loadLiveAttendance();
  }

  @override
  void dispose() {
    _qrSession.dispose();
    super.dispose();
  }

  Future<void> _loadLiveAttendance() async {
    if (!mounted) return;
    setState(() => _isRefreshingList = true);
    try {
      final records = await _attendanceService.getClassAttendance(widget.routine.id);
      if (mounted) {
        setState(() {
          _attendances = records;
          _isRefreshingList = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isRefreshingList = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.routine.courseName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('Batch ${widget.routine.batchNumber ?? ''} • Live Anti-Proxy QR', style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.checklist_rtl, color: AppTheme.accent),
            tooltip: 'Manual Attendance Fallback',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TeacherAttendanceListScreen(routine: widget.routine),
                ),
              ).then((_) => _loadLiveAttendance());
            },
          ),
        ],
      ),
      body: ListenableBuilder(
        listenable: _qrSession,
        builder: (context, _) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: Column(
                  children: [
                    // QR Card Container
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppTheme.border),
                        boxShadow: AppTheme.softCardShadow,
                      ),
                      child: Column(
                        children: [
                          // 10-Second Refresh Indicator Header
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    width: 10,
                                    height: 10,
                                    decoration: const BoxDecoration(
                                      color: AppTheme.success,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Anti-Proxy Active',
                                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                                  ),
                                ],
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: AppTheme.accent.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'Refreshes in ${_qrSession.secondsRemaining}s',
                                  style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),

                          // Dynamic Linear Progress Bar for 10s countdown
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _qrSession.progressFraction,
                              backgroundColor: const Color(0xFFE2E8F0),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _qrSession.secondsRemaining <= 3 ? AppTheme.error : AppTheme.accent,
                              ),
                              minHeight: 6,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Dynamic QR Code Display
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: const Color(0xFFE2E8F0), width: 1.5),
                            ),
                            child: QrImageView(
                              data: _qrSession.currentPayload,
                              version: QrVersions.auto,
                              size: 240,
                              backgroundColor: Colors.white,
                              errorCorrectionLevel: QrErrorCorrectLevel.M,
                            ),
                          ),
                          const SizedBox(height: 18),
                          const Text(
                            'Display this code on the projector or screen.',
                            style: TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Scanned Count & Manual Fallback Button
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        color: AppTheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${_attendances.length} Students Present',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              const Text('Scanned live via app', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                            ],
                          ),
                          IconButton(
                            icon: _isRefreshingList
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accent)),
                                  )
                                : const Icon(Icons.refresh, color: AppTheme.accent),
                            onPressed: _isRefreshingList ? null : _loadLiveAttendance,
                            tooltip: 'Refresh Scanned Count',
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    AppButton(
                      text: 'Manual Checklist Fallback',
                      isOutlined: true,
                      icon: Icons.checklist,
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => TeacherAttendanceListScreen(routine: widget.routine),
                          ),
                        ).then((_) => _loadLiveAttendance());
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
