import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/department_routine_model.dart';
import '../utils/routine_helper.dart';

class RoutineService {
  static final RoutineService instance = RoutineService._internal();
  RoutineService._internal();

  SupabaseClient get _client => Supabase.instance.client;

  // In-memory cache of faculty directory { initial -> fullName }
  Map<String, String>? _facultyCache;

  /// Expose fallback map for routine lookup and fallback resolution
  static Map<String, String> get fallbackFacultyMap => _fallbackFacultyMap;

  /// Fetches the faculty directory from public.faculty_directory and caches it
  Future<Map<String, String>> getFacultyDirectory({bool forceRefresh = false}) async {
    if (_facultyCache != null && !forceRefresh) {
      return _facultyCache!;
    }

    try {
      final data = await _client
          .from('faculty_directory')
          .select('initial, full_name, department');

      final Map<String, String> map = {};
      for (final row in data) {
        final initial = (row['initial'] as String? ?? '').trim().toUpperCase();
        final fullName = row['full_name'] as String? ?? '';
        if (initial.isNotEmpty) {
          map[initial] = fullName;
        }
      }
      _facultyCache = map;
      return map;
    } catch (_) {
      return _facultyCache ?? _fallbackFacultyMap;
    }
  }

  /// Resolves full name for a teacher initial
  Future<String?> resolveTeacherFullName(String? initial) async {
    if (initial == null || initial.trim().isEmpty) return null;
    final cleanInit = initial.trim().toUpperCase();
    try {
      final directory = await getFacultyDirectory();
      return directory[cleanInit] ?? _fallbackFacultyMap[cleanInit] ?? initial;
    } catch (_) {
      return _fallbackFacultyMap[cleanInit] ?? initial;
    }
  }

  /// Fetches routines for a normalized batch (e.g. 'ICE-18'), optionally filtered by day of week.
  Future<List<DepartmentRoutineModel>> getRoutinesForBatch({
    required String batch,
    String? dayOfWeek,
  }) async {
    final normBatch = RoutineHelper.normalizeBatch(batch);
    final facultyMap = await getFacultyDirectory();

    // Extract digits to support 'Batch 21' and 'ICE-21'
    final digits = RegExp(r'\d+').firstMatch(batch)?.group(0);
    final batchFilter = <String>{
      batch,
      normBatch,
      if (digits != null) 'Batch $digits',
      if (digits != null) 'ICE-$digits',
    }.toList();

    var query = _client
        .from('department_routines')
        .select()
        .inFilter('batch', batchFilter);

    if (dayOfWeek != null && dayOfWeek.isNotEmpty) {
      final normalizedDay = RoutineHelper.normalizeDayName(dayOfWeek);
      query = query.eq('day_of_week', normalizedDay);
    }

    final data = await query.order('start_time', ascending: true);

    return (data as List).map((row) {
      final model = DepartmentRoutineModel.fromJson(row);
      final initial = (model.teacherInitial ?? '').trim().toUpperCase();
      final fullName = facultyMap[initial] ?? _fallbackFacultyMap[initial] ?? model.teacherInitial;
      return model.copyWith(teacherFullName: fullName);
    }).toList();
  }

  /// Fetches all classes for a batch for today that have not finished yet (end_time > currentTime)
  Future<List<DepartmentRoutineModel>> getTodayUpcomingClasses({
    required String batch,
    DateTime? referenceDate,
    DateTime? semesterStartDate,
  }) async {
    final now = referenceDate ?? DateTime.now();
    final dayName = RoutineHelper.getDayNameFromWeekday(now.weekday);
    final currentTimeStr =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}:${now.second.toString().padLeft(2, '0')}';

    final routines = await getRoutinesForBatch(batch: batch, dayOfWeek: dayName);

    // Filter routines whose end_time is strictly after currentTime and active for this week parity
    final upcoming = routines.where((r) {
      final endTimeComparable = r.endTime.padRight(8, ':00');
      final isUpcomingTime = endTimeComparable.compareTo(currentTimeStr) > 0;
      final isActiveWeek = RoutineHelper.isSlotActiveForWeek(
        slotParity: r.weekParity,
        startDate: semesterStartDate,
        referenceDate: now,
      );
      return isUpcomingTime && isActiveWeek;
    }).toList();

    return upcoming;
  }

  /// Bulk publishes routines into public.department_routines
  Future<void> publishRoutines({
    required List<DepartmentRoutineModel> routines,
    bool clearExistingBatchRoutines = false,
  }) async {
    if (routines.isEmpty) return;

    if (clearExistingBatchRoutines) {
      final batches = routines.map((r) => r.batch).toSet();
      for (final b in batches) {
        await _client.from('department_routines').delete().eq('batch', b);
      }
    }

    final payload = routines.map((r) => r.toJson(includeId: false)).toList();
    await _client.from('department_routines').insert(payload);
  }

  /// Deletes a specific routine entry by ID
  Future<void> deleteRoutine(String routineId) async {
    await _client.from('department_routines').delete().eq('id', routineId);
  }

  /// Official fallback routine schedule for Prof. Dr. Md. Anwar Hossain (MAH)
  static final List<DepartmentRoutineModel> fallbackMAHRoutines = [
    DepartmentRoutineModel(
      id: 'mah-sat-1',
      batch: 'ICE-18',
      dayOfWeek: 'Saturday',
      startTime: '14:00:00',
      endTime: '15:00:00',
      courseCode: 'ICE-2202',
      teacherInitial: 'MAH',
      roomNumber: '921',
      isLab: false,
      weekParity: 'all',
      teacherFullName: 'Prof. Dr. Md. Anwar Hossain',
    ),
    DepartmentRoutineModel(
      id: 'mah-sun-1',
      batch: 'ICE-14',
      dayOfWeek: 'Sunday',
      startTime: '11:00:00',
      endTime: '12:00:00',
      courseCode: 'ICE-4117',
      teacherInitial: 'MAH',
      roomNumber: '904',
      isLab: true,
      weekParity: 'odd',
      teacherFullName: 'Prof. Dr. Md. Anwar Hossain',
    ),
    DepartmentRoutineModel(
      id: 'mah-sun-2',
      batch: 'ICE-16',
      dayOfWeek: 'Sunday',
      startTime: '14:00:00',
      endTime: '15:00:00',
      courseCode: 'ICE-1106',
      teacherInitial: 'MAH',
      roomNumber: '920',
      isLab: false,
      weekParity: 'all',
      teacherFullName: 'Prof. Dr. Md. Anwar Hossain',
    ),
    DepartmentRoutineModel(
      id: 'mah-mon-1',
      batch: 'ICE-18',
      dayOfWeek: 'Monday',
      startTime: '11:00:00',
      endTime: '12:00:00',
      courseCode: 'ICE-2202',
      teacherInitial: 'MAH',
      roomNumber: '903',
      isLab: false,
      weekParity: 'all',
      teacherFullName: 'Prof. Dr. Md. Anwar Hossain',
    ),
    DepartmentRoutineModel(
      id: 'mah-tue-1',
      batch: 'ICE-14',
      dayOfWeek: 'Tuesday',
      startTime: '11:00:00',
      endTime: '13:00:00',
      courseCode: 'ICE-4116',
      teacherInitial: 'MAH',
      roomNumber: '904',
      isLab: false,
      weekParity: 'all',
      teacherFullName: 'Prof. Dr. Md. Anwar Hossain',
    ),
    DepartmentRoutineModel(
      id: 'mah-tue-2',
      batch: 'ICE-18',
      dayOfWeek: 'Tuesday',
      startTime: '14:00:00',
      endTime: '16:00:00',
      courseCode: 'ICE-2202',
      teacherInitial: 'MAH',
      roomNumber: '905',
      isLab: true,
      weekParity: 'all',
      teacherFullName: 'Prof. Dr. Md. Anwar Hossain',
    ),
    DepartmentRoutineModel(
      id: 'mah-wed-1',
      batch: 'ICE-14',
      dayOfWeek: 'Wednesday',
      startTime: '09:00:00',
      endTime: '10:00:00',
      courseCode: 'ICE-4116',
      teacherInitial: 'MAH',
      roomNumber: '904',
      isLab: false,
      weekParity: 'all',
      teacherFullName: 'Prof. Dr. Md. Anwar Hossain',
    ),
  ];

  /// Fetches routines assigned to a teacher by initial (e.g. 'MAH'), optionally filtered by day of week.
  Future<List<DepartmentRoutineModel>> getRoutinesForTeacher({
    required String teacherInitial,
    String? dayOfWeek,
  }) async {
    final cleanInit = teacherInitial.trim().toUpperCase();
    final facultyMap = await getFacultyDirectory();
    final normalizedDay = dayOfWeek != null && dayOfWeek.isNotEmpty
        ? RoutineHelper.normalizeDayName(dayOfWeek)
        : null;

    try {
      var query = _client
          .from('department_routines')
          .select()
          .ilike('teacher_initial', cleanInit);

      if (normalizedDay != null) {
        query = query.eq('day_of_week', normalizedDay);
      }

      final data = await query.order('start_time', ascending: true);
      final list = (data as List).map((row) {
        final model = DepartmentRoutineModel.fromJson(row);
        final initial = (model.teacherInitial ?? '').trim().toUpperCase();
        final fullName = facultyMap[initial] ?? _fallbackFacultyMap[initial] ?? model.teacherInitial;
        return model.copyWith(teacherFullName: fullName);
      }).toList();

      if (list.isNotEmpty) {
        return list;
      }
    } catch (_) {}

    // Fallback if empty or database disconnected
    if (cleanInit == 'MAH') {
      if (normalizedDay != null) {
        return fallbackMAHRoutines
            .where((r) => RoutineHelper.normalizeDayName(r.dayOfWeek).toLowerCase() == normalizedDay.toLowerCase())
            .toList();
      }
      return List<DepartmentRoutineModel>.from(fallbackMAHRoutines);
    }

    return [];
  }

  /// Fallback initial to faculty name dictionary in case network fails
  static const Map<String, String> _fallbackFacultyMap = {
    'MAH': 'Prof. Dr. Md. Anwar Hossain',
    'MSH': 'Prof. Dr. Md. Sarwar Hosain',
    'MOF': 'Prof. Dr. Md. Omar Faruk',
    'MIH': 'Dr. Md. Imran Hossain',
    'TNT': 'Taskin Noor Turna',
    'TD': 'Tarun Debnath',
    'AM': 'Akif Mahdi',
    'MAR': 'Dr. Md. Azizur Rahman',
    'MIK': 'Md. Ibrahim Khalil',
    'MKIC': 'Prof. Dr. Mir Khaled Iqbal Chowdhury',
    'KK': 'Prof. Dr. Kamruzzaman Khan',
    'SS': 'Soma Saha',
    'DAF': 'Dr. A. F. M. Zainul Abadin',
  };
}
