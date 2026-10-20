import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/app_theme.dart';
import '../models/department_routine_model.dart';
import '../services/auth_service.dart';
import '../services/db_service.dart';
import '../services/routine_service.dart';
import '../utils/routine_helper.dart';

class HomeNextClassCard extends StatefulWidget {
  final VoidCallback? onViewSchedule;

  const HomeNextClassCard({super.key, this.onViewSchedule});

  @override
  State<HomeNextClassCard> createState() => _HomeNextClassCardState();
}

class _HomeNextClassCardState extends State<HomeNextClassCard> {
  final RoutineService _routineService = RoutineService.instance;
  final DbService _dbService = DbService();

  List<DepartmentRoutineModel> _todayUpcoming = [];
  bool _isLoading = true;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _loadUpcomingClasses();
    // Periodically refresh every 60 seconds to update remaining minutes
    _timer = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) _loadUpcomingClasses();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _loadUpcomingClasses() async {
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final student = authService.studentProfile;
      final batchStr = student?.batchNumber?.toString() ?? '18';
      final canonicalBatch = RoutineHelper.normalizeBatch(batchStr);

      final batchNum = student?.batchNumber ?? int.tryParse(batchStr);
      DateTime? startDate;
      if (batchNum != null) {
        final batchModel = await _dbService.getBatchByNumber(batchNum);
        startDate = batchModel?.semesterStartDate;
      }

      final upcoming = await _routineService.getTodayUpcomingClasses(
        batch: canonicalBatch,
        semesterStartDate: startDate,
      );

      if (mounted) {
        setState(() {
          _todayUpcoming = upcoming;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final todayDayName = RoutineHelper.getDayNameFromWeekday(now.weekday);
    final isAcademicDay = RoutineHelper.academicDays.contains(todayDayName);

    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.primary,
          borderRadius: BorderRadius.circular(20),
        ),
        child: const Center(
          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
        ),
      );
    }

    // If it's a weekend (Thursday / Friday) or no classes are upcoming today:
    if (!isAcademicDay || _todayUpcoming.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0xFF334155)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 6,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.accent.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.today, color: AppTheme.accent, size: 14),
                      const SizedBox(width: 6),
                      Text(
                        todayDayName,
                        style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                if (widget.onViewSchedule != null)
                  TextButton(
                    onPressed: widget.onViewSchedule,
                    child: const Text('Full Timetable →', style: TextStyle(color: AppTheme.accent, fontSize: 12)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Row(
              children: [
                Text(
                  '🎉',
                  style: TextStyle(fontSize: 28),
                ),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'All classes finished for today 🎉',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'No remaining academic sessions scheduled for today. Enjoy your time or catch up on study notes!',
                        style: TextStyle(
                          color: Color(0xFF94A3B8),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    // Next class is the first element in the upcoming sorted list
    final nextClass = _todayUpcoming.first;
    final minutesUntil = RoutineHelper.getMinutesUntilClass(nextClass.startTime);
    final isOngoing = RoutineHelper.isClassOngoing(nextClass.startTime, nextClass.endTime);

    final String badgeText;
    final Color badgeColor;

    if (isOngoing) {
      badgeText = 'Class In Session Now 🔴';
      badgeColor = const Color(0xFFEF4444);
    } else if (minutesUntil <= 0) {
      badgeText = 'Starting Imminently ⏱️';
      badgeColor = const Color(0xFFF59E0B);
    } else if (minutesUntil < 60) {
      badgeText = 'Next Class in $minutesUntil mins';
      badgeColor = AppTheme.accent;
    } else {
      final hours = minutesUntil ~/ 60;
      final mins = minutesUntil % 60;
      badgeText = 'Next Class in ${hours}h ${mins}m';
      badgeColor = AppTheme.accent;
    }

    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: badgeColor.withValues(alpha: 0.5)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isOngoing ? Icons.play_circle_fill : Icons.access_time_filled,
                      color: badgeColor,
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      badgeText,
                      style: TextStyle(color: badgeColor, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (widget.onViewSchedule != null)
                InkWell(
                  onTap: widget.onViewSchedule,
                  child: const Text(
                    'Full Schedule →',
                    style: TextStyle(color: AppTheme.accent, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 18),

          // Course Code & Time Slot
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.start,
            spacing: 12,
            runSpacing: 8,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    nextClass.courseCode,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.3,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    RoutineHelper.formatTimeRange(nextClass.startTime, nextClass.endTime),
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                    maxLines: 1,
                  ),
                ],
              ),

              // Room Number Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.meeting_room, color: Colors.white, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      'Room ${nextClass.roomNumber ?? "TBA"}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(color: Color(0xFF334155), height: 1),
          const SizedBox(height: 14),

          // Teacher and Lab indicators
          Row(
            children: [
              const Icon(Icons.person, color: AppTheme.accent, size: 16),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  nextClass.teacherFullName != null && nextClass.teacherFullName!.isNotEmpty
                      ? (nextClass.teacherInitial != null && nextClass.teacherInitial!.isNotEmpty && nextClass.teacherFullName != nextClass.teacherInitial
                          ? '${nextClass.teacherFullName} [${nextClass.teacherInitial}]'
                          : nextClass.teacherFullName!)
                      : (nextClass.teacherInitial != null ? 'Faculty [${nextClass.teacherInitial}]' : 'Faculty TBA'),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (nextClass.isLab) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    'LAB',
                    style: TextStyle(color: Color(0xFFC4B5FD), fontWeight: FontWeight.bold, fontSize: 10),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
