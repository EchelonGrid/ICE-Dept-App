import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/department_routine_model.dart';
import '../../services/auth_service.dart';
import '../../services/routine_service.dart';
import '../../utils/routine_helper.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/profile_avatar_button.dart';
import '../../widgets/skeleton_loader.dart';
import 'teacher_qr_generator_screen.dart';

/// Official departmental calendar for the ICE department
const List<String> academicDays = ['Sat', 'Sun', 'Mon', 'Tue', 'Wed'];

class TeacherScheduleTab extends StatefulWidget {
  final DateTime? referenceDate;
  const TeacherScheduleTab({super.key, this.referenceDate});

  @override
  State<TeacherScheduleTab> createState() => _TeacherScheduleTabState();
}

class _TeacherScheduleTabState extends State<TeacherScheduleTab> {
  final RoutineService _routineService = RoutineService.instance;
  late String _selectedDay;
  bool _isTodayWeekend = false;
  String _todayActualDayName = '';
  List<DepartmentRoutineModel> _dayRoutines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _initAcademicDay();
    _loadSchedule();
  }

  void _initAcademicDay() {
    final now = widget.referenceDate ?? DateTime.now();
    final weekday = now.weekday; // 1=Mon, 2=Tue, 3=Wed, 4=Thu, 5=Fri, 6=Sat, 7=Sun

    _todayActualDayName = RoutineHelper.getDayNameFromWeekday(weekday);

    // Thursday (4) or Friday (5) is official departmental weekend
    if (weekday == DateTime.thursday || weekday == DateTime.friday) {
      _isTodayWeekend = true;
      _selectedDay = 'Sat';
    } else {
      _isTodayWeekend = false;
      switch (weekday) {
        case DateTime.saturday:
          _selectedDay = 'Sat';
          break;
        case DateTime.sunday:
          _selectedDay = 'Sun';
          break;
        case DateTime.monday:
          _selectedDay = 'Mon';
          break;
        case DateTime.tuesday:
          _selectedDay = 'Tue';
          break;
        case DateTime.wednesday:
          _selectedDay = 'Wed';
          break;
        default:
          _selectedDay = 'Sat';
      }
    }
  }

  String _mapShortDayToFull(String shortDay) {
    switch (shortDay) {
      case 'Sat':
        return 'Saturday';
      case 'Sun':
        return 'Sunday';
      case 'Mon':
        return 'Monday';
      case 'Tue':
        return 'Tuesday';
      case 'Wed':
        return 'Wednesday';
      default:
        return 'Saturday';
    }
  }

  Future<void> _loadSchedule() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final user = authService.currentUser;
      final teacherInitials = user?.initials ?? user?.displayInitials ?? 'MAH';
      final fullDay = _mapShortDayToFull(_selectedDay);

      final routines = await _routineService.getRoutinesForTeacher(
        teacherInitial: teacherInitials,
        dayOfWeek: fullDay,
      );

      if (mounted) {
        setState(() {
          _dayRoutines = routines;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final teacherInitials = user?.initials ?? user?.displayInitials ?? 'MAH';

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Faculty Timetable',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: AppTheme.textPrimary),
            ),
            Text(
              'Teacher: [$teacherInitials] • Sat – Wed Routine',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w500),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
            tooltip: 'Refresh Routine',
            onPressed: _loadSchedule,
          ),
          const ProfileAvatarButton(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadSchedule,
        child: Column(
          children: [
            // ================= 1. WEEKEND / OFF DAY BANNER =================
            if (_isTodayWeekend)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFEF3C7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFFDE68A)),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: const BoxDecoration(
                        color: Color(0xFFF59E0B),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.weekend_rounded, color: Colors.white, size: 14),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Weekend / Off Day',
                            style: TextStyle(
                              color: Color(0xFF92400E),
                              fontWeight: FontWeight.w800,
                              fontSize: 12.5,
                            ),
                          ),
                          Text(
                            _selectedDay == 'Sat'
                                ? 'Department is closed today ($_todayActualDayName). Displaying Saturday\'s timetable by default.'
                                : 'Department is closed today ($_todayActualDayName). Viewing ${_mapShortDayToFull(_selectedDay)}\'s timetable.',
                            style: const TextStyle(
                              color: Color(0xFFB45309),
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // ================= 2. ACADEMIC DAY TABS (SAT - WED) =================
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.02),
                    blurRadius: 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                children: academicDays.map((dayShort) {
                  final isSelected = _selectedDay == dayShort;
                  return Expanded(
                    child: InkWell(
                      onTap: () {
                        if (_selectedDay != dayShort) {
                          setState(() => _selectedDay = dayShort);
                          _loadSchedule();
                        }
                      },
                      borderRadius: BorderRadius.circular(10),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? AppTheme.primary : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: isSelected
                              ? [
                                  BoxShadow(
                                    color: AppTheme.primary.withValues(alpha: 0.25),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            dayShort,
                            style: TextStyle(
                              color: isSelected ? Colors.white : AppTheme.textSecondary,
                              fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),

            // ================= 3. DAY HEADING & STATS =================
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${_mapShortDayToFull(_selectedDay)} Schedule',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '${_dayRoutines.length} Assigned ${_dayRoutines.length == 1 ? "Slot" : "Slots"}',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 4),

            // ================= 4. ROUTINE LIST =================
            Expanded(
              child: _isLoading
                  ? SkeletonLoader.listSkeleton(count: 3)
                  : _dayRoutines.isEmpty
                      ? const EmptyStateView(
                          icon: Icons.event_available_outlined,
                          title: 'No Teaching Assigned',
                          description: 'You have no scheduled lectures or laboratory sessions for this selected day.',
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                          itemCount: _dayRoutines.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = _dayRoutines[index];
                            return _buildScheduleCard(item);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScheduleCard(DepartmentRoutineModel routine) {
    final courseTitle = routine.courseTitle;
    final timeStr = RoutineHelper.formatTimeRange(routine.startTime, routine.endTime);
    final room = routine.roomNumber?.isNotEmpty == true ? 'Room ${routine.roomNumber}' : 'Room TBA';
    final batchText = routine.batch.replaceAll('ICE-', 'Batch ');

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Course Code + Badges + Batch
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        routine.courseCode,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 17,
                          color: AppTheme.textPrimary,
                          letterSpacing: -0.3,
                        ),
                      ),
                      if (routine.isLab)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: const Color(0xFF8B5CF6).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            routine.weekParity.toLowerCase() == 'odd'
                                ? 'ODD WEEK LAB'
                                : routine.weekParity.toLowerCase() == 'even'
                                    ? 'EVEN WEEK LAB'
                                    : 'LAB SESSION',
                            style: const TextStyle(
                              color: Color(0xFF7C3AED),
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    batchText,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: AppTheme.accent,
                      fontSize: 11,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),

            // Course Title
            Text(
              courseTitle,
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondary,
              ),
            ),
            const SizedBox(height: 12),

            // Time and Room Details
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.schedule_rounded, size: 15, color: Color(0xFF0284C7)),
                  const SizedBox(width: 6),
                  Text(
                    timeStr,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Icon(Icons.room_rounded, size: 15, color: Color(0xFF64748B)),
                  const SizedBox(width: 4),
                  Text(
                    room,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF334155),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Attendance Action Launcher
            ElevatedButton.icon(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    fullscreenDialog: true,
                    builder: (_) => TeacherQRGeneratorScreen(
                      routine: routine.toRoutineModel(),
                    ),
                  ),
                );
              },
              icon: const Icon(Icons.qr_code_2_rounded, size: 18),
              label: const Text(
                'Launch QR Attendance',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 42),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Backward compatibility wrapper for existing imports
class TeacherRoutineScreen extends StatelessWidget {
  const TeacherRoutineScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const TeacherScheduleTab();
  }
}
