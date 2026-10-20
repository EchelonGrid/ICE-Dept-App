import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/department_routine_model.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../services/routine_service.dart';
import '../../utils/academic_progression_helper.dart';
import '../../utils/routine_helper.dart';
import '../../widgets/profile_avatar_button.dart';
import '../../widgets/skeleton_loader.dart';

class ScheduleTabScreen extends StatefulWidget {
  const ScheduleTabScreen({super.key});

  @override
  State<ScheduleTabScreen> createState() => _ScheduleTabScreenState();
}

class _ScheduleTabScreenState extends State<ScheduleTabScreen> {
  final RoutineService _routineService = RoutineService.instance;
  final DbService _dbService = DbService();

  String _selectedDay = 'Sunday';
  List<DepartmentRoutineModel> _dayRoutines = [];
  bool _isLoading = true;
  String _currentParity = 'odd';
  int _currentWeek = 1;
  DateTime? _semesterStartDate;

  @override
  void initState() {
    super.initState();
    _currentParity = RoutineHelper.getCurrentWeekParity();
    _currentWeek = RoutineHelper.getCurrentAcademicWeek();

    // Default to today's academic day if Sat-Wed, else Sunday
    final todayDayName = RoutineHelper.getDayNameFromWeekday(DateTime.now().weekday);
    if (RoutineHelper.academicDays.contains(todayDayName)) {
      _selectedDay = todayDayName;
    } else {
      _selectedDay = 'Sunday';
    }

    _fetchDaySchedule();
  }

  Future<void> _fetchDaySchedule() async {
    setState(() => _isLoading = true);

    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final student = authService.studentProfile;
      final batchStr = student?.batchNumber?.toString() ?? '18';
      final canonicalBatch = RoutineHelper.normalizeBatch(batchStr);

      // Query student's batch to get dynamic semester_start_date
      final batchNum = student?.batchNumber ?? int.tryParse(batchStr);
      if (batchNum != null) {
        final batchModel = await _dbService.getBatchByNumber(batchNum);
        if (batchModel?.semesterStartDate != null) {
          _semesterStartDate = batchModel!.semesterStartDate;
          _currentParity = AcademicProgressionHelper.calculateParity(_semesterStartDate!);
          _currentWeek = AcademicProgressionHelper.calculateAcademicWeek(_semesterStartDate!);
        }
      }

      final routines = await _routineService.getRoutinesForBatch(
        batch: canonicalBatch,
        dayOfWeek: _selectedDay,
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
    final student = authService.studentProfile;
    final batchStr = student?.batchNumber?.toString() ?? '18';
    final canonicalBatch = RoutineHelper.normalizeBatch(batchStr);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Academic Schedule',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            Text(
              '$canonicalBatch • Semester Routine',
              style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary),
            ),
          ],
        ),
        actions: const [
          ProfileAvatarButton(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _fetchDaySchedule,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Active Week & Parity Banner
              _buildAcademicWeekBanner(),

              // 2. Horizontal Day Selector (Sat - Wed)
              _buildDaySelector(),

              // 3. Class Cards List
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '$_selectedDay Schedule',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                        ),
                        Text(
                          '${_dayRoutines.length} Sessions',
                          style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    if (_isLoading)
                      SkeletonLoader.listSkeleton(count: 3)
                    else if (_dayRoutines.isEmpty)
                      _buildEmptyState(canonicalBatch)
                    else
                      ..._dayRoutines.map((routine) => _buildClassCard(routine)),
                  ],
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAcademicWeekBanner() {
    final isOdd = _currentParity == 'odd';

    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOdd
              ? [const Color(0xFF1E3A8A), const Color(0xFF0284C7)]
              : [const Color(0xFF065F46), const Color(0xFF059669)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: (isOdd ? const Color(0xFF0284C7) : const Color(0xFF059669)).withValues(alpha: 0.25),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.calendar_month, color: Colors.white, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current: Week $_currentWeek (${_currentParity.toUpperCase()} WEEK)',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                const SizedBox(height: 4),
                Text(
                  'Semester began Jul 15, 2026 • ${isOdd ? "Odd-week labs active" : "Even-week labs active"}',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12),
                  overflow: TextOverflow.ellipsis,
                  maxLines: 2,
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _currentParity.toUpperCase(),
              style: TextStyle(
                color: isOdd ? const Color(0xFF0284C7) : const Color(0xFF059669),
                fontWeight: FontWeight.w800,
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDaySelector() {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: RoutineHelper.academicDays.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final day = RoutineHelper.academicDays[index];
          final isSelected = day == _selectedDay;
          final shortName = day.substring(0, 3);

          return InkWell(
            onTap: () {
              setState(() => _selectedDay = day);
              _fetchDaySchedule();
            },
            borderRadius: BorderRadius.circular(24),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.accent : AppTheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: isSelected ? AppTheme.accent : AppTheme.border,
                ),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: AppTheme.accent.withValues(alpha: 0.3),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ]
                    : null,
              ),
              child: Center(
                child: Text(
                  shortName,
                  style: TextStyle(
                    color: isSelected ? Colors.white : AppTheme.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildClassCard(DepartmentRoutineModel routine) {
    final isActiveThisWeek = RoutineHelper.isSlotActiveForWeek(
      slotParity: routine.weekParity,
      startDate: _semesterStartDate,
    );
    final hasParityConstraint = routine.weekParity != 'all';

    final cardBorder = isActiveThisWeek && hasParityConstraint
        ? Border.all(color: AppTheme.accent, width: 1.8)
        : Border.all(color: AppTheme.border);

    return Opacity(
      opacity: isActiveThisWeek ? 1.0 : 0.45,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: cardBorder,
          boxShadow: AppTheme.softCardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Time & Badges Row
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.access_time_rounded, size: 16, color: AppTheme.accent),
                    const SizedBox(width: 6),
                    Text(
                      RoutineHelper.formatTimeRange(routine.startTime, routine.endTime),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                    ),
                  ],
                ),

                // Parity or Lab Status Badge
                if (hasParityConstraint)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: isActiveThisWeek
                          ? AppTheme.success.withValues(alpha: 0.12)
                          : AppTheme.textMuted.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isActiveThisWeek ? AppTheme.success : AppTheme.textMuted,
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      isActiveThisWeek
                          ? 'Active This Week (${routine.weekParity.toUpperCase()} Week Lab)'
                          : 'Inactive This Week (${routine.weekParity.toUpperCase()} Week Lab)',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: isActiveThisWeek ? AppTheme.success : AppTheme.textSecondary,
                      ),
                    ),
                  )
                else if (routine.isLab)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFF8B5CF6).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Lab Session (3h)',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Color(0xFF8B5CF6)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // Course Code & Room Badge
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 6,
              children: [
                Text(
                  routine.courseCode,
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppTheme.textPrimary),
                  overflow: TextOverflow.ellipsis,
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.meeting_room_outlined, size: 13, color: AppTheme.textSecondary),
                      const SizedBox(width: 4),
                      Text(
                        'Room ${routine.roomNumber ?? "TBA"}',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Teacher Name
            Row(
              children: [
                const Icon(Icons.person_outline, size: 15, color: AppTheme.textMuted),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    routine.teacherFullName != null && routine.teacherFullName!.isNotEmpty
                        ? (routine.teacherInitial != null && routine.teacherInitial!.isNotEmpty && routine.teacherFullName != routine.teacherInitial
                            ? '${routine.teacherFullName} [${routine.teacherInitial}]'
                            : routine.teacherFullName!)
                        : (routine.teacherInitial != null ? 'Faculty [${routine.teacherInitial}]' : 'Faculty TBA'),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(String canonicalBatch) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.event_busy_outlined, size: 48, color: AppTheme.textMuted.withValues(alpha: 0.5)),
            const SizedBox(height: 12),
            Text(
              'No Classes Scheduled on $_selectedDay',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              'No active timetable entries found for $canonicalBatch.',
              style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
