import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/attendance_model.dart';
import '../models/attendance_record_model.dart';
import '../models/attendance_session_model.dart';
import 'supabase_service.dart';

class AttendanceService {
  SupabaseClient get _client => SupabaseService.instance.client;

  /// Submits attendance via scanned QR code token to the backend RPC
  Future<Map<String, dynamic>> submitQRAttendance({
    required String classId,
    required int qrTimestamp,
    required String qrToken,
  }) async {
    final response = await _client.rpc(
      'mark_qr_attendance',
      params: {
        'p_class_id': classId,
        'p_qr_timestamp': qrTimestamp,
        'p_qr_token': qrToken,
      },
    );

    if (response is Map) {
      return Map<String, dynamic>.from(response);
    }
    return {'success': false, 'message': 'Unknown response format'};
  }

  /// Teacher manual marking fallback
  Future<void> markAttendanceManually({
    required String classId,
    required String studentId,
    required String status,
    DateTime? date,
  }) async {
    final effectiveDate = date ?? DateTime.now();
    final dateStr =
        "${effectiveDate.year.toString().padLeft(4, '0')}-${effectiveDate.month.toString().padLeft(2, '0')}-${effectiveDate.day.toString().padLeft(2, '0')}";

    await _client.from('attendance').upsert(
      {
        'class_id': classId,
        'student_id': studentId,
        'date': dateStr,
        'status': status,
      },
      onConflict: 'class_id,student_id,date',
    );
  }

  /// Fetch attendance list for a specific class & date
  Future<List<AttendanceModel>> getClassAttendance(String classId, {DateTime? date}) async {
    final effectiveDate = date ?? DateTime.now();
    final dateStr =
        "${effectiveDate.year.toString().padLeft(4, '0')}-${effectiveDate.month.toString().padLeft(2, '0')}-${effectiveDate.day.toString().padLeft(2, '0')}";

    final response = await _client
        .from('attendance')
        .select('*, users(name), class_routine(course_name)')
        .eq('class_id', classId)
        .eq('date', dateStr);

    return (response as List).map((json) => AttendanceModel.fromJson(json)).toList();
  }

  /// Fetch personal attendance records for a student
  Future<List<AttendanceModel>> getStudentAttendanceHistory(String studentId) async {
    final response = await _client
        .from('attendance')
        .select('*, class_routine(course_name, room_number)')
        .eq('student_id', studentId)
        .order('date', ascending: false);

    return (response as List).map((json) => AttendanceModel.fromJson(json)).toList();
  }

  /// Fetches recent attendance logs / records across classes for dashboard display
  Future<List<Map<String, dynamic>>> getRecentAttendanceLogs({int limit = 5}) async {
    try {
      // First attempt to query structured attendance_sessions with attendance_records
      final sessionData = await _client
          .from('attendance_sessions')
          .select('*, attendance_records(*)')
          .order('session_date', ascending: false)
          .limit(limit);

      if (sessionData.isNotEmpty) {
        final list = (sessionData as List).map((row) {
          final session = AttendanceSessionModel.fromJson(row as Map<String, dynamic>);
          return {
            'session_id': session.id,
            'course_code': session.courseCode,
            'course_name': session.courseCode,
            'batch': session.batch,
            'date': "${session.sessionDate.year}-${session.sessionDate.month.toString().padLeft(2, '0')}-${session.sessionDate.day.toString().padLeft(2, '0')}",
            'present_count': session.presentCount,
            'total_students': session.totalStudents,
            'status': session.status,
            'is_lab': session.courseCode.toLowerCase().contains('lab') ||
                session.courseCode.endsWith('7') ||
                session.courseCode.endsWith('6'),
          };
        }).toList();
        return list;
      }

      final response = await _client
          .from('attendance')
          .select('*, users(name), class_routine(course_name, room_number, batch)')
          .order('date', ascending: false)
          .limit(limit);

      return List<Map<String, dynamic>>.from(response as List);
    } catch (_) {
      return [];
    }
  }

  // ==================== ATTENDANCE SESSIONS & ROSTER ====================

  /// Fetches all past attendance sessions from public.attendance_sessions
  Future<List<AttendanceSessionModel>> getAttendanceSessions({
    String? teacherInitial,
    String? batch,
  }) async {
    try {
      var query = _client.from('attendance_sessions').select('*, attendance_records(*)');
      if (teacherInitial != null && teacherInitial.isNotEmpty) {
        query = query.ilike('teacher_initial', teacherInitial.trim());
      }
      if (batch != null && batch.isNotEmpty && batch.toLowerCase() != 'all') {
        final digits = RegExp(r'\d+').firstMatch(batch)?.group(0);
        final batchFilter = <String>{
          batch,
          if (digits != null) 'ICE-$digits',
          if (digits != null) 'Batch $digits',
        }.toList();
        query = query.inFilter('batch', batchFilter);
      }

      final data = await query.order('session_date', ascending: false);
      final list = (data as List).map((row) {
        return AttendanceSessionModel.fromJson(row as Map<String, dynamic>);
      }).toList();

      if (list.isNotEmpty) return list;
    } catch (_) {}

    return _filterFallbackSessions(teacherInitial: teacherInitial, batch: batch);
  }

  /// Fetches student attendance roster for a specific session
  Future<List<AttendanceRecordModel>> getSessionRecords(String sessionId) async {
    try {
      final data = await _client
          .from('attendance_records')
          .select()
          .eq('session_id', sessionId)
          .order('student_roll', ascending: true);

      return (data as List)
          .map((row) => AttendanceRecordModel.fromJson(row as Map<String, dynamic>))
          .toList();
    } catch (_) {
      final session = _fallbackSessions.firstWhere(
        (s) => s.id == sessionId,
        orElse: () => _fallbackSessions.first,
      );
      return session.records;
    }
  }

  /// Toggles or updates student attendance status in attendance_records
  Future<void> updateRecordStatus({
    required String recordId,
    required String status,
    DateTime? scannedAt,
  }) async {
    final cleanStatus = status.toUpperCase();
    final effectiveScannedAt = cleanStatus == 'PRESENT'
        ? (scannedAt ?? DateTime.now())
        : null;

    try {
      await _client
          .from('attendance_records')
          .update({
            'status': cleanStatus,
            'scanned_at': effectiveScannedAt?.toIso8601String(),
          })
          .eq('id', recordId);
    } catch (_) {
      // In-memory update for fallback mode
      for (final s in _fallbackSessions) {
        final idx = s.records.indexWhere((r) => r.id == recordId);
        if (idx >= 0) {
          final old = s.records[idx];
          s.records[idx] = old.copyWith(
            status: cleanStatus,
            scannedAt: effectiveScannedAt,
            clearScannedAt: effectiveScannedAt == null,
          );
          break;
        }
      }
    }
  }

  /// Records a session status (e.g. CANCELLED, RESCHEDULED, ACTIVE, COMPLETED)
  Future<Map<String, dynamic>> recordSessionStatus({
    required String courseCode,
    required String batch,
    required String teacherInitial,
    required String status,
    DateTime? sessionDate,
    String? startTime,
  }) async {
    final effectiveDate = sessionDate ?? DateTime.now();
    final dateStr =
        "${effectiveDate.year.toString().padLeft(4, '0')}-${effectiveDate.month.toString().padLeft(2, '0')}-${effectiveDate.day.toString().padLeft(2, '0')}";

    try {
      final existing = await _client
          .from('attendance_sessions')
          .select('id')
          .ilike('teacher_initial', teacherInitial.trim())
          .eq('course_code', courseCode.trim())
          .eq('batch', batch.trim())
          .eq('session_date', dateStr)
          .maybeSingle();

      if (existing != null) {
        final response = await _client
            .from('attendance_sessions')
            .update({
              'status': status.toUpperCase(),
              if (startTime != null) 'start_time': startTime,
            })
            .eq('id', existing['id'])
            .select()
            .single();
        return Map<String, dynamic>.from(response);
      } else {
        final response = await _client
            .from('attendance_sessions')
            .insert({
              'course_code': courseCode.trim(),
              'batch': batch.trim(),
              'teacher_initial': teacherInitial.trim().toUpperCase(),
              'session_date': dateStr,
              if (startTime != null) 'start_time': startTime,
              'status': status.toUpperCase(),
            })
            .select()
            .single();

        return Map<String, dynamic>.from(response);
      }
    } catch (_) {
      return {
        'id': 'local-${DateTime.now().millisecondsSinceEpoch}',
        'course_code': courseCode,
        'batch': batch,
        'teacher_initial': teacherInitial,
        'session_date': dateStr,
        'status': status.toUpperCase(),
      };
    }
  }

  /// Fetches session statuses recorded today for this teacher (both CANCELLED and RESCHEDULED)
  Future<Map<String, String>> getTodaySessionStatuses({
    required String teacherInitial,
    DateTime? date,
  }) async {
    final effectiveDate = date ?? DateTime.now();
    final dateStr =
        "${effectiveDate.year.toString().padLeft(4, '0')}-${effectiveDate.month.toString().padLeft(2, '0')}-${effectiveDate.day.toString().padLeft(2, '0')}";

    try {
      final response = await _client
          .from('attendance_sessions')
          .select('course_code, batch, status')
          .ilike('teacher_initial', teacherInitial.trim())
          .eq('session_date', dateStr);

      final Map<String, String> statuses = {};
      for (final row in response as List) {
        final code = (row['course_code'] as String? ?? '').trim();
        final batch = (row['batch'] as String? ?? '').trim();
        final status = (row['status'] as String? ?? '').trim().toUpperCase();
        if (code.isNotEmpty && batch.isNotEmpty) {
          statuses['$code-$batch'] = status;
          statuses[code] = status;
        }
      }
      return statuses;
    } catch (_) {
      return {};
    }
  }

  /// Gets list of course codes marked as cancelled today for this teacher
  Future<List<String>> getCancelledClassCodesForToday({
    required String teacherInitial,
    DateTime? date,
  }) async {
    final map = await getTodaySessionStatuses(teacherInitial: teacherInitial, date: date);
    return map.entries
        .where((e) => e.value == 'CANCELLED')
        .map((e) => e.key)
        .toList();
  }

  // ==================== FALLBACK SEED DATA ====================

  static final List<AttendanceSessionModel> _fallbackSessions = [
    AttendanceSessionModel(
      id: 'sess-mah-1',
      courseCode: 'ICE-2202',
      batch: 'ICE-18',
      teacherInitial: 'MAH',
      sessionDate: DateTime(2026, 9, 4),
      startTime: '14:00:00',
      status: 'COMPLETED',
      totalStudents: 6,
      presentCount: 5,
      records: [
        AttendanceRecordModel(
          id: 'rec-1',
          sessionId: 'sess-mah-1',
          studentRoll: '2108001',
          studentName: 'Alex Rahman',
          status: 'PRESENT',
          scannedAt: DateTime(2026, 9, 4, 14, 2, 15),
        ),
        AttendanceRecordModel(
          id: 'rec-2',
          sessionId: 'sess-mah-1',
          studentRoll: '2108002',
          studentName: 'Sarah Khan',
          status: 'PRESENT',
          scannedAt: DateTime(2026, 9, 4, 14, 3, 10),
        ),
        AttendanceRecordModel(
          id: 'rec-3',
          sessionId: 'sess-mah-1',
          studentRoll: '2108003',
          studentName: 'Tanvir Hossain',
          status: 'ABSENT',
          scannedAt: null,
        ),
        AttendanceRecordModel(
          id: 'rec-4',
          sessionId: 'sess-mah-1',
          studentRoll: '2108004',
          studentName: 'Sabbir Ahmed',
          status: 'PRESENT',
          scannedAt: DateTime(2026, 9, 4, 14, 4, 0),
        ),
        AttendanceRecordModel(
          id: 'rec-5',
          sessionId: 'sess-mah-1',
          studentRoll: '2108005',
          studentName: 'Nusrat Jahan',
          status: 'PRESENT',
          scannedAt: DateTime(2026, 9, 4, 14, 4, 20),
        ),
        AttendanceRecordModel(
          id: 'rec-6',
          sessionId: 'sess-mah-1',
          studentRoll: '2108011',
          studentName: 'Nadim Mostafa',
          status: 'PRESENT',
          scannedAt: DateTime(2026, 9, 4, 14, 5, 0),
        ),
      ],
    ),
    AttendanceSessionModel(
      id: 'sess-mah-2',
      courseCode: 'ICE-4116',
      batch: 'ICE-14',
      teacherInitial: 'MAH',
      sessionDate: DateTime(2026, 9, 1),
      startTime: '11:00:00',
      status: 'COMPLETED',
      totalStudents: 4,
      presentCount: 3,
      records: [
        AttendanceRecordModel(
          id: 'rec-7',
          sessionId: 'sess-mah-2',
          studentRoll: '1908001',
          studentName: 'Fahim Shakil',
          status: 'PRESENT',
          scannedAt: DateTime(2026, 9, 1, 11, 2, 0),
        ),
        AttendanceRecordModel(
          id: 'rec-8',
          sessionId: 'sess-mah-2',
          studentRoll: '1908002',
          studentName: 'Farhana Yasmin',
          status: 'PRESENT',
          scannedAt: DateTime(2026, 9, 1, 11, 3, 0),
        ),
        AttendanceRecordModel(
          id: 'rec-9',
          sessionId: 'sess-mah-2',
          studentRoll: '1908003',
          studentName: 'Rashedul Islam',
          status: 'PRESENT',
          scannedAt: DateTime(2026, 9, 1, 11, 4, 0),
        ),
        AttendanceRecordModel(
          id: 'rec-10',
          sessionId: 'sess-mah-2',
          studentRoll: '1908004',
          studentName: 'Mehedi Hasan',
          status: 'ABSENT',
          scannedAt: null,
        ),
      ],
    ),
    AttendanceSessionModel(
      id: 'sess-mah-3',
      courseCode: 'ICE-4117',
      batch: 'ICE-14',
      teacherInitial: 'MAH',
      sessionDate: DateTime(2026, 8, 30),
      startTime: '11:00:00',
      status: 'COMPLETED',
      totalStudents: 4,
      presentCount: 4,
      records: [
        AttendanceRecordModel(
          id: 'rec-11',
          sessionId: 'sess-mah-3',
          studentRoll: '1908001',
          studentName: 'Fahim Shakil',
          status: 'PRESENT',
          scannedAt: DateTime(2026, 8, 30, 11, 2, 0),
        ),
        AttendanceRecordModel(
          id: 'rec-12',
          sessionId: 'sess-mah-3',
          studentRoll: '1908002',
          studentName: 'Farhana Yasmin',
          status: 'PRESENT',
          scannedAt: DateTime(2026, 8, 30, 11, 3, 0),
        ),
        AttendanceRecordModel(
          id: 'rec-13',
          sessionId: 'sess-mah-3',
          studentRoll: '1908003',
          studentName: 'Rashedul Islam',
          status: 'PRESENT',
          scannedAt: DateTime(2026, 8, 30, 11, 4, 0),
        ),
        AttendanceRecordModel(
          id: 'rec-14',
          sessionId: 'sess-mah-3',
          studentRoll: '1908004',
          studentName: 'Mehedi Hasan',
          status: 'PRESENT',
          scannedAt: DateTime(2026, 8, 30, 11, 5, 0),
        ),
      ],
    ),
  ];

  static List<AttendanceSessionModel> _filterFallbackSessions({
    String? teacherInitial,
    String? batch,
  }) {
    var list = _fallbackSessions;
    if (teacherInitial != null && teacherInitial.isNotEmpty) {
      list = list.where((s) => s.teacherInitial.toLowerCase() == teacherInitial.toLowerCase()).toList();
    }
    if (batch != null && batch.isNotEmpty && batch.toLowerCase() != 'all') {
      final digits = RegExp(r'\d+').firstMatch(batch)?.group(0);
      list = list.where((s) {
        if (s.batch.toLowerCase() == batch.toLowerCase()) return true;
        if (digits != null && s.batch.contains(digits)) return true;
        return false;
      }).toList();
    }
    return list;
  }
}
