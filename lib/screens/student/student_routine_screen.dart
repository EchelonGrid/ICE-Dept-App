import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_time_helper.dart';
import '../../models/routine_model.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/profile_avatar_button.dart';

class StudentRoutineScreen extends StatefulWidget {
  const StudentRoutineScreen({super.key});

  @override
  State<StudentRoutineScreen> createState() => _StudentRoutineScreenState();
}

class _StudentRoutineScreenState extends State<StudentRoutineScreen> {
  final DbService _dbService = DbService();
  int _selectedDay = 1; // 1=Mon, ..., 5=Fri
  List<RoutineModel> _routines = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _selectedDay = DateTime.now().weekday <= 5 ? DateTime.now().weekday : 1;
    _fetchDayRoutine();
  }

  Future<void> _fetchDayRoutine() async {
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      final batchId = authService.studentProfile?.batchId;

      if (batchId != null) {
        final routines = await _dbService.getRoutinesForBatch(batchId, dayOfWeek: _selectedDay);
        if (mounted) {
          setState(() {
            _routines = routines;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Weekly Class Routine', style: TextStyle(fontWeight: FontWeight.bold)),
        actions: const [
          ProfileAvatarButton(),
        ],
      ),
      body: Column(
        children: [
          // Day selector pills
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: AppTheme.surface,
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  _buildDayPill(6, 'Sat'),
                  const SizedBox(width: 8),
                  _buildDayPill(7, 'Sun'),
                  const SizedBox(width: 8),
                  _buildDayPill(1, 'Mon'),
                  const SizedBox(width: 8),
                  _buildDayPill(2, 'Tue'),
                  const SizedBox(width: 8),
                  _buildDayPill(3, 'Wed'),
                  const SizedBox(width: 8),
                  _buildDayPill(4, 'Thu'),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          Expanded(
            child: _isLoading
                ? SkeletonLoader.listSkeleton(count: 3)
                : _routines.isEmpty
                    ? const EmptyStateView(
                        icon: Icons.event_busy_outlined,
                        title: 'No Classes Scheduled',
                        description: 'There are no scheduled lecture sessions for this day.',
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.all(16),
                        itemCount: _routines.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final item = _routines[index];
                          return Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: item.isCanceled
                                          ? AppTheme.error.withValues(alpha: 0.1)
                                          : AppTheme.primary.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Icon(
                                      item.isCanceled ? Icons.cancel_outlined : Icons.menu_book_outlined,
                                      color: item.isCanceled ? AppTheme.error : AppTheme.primary,
                                      size: 24,
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                item.courseName,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 16,
                                                  color: AppTheme.textPrimary,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (item.isCanceled) ...[
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.error.withValues(alpha: 0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text('CANCELED', style: TextStyle(color: AppTheme.error, fontSize: 10, fontWeight: FontWeight.bold)),
                                              ),
                                            ],
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Wrap(
                                          spacing: 12,
                                          runSpacing: 4,
                                          crossAxisAlignment: WrapCrossAlignment.center,
                                          children: [
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.schedule, size: 14, color: AppTheme.textMuted),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${DateTimeHelper.formatTime(item.startTime)} - ${DateTimeHelper.formatTime(item.endTime)}',
                                                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                                ),
                                              ],
                                            ),
                                            Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(Icons.room, size: 14, color: AppTheme.textMuted),
                                                const SizedBox(width: 4),
                                                Text(
                                                  item.roomNumber,
                                                  style: const TextStyle(fontSize: 13, color: AppTheme.textSecondary),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                        if (item.teacherName != null) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'Instructor: ${item.teacherName}',
                                            style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                                          ),
                                        ],
                                      ],
                                    ),
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

  Widget _buildDayPill(int dayNumber, String dayShort) {
    final isSelected = _selectedDay == dayNumber;
    return InkWell(
      onTap: () {
        setState(() => _selectedDay = dayNumber);
        _fetchDayRoutine();
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          dayShort,
          style: TextStyle(
            color: isSelected ? Colors.white : AppTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}
