import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import '../models/batch_model.dart';
import '../models/user_model.dart';
import '../models/student_profile_model.dart';
import '../models/routine_model.dart';
import '../models/notice_model.dart';
import '../models/department_notice_model.dart';
import '../models/class_test_model.dart';
import '../models/faculty_model.dart';
import 'supabase_service.dart';
import 'routine_service.dart';

class DbService {
  SupabaseClient? get _clientOrNull => SupabaseService.instance.clientOrNull;
  SupabaseClient get _client => SupabaseService.instance.client;

  // ==================== BATCH MANAGEMENT ====================

  Future<List<BatchModel>> getBatches() async {
    final response = await _client
        .from('batches')
        .select()
        .order('batch_number', ascending: false);

    return (response as List).map((json) => BatchModel.fromJson(json)).toList();
  }

  Future<BatchModel> createBatch(int batchNumber) async {
    final response = await _client
        .from('batches')
        .insert({
          'batch_number': batchNumber,
          'status': 'active',
        })
        .select()
        .single();

    return BatchModel.fromJson(response);
  }

  Future<BatchModel?> getBatchByNumber(int batchNumber) async {
    final response = await _client
        .from('batches')
        .select()
        .eq('batch_number', batchNumber)
        .maybeSingle();
    if (response == null) return null;
    return BatchModel.fromJson(response);
  }

  Future<void> updateBatchStatus(String batchId, String status) async {
    await _client.from('batches').update({'status': status}).eq('id', batchId);
  }

  Future<void> promoteBatch({
    required String batchId,
    required String nextSemester,
    required DateTime newStartDate,
    required String batchName,
  }) async {
    final dateStr = DateFormat('yyyy-MM-dd').format(newStartDate);
    await _client.from('batches').update({
      'current_semester': nextSemester,
      'semester_start_date': dateStr,
    }).eq('id', batchId);

    // Clear active CTs for that batch to ensure obsolete tests are removed
    final batchNum = batchName.replaceAll(RegExp(r'[^0-9]'), '');
    final filters = <String>{
      'batch.eq.$batchName',
      if (batchNum.isNotEmpty) 'batch.eq.$batchNum',
      if (batchNum.isNotEmpty) 'batch.eq.Batch $batchNum',
      if (batchNum.isNotEmpty) 'batch.eq.ICE-$batchNum',
    }.join(',');
    try {
      await _client.from('class_tests').delete().or(filters);
    } catch (e) {
      debugPrint('Clear CTs on promotion notice: $e');
    }
  }

  Future<void> graduateBatch({
    required String batchId,
    required String batchName,
  }) async {
    await _client.from('batches').update({
      'status': 'graduated',
      'current_semester': 'Graduated',
    }).eq('id', batchId);

    // Clear active CTs for that batch
    final batchNum = batchName.replaceAll(RegExp(r'[^0-9]'), '');
    final filters = <String>{
      'batch.eq.$batchName',
      if (batchNum.isNotEmpty) 'batch.eq.$batchNum',
      if (batchNum.isNotEmpty) 'batch.eq.Batch $batchNum',
      if (batchNum.isNotEmpty) 'batch.eq.ICE-$batchNum',
    }.join(',');
    try {
      await _client.from('class_tests').delete().or(filters);
    } catch (e) {
      debugPrint('Clear CTs on graduation notice: $e');
    }
  }

  // ==================== USER MANAGEMENT & ONBOARDING ====================

  Future<List<FacultyModel>> getFacultyDirectory() async {
    final client = _clientOrNull;
    if (client == null) {
      return FacultyModel.officialFacultyList;
    }

    try {
      final facultyList = await client
          .from('faculty_directory')
          .select()
          .order('initials', ascending: true);

      final List<FacultyModel> directory = [];
      for (final item in (facultyList as List)) {
        directory.add(FacultyModel.fromJson(item as Map<String, dynamic>));
      }

      if (directory.isEmpty) {
        // Table in Supabase is empty; attempt to seed the official faculty list
        try {
          await client.from('faculty_directory').upsert(
            FacultyModel.officialFacultyList.map((f) => f.toJson()).toList(),
            onConflict: 'initials',
          );
        } catch (e) {
          debugPrint('Seed faculty_directory error: $e');
        }
        return FacultyModel.officialFacultyList;
      }

      // Ensure all official faculty members are present in the list
      final existingInitials = directory.map((d) => d.displayInitials).toSet();
      final List<FacultyModel> missing = [];
      for (final official in FacultyModel.officialFacultyList) {
        if (!existingInitials.contains(official.displayInitials)) {
          missing.add(official);
        }
      }

      if (missing.isNotEmpty) {
        try {
          await client.from('faculty_directory').upsert(
            missing.map((m) => m.toJson()).toList(),
            onConflict: 'initials',
          );
        } catch (_) {}
        directory.addAll(missing);
      }

      directory.sort((a, b) => a.displayInitials.compareTo(b.displayInitials));
      return directory;
    } catch (e) {
      debugPrint('Error fetching faculty_directory: $e');
      return FacultyModel.officialFacultyList;
    }
  }

  Future<List<UserModel>> getTeachers() async {
    final directory = await getFacultyDirectory();
    final client = _clientOrNull;
    if (client == null) {
      return directory.map((f) => f.toUserModel()).toList();
    }

    try {
      final response = await client
          .from('users')
          .select()
          .eq('role', 'teacher');

      final Map<String, UserModel> byEmail = {};
      final Map<String, UserModel> byId = {};
      final Map<String, UserModel> byInit = {};
      for (final json in (response as List)) {
        final u = UserModel.fromJson(json);
        byEmail[u.email.toLowerCase()] = u;
        byId[u.id] = u;
        if (u.initials != null && u.initials!.trim().isNotEmpty) {
          byInit[u.initials!.trim().toUpperCase()] = u;
        }
      }

      return directory.map((fac) {
        final matched = (fac.userId != null ? byId[fac.userId!] : null) ??
            byEmail[fac.displayEmail.toLowerCase()] ??
            byInit[fac.displayInitials];
        if (matched != null) {
          return matched.copyWith(
            initials: fac.displayInitials,
            name: fac.fullName,
          );
        }
        return fac.toUserModel();
      }).toList();
    } catch (_) {
      return directory.map((f) => f.toUserModel()).toList();
    }
  }

  Future<List<StudentProfileModel>> getStudents({String? batchId}) async {
    var query = _client.from('student_profiles').select('*, users(name, email, role), batches(batch_number)');

    if (batchId != null) {
      query = query.eq('batch_id', batchId);
    }

    final response = await query.order('student_id_roll', ascending: true);
    return (response as List).map((json) => StudentProfileModel.fromJson(json)).toList();
  }

  Future<void> createStudentUser({
    required String email,
    required String password,
    required String name,
    required String batchId,
    required String rollNumber,
    bool isCr = false,
  }) async {
    // Admin creates auth user via Supabase Auth signUp
    final authResponse = await _client.auth.signUp(
      email: email.trim(),
      password: password,
      data: {
        'name': name,
        'role': 'student',
        'password_changed': false,
      },
    );

    final userId = authResponse.user?.id;
    if (userId == null) {
      throw Exception('Failed to create auth user for student.');
    }

    // Insert student profile record
    await _client.from('student_profiles').insert({
      'user_id': userId,
      'batch_id': batchId,
      'is_cr': isCr,
      'student_id_roll': rollNumber,
    });
  }

  Future<void> createTeacherUser({
    required String email,
    required String password,
    required String name,
    String? initials,
    String? designation,
  }) async {
    final cleanName = name.trim();
    final cleanEmail = email.trim().toLowerCase();
    String cleanInitials = (initials ?? '').trim().toUpperCase();
    if (cleanInitials.isEmpty) {
      final parts = cleanName.replaceAll(RegExp(r'^(Dr\.|Prof\.|Mr\.|Mrs\.|Ms\.)\s*', caseSensitive: false), '').trim().split(RegExp(r'\s+'));
      if (parts.length == 1) {
        cleanInitials = parts[0].substring(0, parts[0].length.clamp(1, 3)).toUpperCase();
      } else if (parts.length >= 2) {
        cleanInitials = '${parts[0][0]}${parts[1][0]}${parts.length > 2 ? parts.last[0] : ''}'.toUpperCase();
      } else {
        cleanInitials = 'FAC';
      }
    }

    String? userId;
    try {
      final authRes = await _client.auth.signUp(
        email: cleanEmail,
        password: password,
        data: {
          'name': cleanName,
          'role': 'teacher',
          'initials': cleanInitials,
          'password_changed': false,
        },
      );
      userId = authRes.user?.id;
      if (userId != null) {
        try {
          await _client.from('users').update({
            'initials': cleanInitials,
          }).eq('id', userId);
        } catch (e) {
          debugPrint('Save teacher initials to users error: $e');
        }
      }
    } catch (e) {
      debugPrint('Auth signup for teacher failed or user exists: $e');
    }

    // Upsert into public.faculty_directory
    try {
      await _client.from('faculty_directory').upsert({
        'initials': cleanInitials,
        'initial': cleanInitials,
        'full_name': cleanName,
        'email': cleanEmail,
        if (designation != null && designation.trim().isNotEmpty) 'designation': designation.trim(),
        if (userId != null) 'user_id': userId,
      }, onConflict: 'initials');
      RoutineService.instance.getFacultyDirectory(forceRefresh: true);
    } catch (e) {
      debugPrint('Error upserting to faculty_directory: $e');
    }
  }

  Future<void> updateFacultyMember({
    String? facultyId,
    String? userId,
    required String name,
    required String initials,
    String? email,
    String? designation,
    String? oldInitials,
  }) async {
    final cleanInitials = initials.trim().toUpperCase();
    final cleanName = name.trim();
    final cleanEmail = email?.trim().toLowerCase();
    final cleanOldInit = oldInitials?.trim().toUpperCase();

    final actualUserId = (userId != null &&
            userId.isNotEmpty &&
            !userId.startsWith('faculty_'))
        ? userId
        : null;

    final client = _clientOrNull;
    if (client == null) {
      return;
    }

    // 1. Synchronize public.users if user exists
    try {
      if (actualUserId != null) {
        await client.from('users').update({
          'name': cleanName,
          'initials': cleanInitials,
        }).eq('id', actualUserId);
      } else if (cleanEmail != null && cleanEmail.isNotEmpty) {
        await client.from('users').update({
          'name': cleanName,
          'initials': cleanInitials,
        }).eq('email', cleanEmail);
      } else if (cleanOldInit != null && cleanOldInit.isNotEmpty) {
        await client.from('users').update({
          'name': cleanName,
          'initials': cleanInitials,
        }).eq('initials', cleanOldInit);
      }
    } catch (e) {
      debugPrint('Sync user table error: $e');
    }

    // 2. Synchronize public.faculty_directory
    try {
      final updateData = <String, dynamic>{
        'initials': cleanInitials,
        'initial': cleanInitials,
        'full_name': cleanName,
        if (designation != null && designation.trim().isNotEmpty)
          'designation': designation.trim(),
        if (cleanEmail != null && cleanEmail.isNotEmpty)
          'email': cleanEmail,
        if (actualUserId != null)
          'user_id': actualUserId,
      };

      bool updated = false;
      // If we have the directory row primary key ID, update in-place by ID
      if (facultyId != null &&
          facultyId.isNotEmpty &&
          !facultyId.startsWith('faculty_')) {
        try {
          final res = await client
              .from('faculty_directory')
              .update(updateData)
              .eq('id', facultyId)
              .select();
          if ((res as List).isNotEmpty) {
            updated = true;
          }
        } catch (_) {}
      }

      // If not updated by ID, try updating by old initials or current initials
      if (!updated) {
        final targetInitials = cleanOldInit ?? cleanInitials;
        try {
          final res = await client
              .from('faculty_directory')
              .update(updateData)
              .or('initials.eq.$targetInitials,initial.eq.$targetInitials')
              .select();
          if ((res as List).isNotEmpty) {
            updated = true;
          }
        } catch (_) {}
      }

      // If no existing record was updated, upsert
      if (!updated) {
        await client
            .from('faculty_directory')
            .upsert(updateData, onConflict: 'initials');
      }

      // If initials changed and there was an old initials record under a different ID, clean up duplicate
      if (cleanOldInit != null && cleanOldInit != cleanInitials) {
        try {
          await client
              .from('faculty_directory')
              .delete()
              .or('initials.eq.$cleanOldInit,initial.eq.$cleanOldInit');
        } catch (_) {}
      }

      RoutineService.instance.getFacultyDirectory(forceRefresh: true);
    } catch (e) {
      debugPrint('Error updating faculty_directory: $e');
    }
  }

  Future<void> updateCrStatus(String userId, bool isCr) async {
    await _client
        .from('student_profiles')
        .update({'is_cr': isCr})
        .eq('user_id', userId);
  }

  Future<void> updateStudentProfile({
    required String userId,
    required String name,
    required String rollNumber,
    required bool isCr,
  }) async {
    await _client.from('student_profiles').update({
      'student_id_roll': rollNumber.trim(),
      'is_cr': isCr,
    }).eq('user_id', userId);

    if (name.trim().isNotEmpty) {
      try {
        await _client.from('users').update({
          'name': name.trim(),
        }).eq('id', userId);
      } catch (_) {}
    }
  }

  Future<void> deleteStudent(String userId) async {
    await _client.from('student_profiles').delete().eq('user_id', userId);
    try {
      await _client.from('users').delete().eq('id', userId);
    } catch (_) {}
  }

  Future<void> resetStudentPassword(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  // ==================== CLASS ROUTINE ====================

  Future<List<RoutineModel>> getRoutinesForBatch(String batchId, {int? dayOfWeek}) async {
    var query = _client
        .from('class_routine')
        .select('*, users(name), batches(batch_number)')
        .eq('batch_id', batchId);

    if (dayOfWeek != null) {
      query = query.eq('day_of_week', dayOfWeek);
    }

    final response = await query.order('start_time', ascending: true);
    return (response as List).map((json) => RoutineModel.fromJson(json)).toList();
  }

  Future<List<RoutineModel>> getRoutinesForTeacher(String teacherId, {int? dayOfWeek}) async {
    var query = _client
        .from('class_routine')
        .select('*, users(name), batches(batch_number)')
        .eq('teacher_id', teacherId);

    if (dayOfWeek != null) {
      query = query.eq('day_of_week', dayOfWeek);
    }

    final response = await query.order('start_time', ascending: true);
    return (response as List).map((json) => RoutineModel.fromJson(json)).toList();
  }

  Future<RoutineModel> createRoutine({
    required String batchId,
    required String teacherId,
    required int dayOfWeek,
    required String startTime,
    required String endTime,
    required String courseName,
    String roomNumber = 'ICE-Room 101',
  }) async {
    final response = await _client
        .from('class_routine')
        .insert({
          'batch_id': batchId,
          'teacher_id': teacherId,
          'day_of_week': dayOfWeek,
          'start_time': startTime,
          'end_time': endTime,
          'course_name': courseName,
          'room_number': roomNumber,
          'status': 'scheduled',
        })
        .select('*, users(name), batches(batch_number)')
        .single();

    return RoutineModel.fromJson(response);
  }

  Future<void> updateRoutineStatus(String routineId, String status) async {
    await _client
        .from('class_routine')
        .update({'status': status})
        .eq('id', routineId);
  }

  // ==================== NOTICES ====================

  Future<List<NoticeModel>> getNotices({String? batchId}) async {
    var query = _client.from('notices').select('*, users(name, role), batches(batch_number)');

    if (batchId != null) {
      // Fetch notices that are either specific to this batch OR department-wide (batch_id is null)
      query = query.or('batch_id.eq.$batchId,batch_id.is.null');
    }

    final response = await query.order('created_at', ascending: false);
    return (response as List).map((json) => NoticeModel.fromJson(json)).toList();
  }

  Future<NoticeModel> createNotice({
    required String title,
    required String content,
    String? batchId,
    bool isCrNotice = false,
  }) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) {
      throw Exception('User must be logged in to create notices.');
    }

    final response = await _client
        .from('notices')
        .insert({
          'author_id': currentUserId,
          'batch_id': batchId,
          'title': title,
          'content': content,
          'is_cr_notice': isCrNotice,
        })
        .select('*, users(name, role), batches(batch_number)')
        .single();

    return NoticeModel.fromJson(response);
  }

  Future<void> deleteNotice(String noticeId) async {
    await _client.from('notices').delete().eq('id', noticeId);
  }

  // ==================== DEPARTMENT NOTICES ====================

  Future<List<DepartmentNoticeModel>> getDepartmentNotices({String? batch}) async {
    var query = _client.from('department_notices').select();

    if (batch != null && batch.isNotEmpty && batch.toLowerCase() != 'all') {
      final batchNum = batch.replaceAll(RegExp(r'[^0-9]'), '');
      final conditions = <String>{
        'target_batch.eq.$batch',
        if (batchNum.isNotEmpty) 'target_batch.eq.$batchNum',
        if (batchNum.isNotEmpty) 'target_batch.eq.Batch $batchNum',
        if (batchNum.isNotEmpty) 'target_batch.eq.ICE-$batchNum',
        'target_batch.eq.all',
        'target_batch.is.null',
      }.join(',');
      query = query.or(conditions);
    }

    final response = await query
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => DepartmentNoticeModel.fromJson(json))
        .toList();
  }

  Future<List<DepartmentNoticeModel>> getActiveDepartmentNoticesForBatch({
    required String batch,
    int limit = 5,
  }) async {
    final batchNum = batch.replaceAll(RegExp(r'[^0-9]'), '');
    final filters = <String>{
      'target_batch.eq.all',
      'target_batch.eq.$batch',
      if (batchNum.isNotEmpty) 'target_batch.eq.$batchNum',
      if (batchNum.isNotEmpty) 'target_batch.eq.Batch $batchNum',
      if (batchNum.isNotEmpty) 'target_batch.eq.ICE-$batchNum',
      'target_batch.is.null',
    }.join(',');

    final response = await _client
        .from('department_notices')
        .select()
        .or(filters)
        .order('is_pinned', ascending: false)
        .order('created_at', ascending: false);

    final list = (response as List)
        .map((json) => DepartmentNoticeModel.fromJson(json))
        .where((notice) => !notice.isExpired)
        .take(limit)
        .toList();

    return list;
  }

  Future<DepartmentNoticeModel> createDepartmentNotice({
    required String title,
    required String content,
    String? attachmentUrl,
    String? attachmentName,
    String targetBatch = 'all',
    String priority = 'normal',
    bool isPinned = false,
    String? authorName,
    DateTime? expiresAt,
  }) async {
    final effectiveAuthor = authorName ??
        _client.auth.currentUser?.userMetadata?['name'] ??
        'Department Office';

    final response = await _client
        .from('department_notices')
        .insert({
          'title': title.trim(),
          'content': content.trim(),
          'attachment_url': attachmentUrl,
          'attachment_name': attachmentName,
          'target_batch': targetBatch,
          'priority': priority,
          'is_pinned': isPinned,
          'author_name': effectiveAuthor,
          if (expiresAt != null) 'expires_at': expiresAt.toIso8601String(),
        })
        .select()
        .single();

    return DepartmentNoticeModel.fromJson(response);
  }

  Future<void> togglePinDepartmentNotice(String noticeId, bool isPinned) async {
    await _client
        .from('department_notices')
        .update({'is_pinned': isPinned})
        .eq('id', noticeId);
  }

  Future<void> deleteDepartmentNotice(String noticeId) async {
    await _client.from('department_notices').delete().eq('id', noticeId);
  }

  Future<Map<String, String>> uploadNoticeAttachment({
    required Uint8List fileBytes,
    required String fileName,
  }) async {
    final sanitizedFileName = fileName.replaceAll(RegExp(r'[^a-zA-Z0-9._-]'), '_');
    final storagePath = 'notices/${DateTime.now().millisecondsSinceEpoch}_$sanitizedFileName';

    await _client.storage.from('chat_attachments').uploadBinary(
      storagePath,
      fileBytes,
      fileOptions: const FileOptions(upsert: true),
    );

    final publicUrl = _client.storage.from('chat_attachments').getPublicUrl(storagePath);
    return {
      'url': publicUrl,
      'name': fileName,
    };
  }

  // ==================== CLASS TESTS (CR MANAGED) ====================

  Future<void> purgeExpiredClassTests() async {
    final todayIso = DateTime.now().toIso8601String().split('T')[0];
    try {
      // Permanently delete any test where test_date is before today
      await _client
          .from('class_tests')
          .delete()
          .lt('test_date', todayIso);
    } catch (e) {
      debugPrint('Purge notice: $e');
    }
  }

  Future<List<ClassTestModel>> getUpcomingClassTestsForBatch({
    required String batch,
    bool autoPurge = true,
  }) async {
    if (autoPurge) {
      await purgeExpiredClassTests();
    }

    final todayIso = DateTime.now().toIso8601String().split('T')[0];
    final batchNum = batch.replaceAll(RegExp(r'[^0-9]'), '');
    final filters = <String>{
      'batch.eq.$batch',
      if (batchNum.isNotEmpty) 'batch.eq.$batchNum',
      if (batchNum.isNotEmpty) 'batch.eq.Batch $batchNum',
      if (batchNum.isNotEmpty) 'batch.eq.ICE-$batchNum',
    }.join(',');

    final response = await _client
        .from('class_tests')
        .select()
        .or(filters)
        .gte('test_date', todayIso)
        .order('test_date', ascending: true)
        .order('test_time', ascending: true);

    return (response as List)
        .map((json) => ClassTestModel.fromJson(json))
        .toList();
  }

  Future<ClassTestModel?> getNextUpcomingClassTestForBatch({
    required String batch,
  }) async {
    final tests = await getUpcomingClassTestsForBatch(batch: batch);
    if (tests.isEmpty) return null;
    return tests.first;
  }

  Future<ClassTestModel> createClassTest({
    required String batch,
    required String courseCode,
    required String title,
    String? syllabus,
    required DateTime testDate,
    String? testTime,
    String? createdBy,
  }) async {
    final response = await _client
        .from('class_tests')
        .insert({
          'batch': batch,
          'course_code': courseCode.trim(),
          'title': title.trim(),
          'syllabus': syllabus?.trim(),
          'test_date': DateFormat('yyyy-MM-dd').format(testDate),
          'test_time': testTime,
          'created_by': createdBy ?? _client.auth.currentUser?.id,
        })
        .select()
        .single();

    return ClassTestModel.fromJson(response);
  }

  Future<ClassTestModel> updateClassTest({
    required String testId,
    required String courseCode,
    required String title,
    String? syllabus,
    required DateTime testDate,
    String? testTime,
  }) async {
    final response = await _client
        .from('class_tests')
        .update({
          'course_code': courseCode.trim(),
          'title': title.trim(),
          'syllabus': syllabus?.trim(),
          'test_date': DateFormat('yyyy-MM-dd').format(testDate),
          'test_time': testTime,
        })
        .eq('id', testId)
        .select()
        .single();

    return ClassTestModel.fromJson(response);
  }

  Future<void> deleteClassTest(String testId) async {
    await _client.from('class_tests').delete().eq('id', testId);
  }
}

