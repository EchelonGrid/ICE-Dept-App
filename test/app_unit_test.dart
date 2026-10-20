import 'package:flutter_test/flutter_test.dart';
import 'package:ice_dept_app/core/utils/qr_token_helper.dart';
import 'package:ice_dept_app/core/utils/date_time_helper.dart';
import 'package:ice_dept_app/models/user_model.dart';
import 'package:ice_dept_app/models/batch_model.dart';
import 'package:ice_dept_app/models/routine_model.dart';
import 'package:ice_dept_app/models/notice_model.dart';
import 'package:ice_dept_app/models/chat_message_model.dart';
import 'package:ice_dept_app/models/local_note_model.dart';
import 'package:flutter/material.dart';
import 'package:ice_dept_app/models/resource_item_model.dart';
import 'package:ice_dept_app/services/quick_access_service.dart';
import 'package:ice_dept_app/services/theme_service.dart';
import 'package:ice_dept_app/core/constants/curriculum.dart';
import 'package:ice_dept_app/models/department_routine_model.dart';
import 'package:ice_dept_app/models/department_notice_model.dart';
import 'package:ice_dept_app/models/class_test_model.dart';
import 'package:ice_dept_app/utils/routine_helper.dart';
import 'package:ice_dept_app/utils/academic_progression_helper.dart';
import 'package:ice_dept_app/models/faculty_model.dart';
import 'package:ice_dept_app/services/routine_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('QRTokenHelper Tests', () {
    test('generateQRPayload produces valid JSON with correct signature', () {
      const classId = 'test-class-uuid-123';
      final payloadStr = QRTokenHelper.generateQRPayload(classId);

      final parsed = QRTokenHelper.parsePayload(payloadStr);
      expect(parsed, isNotNull);
      expect(parsed!['classId'], equals(classId));
      expect(parsed['timestamp'], isA<int>());
      expect(parsed['token'], isA<String>());

      final expectedSig = QRTokenHelper.generateSignature(classId, parsed['timestamp'] as int);
      expect(parsed['token'], equals(expectedSig));
    });

    test('parsePayload returns null for invalid input', () {
      expect(QRTokenHelper.parsePayload('invalid json string'), isNull);
      expect(QRTokenHelper.parsePayload('{"someKey": "val"}'), isNull);
    });
  });

  group('DateTimeHelper Tests', () {
    test('formatTime formats HH:mm:ss to 12-hour format', () {
      final formatted = DateTimeHelper.formatTime('14:30:00');
      expect(formatted, contains('2:30'));
      expect(formatted, contains('PM'));
    });

    test('getDayName returns correct day names', () {
      expect(DateTimeHelper.getDayName(1), equals('Monday'));
      expect(DateTimeHelper.getDayName(5), equals('Friday'));
      expect(DateTimeHelper.getDayName(7), equals('Sunday'));
    });
  });

  group('Data Models Tests', () {
    test('UserModel serialization and deserialization', () {
      final json = {
        'id': 'user-123',
        'email': 'student@ice.dept',
        'name': 'Test Student',
        'role': 'student',
        'password_changed': true,
      };

      final user = UserModel.fromJson(json);
      expect(user.id, equals('user-123'));
      expect(user.email, equals('student@ice.dept'));
      expect(user.role, equals(UserRole.student));
      expect(user.passwordChanged, isTrue);
      expect(user.initials, isNull);

      final outJson = user.toJson();
      expect(outJson['role'], equals('student'));
      expect(outJson['password_changed'], isTrue);

      final teacherJson = {
        'id': 'teach-456',
        'email': 'imran@ice.dept',
        'name': 'Dr. Md. Imran Hossain',
        'role': 'teacher',
        'initials': 'MIH',
      };
      final teacher = UserModel.fromJson(teacherJson);
      expect(teacher.role, equals(UserRole.teacher));
      expect(teacher.initials, equals('MIH'));
      expect(teacher.displayInitials, equals('MIH'));
      expect(teacher.toJson()['initials'], equals('MIH'));
    });

    test('UserModel displayInitials derives clean fallback when initials is null', () {
      final user1 = UserModel(
        id: '1',
        email: 'anwar@ice.dept',
        name: 'Prof. Dr. Md. Anwar Hossain',
        role: UserRole.teacher,
      );
      expect(user1.displayInitials, equals('MAH'));

      final user2 = UserModel(
        id: '2',
        email: 'tahsin@ice.dept',
        name: 'Tahsin Turna',
        role: UserRole.teacher,
      );
      expect(user2.displayInitials, equals('TT'));

      final user3 = UserModel(
        id: '3',
        email: 'custom@ice.dept',
        name: 'Akif Mahdi',
        role: UserRole.teacher,
        initials: 'AM',
      );
      expect(user3.displayInitials, equals('AM'));
    });

    test('BatchModel serialization and deserialization', () {
      final json = {
        'id': 'batch-21',
        'batch_number': 21,
        'status': 'active',
      };

      final batch = BatchModel.fromJson(json);
      expect(batch.batchNumber, equals(21));
      expect(batch.isActive, isTrue);
    });

    test('RoutineModel serialization and deserialization', () {
      final json = {
        'id': 'routine-1',
        'batch_id': 'batch-21',
        'teacher_id': 'teacher-1',
        'day_of_week': 2,
        'start_time': '10:00:00',
        'end_time': '11:30:00',
        'course_name': 'Digital Communications',
        'room_number': 'ICE-201',
        'status': 'scheduled',
      };

      final routine = RoutineModel.fromJson(json);
      expect(routine.courseName, equals('Digital Communications'));
      expect(routine.isScheduled, isTrue);
      expect(routine.isCanceled, isFalse);
    });

    test('NoticeModel serialization and deserialization', () {
      final json = {
        'id': 'notice-1',
        'author_id': 'author-1',
        'batch_id': null,
        'title': 'Midterm Exam Schedule',
        'content': 'Exams will begin next week.',
        'is_cr_notice': false,
      };

      final notice = NoticeModel.fromJson(json);
      expect(notice.isDepartmentWide, isTrue);
      expect(notice.title, equals('Midterm Exam Schedule'));
    });

    test('ChatMessageModel serialization with referenced notice', () {
      final json = {
        'id': 'msg-1',
        'batch_id': 'batch-21',
        'sender_id': 'user-1',
        'message': 'Regarding the midterm notice...',
        'referenced_notice_id': 'notice-1',
        'referenced_notice_title': 'Midterm Exam Schedule',
        'is_cr': true,
        'users': {
          'name': 'Alex Johnson',
          'role': 'student',
        },
      };

      final msg = ChatMessageModel.fromJson(json);
      expect(msg.id, equals('msg-1'));
      expect(msg.senderName, equals('Alex Johnson'));
      expect(msg.isSenderCr, isTrue);
      expect(msg.hasReferencedNotice, isTrue);
      expect(msg.referencedNoticeTitle, equals('Midterm Exam Schedule'));

      final outJson = msg.toJson();
      expect(outJson['referenced_notice_id'], equals('notice-1'));
      expect(outJson['referenced_notice_title'], equals('Midterm Exam Schedule'));
      expect(outJson['chat_scope'], equals('batch'));
    });

    test('ChatMessageModel supports department and cr scopes', () {
      final deptMsg = ChatMessageModel.fromJson({
        'id': 'msg-dept',
        'sender_id': 'user-2',
        'message': 'Department open forum discussion',
        'chat_scope': 'department',
      });
      expect(deptMsg.scopeEnum, equals(ChatScope.department));

      final crMsg = ChatMessageModel.fromJson({
        'id': 'msg-cr',
        'sender_id': 'user-3',
        'sender_name': 'CR Sarah',
        'message': 'CR council agenda (updated)',
        'chat_scope': 'cr',
        'is_edited': true,
        'reactions': {
          '❤️': ['user-1', 'user-2'],
          '👍': ['user-3'],
        },
      });
      expect(crMsg.scopeEnum, equals(ChatScope.cr));
      expect(crMsg.senderName, equals('CR Sarah'));
      expect(crMsg.isEdited, isTrue);
      expect(crMsg.reactions['❤️']?.length, equals(2));
      expect(crMsg.hasReacted('❤️', 'user-1'), isTrue);
      expect(crMsg.hasReacted('❤️', 'user-99'), isFalse);
      expect(crMsg.totalReactionsCount, equals(3));
      expect(ChatScope.fromString('global'), equals(ChatScope.department));
      expect(ChatScope.fromString('cr'), equals(ChatScope.cr));

      // Test attachment properties
      final imgMsg = ChatMessageModel.fromJson({
        'id': 'msg-img',
        'sender_id': 'user-4',
        'message': 'Lab experiment diagram',
        'attachment_url': 'https://supabase.co/storage/v1/object/public/chat_attachments/sample.png',
        'attachment_name': 'sample.png',
        'attachment_type': 'image',
      });
      expect(imgMsg.hasAttachment, isTrue);
      expect(imgMsg.isImageAttachment, isTrue);
      expect(imgMsg.isFileAttachment, isFalse);
      expect(imgMsg.attachmentName, equals('sample.png'));

      final fileMsg = ChatMessageModel.fromJson({
        'id': 'msg-file',
        'sender_id': 'user-5',
        'message': 'Assignment submission guidelines',
        'attachment_url': 'https://supabase.co/storage/v1/object/public/chat_attachments/guide.pdf',
        'attachment_name': 'guide.pdf',
        'attachment_type': 'file',
      });
      expect(fileMsg.hasAttachment, isTrue);
      expect(fileMsg.isImageAttachment, isFalse);
      expect(fileMsg.isFileAttachment, isTrue);

      // Test reply-to properties
      final replyMsg = ChatMessageModel.fromJson({
        'id': 'msg-reply',
        'sender_id': 'user-6',
        'message': 'I agree with this schedule',
        'reply_to_id': 'msg-original',
        'reply_to_text': 'Shall we have the quiz on Sunday?',
        'reply_to_sender': 'CR Rahim',
      });
      expect(replyMsg.hasReply, isTrue);
      expect(replyMsg.replyToId, equals('msg-original'));
      expect(replyMsg.replyToText, equals('Shall we have the quiz on Sunday?'));
      expect(replyMsg.replyToSender, equals('CR Rahim'));

      final serialized = replyMsg.toJson();
      expect(serialized['reply_to_id'], equals('msg-original'));
      expect(serialized['reply_to_text'], equals('Shall we have the quiz on Sunday?'));
      expect(serialized['reply_to_sender'], equals('CR Rahim'));
    });

    test('LocalNoteModel serialization and file size formatting', () {
      final json = {
        'id': 'note-1',
        'subject_code': 'ICE-3101',
        'subject_name': 'Artificial Intelligence and Robotics',
        'title': 'AI Chapter 2 Summary',
        'file_name': 'ai_ch2.pdf',
        'file_size_bytes': 2048576, // ~1.95 MB
        'file_path': '/storage/emulated/0/Download/ai_ch2.pdf',
        'added_at': '2026-09-02T12:00:00.000Z',
      };

      final note = LocalNoteModel.fromJson(json);
      expect(note.id, equals('note-1'));
      expect(note.subjectCode, equals('ICE-3101'));
      expect(note.formattedFileSize, equals('2.0 MB'));

      final out = note.toJson();
      expect(out['subject_code'], equals('ICE-3101'));
      expect(out['file_path'], equals('/storage/emulated/0/Download/ai_ch2.pdf'));
    });

    test('DepartmentCurriculum mapping has 8 complete semesters', () {
      expect(DepartmentCurriculum.allSemesters.length, equals(8));
      final sem31 = DepartmentCurriculum.getSemester('3-1');
      expect(sem31.title, contains('3rd Year 1st Semester'));
      expect(sem31.subjects.any((s) => s.code == 'ICE-3101'), isTrue);
      expect(sem31.subjects.any((s) => s.name == 'Artificial Intelligence and Robotics'), isTrue);
    });

    test('ResourceItem serialization and QuickAccessService pin/unpin toggling', () async {
      SharedPreferences.setMockInitialValues({});
      final service = QuickAccessService.instance;
      await service.loadPinnedItems();

      // Seed items should be loaded initially
      expect(service.pinnedItems.isNotEmpty, isTrue);

      const testItem = ResourceItem(
        id: 'test-item-99',
        title: 'Custom Signal Processing Notes',
        category: 'notes',
        courseName: 'ICE-3105',
        fileUrl: 'https://example.com/signal.pdf',
        uploaderName: 'Lab Assistant',
      );

      // Verify item is initially not pinned
      expect(service.isPinned(testItem.id), isFalse);

      // Pin item
      final pinned = await service.togglePin(testItem);
      expect(pinned, isTrue);
      expect(service.isPinned(testItem.id), isTrue);
      expect(service.pinnedItems.first.id, equals('test-item-99'));

      // Toggle again to unpin
      final unpinned = await service.togglePin(testItem);
      expect(unpinned, isFalse);
      expect(service.isPinned(testItem.id), isFalse);

      // Direct unpin
      await service.togglePin(testItem);
      expect(service.isPinned(testItem.id), isTrue);
      await service.unpin(testItem.id);
      expect(service.isPinned(testItem.id), isFalse);

      // Test JSON serialization of ResourceItem
      final json = testItem.toJson();
      final revived = ResourceItem.fromJson(json);
      expect(revived.id, equals(testItem.id));
      expect(revived.title, equals(testItem.title));
      expect(revived.courseName, equals(testItem.courseName));
      expect(revived.uploaderName, equals(testItem.uploaderName));
    });

    test('ThemeService initializes and persists theme modes', () async {
      SharedPreferences.setMockInitialValues({'app_theme_mode': 'dark'});
      final themeService = ThemeService.instance;
      await themeService.initialize();

      expect(themeService.themeMode, equals(ThemeMode.dark));
      expect(themeService.isDarkMode, isTrue);
      expect(themeService.isLightMode, isFalse);

      await themeService.setThemeMode(ThemeMode.light);
      expect(themeService.themeMode, equals(ThemeMode.light));
      expect(themeService.isLightMode, isTrue);

      await themeService.setThemeMode(ThemeMode.system);
      expect(themeService.themeMode, equals(ThemeMode.system));
      expect(themeService.isSystemMode, isTrue);
    });

    test('RoutineHelper normalizes batches into canonical ICE-XX format', () {
      expect(RoutineHelper.normalizeBatch('18B'), equals('ICE-18'));
      expect(RoutineHelper.normalizeBatch('18'), equals('ICE-18'));
      expect(RoutineHelper.normalizeBatch('Batch 18'), equals('ICE-18'));
      expect(RoutineHelper.normalizeBatch(18), equals('ICE-18'));
      expect(RoutineHelper.normalizeBatch('ICE-18'), equals('ICE-18'));
      expect(RoutineHelper.normalizeBatch('16B'), equals('ICE-16'));
    });

    test('RoutineHelper computes academic week number and odd/even parity correctly', () {
      final startDate = DateTime(2026, 7, 15);

      // Day 0 to 6 = Week 1 (Odd)
      expect(RoutineHelper.getCurrentAcademicWeek(startDate, DateTime(2026, 7, 15)), equals(1));
      expect(RoutineHelper.getCurrentWeekParity(startDate, DateTime(2026, 7, 15)), equals('odd'));

      // Day 7 = Week 2 (Even)
      expect(RoutineHelper.getCurrentAcademicWeek(startDate, DateTime(2026, 7, 22)), equals(2));
      expect(RoutineHelper.getCurrentWeekParity(startDate, DateTime(2026, 7, 22)), equals('even'));

      // Day 50 (Sept 3, 2026) = Week 8 (Even)
      expect(RoutineHelper.getCurrentAcademicWeek(startDate, DateTime(2026, 9, 3)), equals(8));
      expect(RoutineHelper.getCurrentWeekParity(startDate, DateTime(2026, 9, 3)), equals('even'));

      // Slot parity activity
      expect(
        RoutineHelper.isSlotActiveForWeek(slotParity: 'all', startDate: startDate, referenceDate: DateTime(2026, 9, 3)),
        isTrue,
      );
      expect(
        RoutineHelper.isSlotActiveForWeek(slotParity: 'even', startDate: startDate, referenceDate: DateTime(2026, 9, 3)),
        isTrue,
      );
      expect(
        RoutineHelper.isSlotActiveForWeek(slotParity: 'odd', startDate: startDate, referenceDate: DateTime(2026, 9, 3)),
        isFalse,
      );
    });

    test('DepartmentRoutineModel serialization and time formatting', () {
      final model = DepartmentRoutineModel(
        id: 'slot-1',
        batch: 'ICE-18',
        dayOfWeek: 'Sunday',
        startTime: '14:00:00',
        endTime: '17:00:00',
        courseCode: 'ICE-2204',
        teacherInitial: 'MIH',
        roomNumber: '904',
        isLab: true,
        weekParity: 'odd',
        teacherFullName: 'Dr. Md. Imran Hossain',
      );

      final json = model.toJson();
      expect(json['batch'], equals('ICE-18'));
      expect(json['is_lab'], isTrue);
      expect(json['week_parity'], equals('odd'));
      expect(json['course_code'], equals('ICE-2204'));

      final fromJson = DepartmentRoutineModel.fromJson(json);
      expect(fromJson.batch, equals('ICE-18'));
      expect(fromJson.isLab, isTrue);
      expect(fromJson.courseCode, equals('ICE-2204'));
      expect(fromJson.weekParity, equals('odd'));

      expect(RoutineHelper.formatTimeRange('14:00:00', '17:00:00'), equals('2:00 PM - 5:00 PM'));
      expect(RoutineHelper.formatTime12Hour('09:00:00'), equals('9:00 AM'));
    });

    test('DepartmentNoticeModel serialization, auto-expiry, and priority helpers', () {
      final now = DateTime.now();
      final futureExpiry = now.add(const Duration(days: 25));
      final pastExpiry = now.subtract(const Duration(days: 2));

      final activeNotice = DepartmentNoticeModel(
        id: 'dn-101',
        title: 'Midterm Routine Published',
        content: 'Please find attached midterm routine.',
        attachmentUrl: 'https://example.com/routine.pdf',
        attachmentName: 'routine.pdf',
        targetBatch: 'all',
        priority: 'urgent',
        isPinned: true,
        authorName: 'Academic Office',
        createdAt: now,
        expiresAt: futureExpiry,
      );

      expect(activeNotice.isUrgent, isTrue);
      expect(activeNotice.isPinned, isTrue);
      expect(activeNotice.isExpired, isFalse);
      expect(activeNotice.isPermanent, isFalse);
      expect(activeNotice.expiryCountdownText, contains('Expires in'));

      final json = activeNotice.toJson();
      expect(json['title'], equals('Midterm Routine Published'));
      expect(json['priority'], equals('urgent'));
      expect(json['attachment_url'], equals('https://example.com/routine.pdf'));

      final fromJson = DepartmentNoticeModel.fromJson(json);
      expect(fromJson.title, equals(activeNotice.title));
      expect(fromJson.isPinned, isTrue);
      expect(fromJson.attachmentName, equals('routine.pdf'));

      // Test Expired notice
      final expiredNotice = activeNotice.copyWith(expiresAt: pastExpiry);
      expect(expiredNotice.isExpired, isTrue);
      expect(expiredNotice.expiryCountdownText, equals('Expired'));

      // Test Permanent notice (null expiresAt)
      final permanentNotice = DepartmentNoticeModel(
        id: 'dn-102',
        title: 'Department Code of Conduct',
        content: 'General conduct policy.',
        createdAt: now,
        expiresAt: null,
      );
      expect(permanentNotice.isPermanent, isTrue);
      expect(permanentNotice.isExpired, isFalse);
      expect(permanentNotice.expiryCountdownText, equals('Permanent Notice'));
    });

    test('ClassTestModel serialization, countdown calculations, and date/time formatting', () {
      final today = DateTime.now();
      final in3Days = today.add(const Duration(days: 3));
      final testModel = ClassTestModel(
        id: 'ct-test-01',
        batch: 'Batch 21',
        courseCode: 'ICE-3101',
        title: 'Class Test 1 - Midterm Prep',
        syllabus: 'Chapters 1 & 2: DSP fundamentals',
        testDate: in3Days,
        testTime: '10:30:00',
        createdBy: 'user-cr-123',
        createdAt: today,
      );

      // Verify serialization
      final json = testModel.toJson();
      expect(json['id'], equals('ct-test-01'));
      expect(json['batch'], equals('Batch 21'));
      expect(json['course_code'], equals('ICE-3101'));
      expect(json['title'], equals('Class Test 1 - Midterm Prep'));
      expect(json['test_time'], equals('10:30:00'));

      // Verify deserialization
      final parsed = ClassTestModel.fromJson(json);
      expect(parsed.id, equals('ct-test-01'));
      expect(parsed.courseCode, equals('ICE-3101'));
      expect(parsed.title, equals('Class Test 1 - Midterm Prep'));
      expect(parsed.syllabus, equals('Chapters 1 & 2: DSP fundamentals'));
      expect(parsed.isUpcoming, isTrue);
      expect(parsed.countdownText, equals('In 3 days'));
      expect(parsed.formattedTime, equals('10:30 AM'));

      // Test today countdown
      final testToday = ClassTestModel(
        id: 'ct-today',
        batch: 'Batch 21',
        courseCode: 'ICE-3103',
        title: 'Quick Quiz',
        testDate: today,
      );
      expect(testToday.countdownText, equals('Today'));
      expect(testToday.isUpcoming, isTrue);

      // Test tomorrow countdown
      final testTomorrow = ClassTestModel(
        id: 'ct-tomorrow',
        batch: 'Batch 21',
        courseCode: 'ICE-3105',
        title: 'Lab Test',
        testDate: today.add(const Duration(days: 1)),
      );
      expect(testTomorrow.countdownText, equals('Tomorrow'));
      expect(testTomorrow.isUpcoming, isTrue);
    });
  });

  group('Academic Progression & Batch Lifecycle Tests', () {
    test('AcademicProgressionHelper semester order has exactly 8 terms', () {
      expect(AcademicProgressionHelper.semesterOrder, equals([
        '1-1',
        '1-2',
        '2-1',
        '2-2',
        '3-1',
        '3-2',
        '4-1',
        '4-2',
      ]));
    });

    test('AcademicProgressionHelper getNextSemester advances correctly', () {
      expect(AcademicProgressionHelper.getNextSemester('1-1'), equals('1-2'));
      expect(AcademicProgressionHelper.getNextSemester('1-2'), equals('2-1'));
      expect(AcademicProgressionHelper.getNextSemester('2-1'), equals('2-2'));
      expect(AcademicProgressionHelper.getNextSemester('2-2'), equals('3-1'));
      expect(AcademicProgressionHelper.getNextSemester('3-1'), equals('3-2'));
      expect(AcademicProgressionHelper.getNextSemester('3-2'), equals('4-1'));
      expect(AcademicProgressionHelper.getNextSemester('4-1'), equals('4-2'));
      expect(AcademicProgressionHelper.getNextSemester('4-2'), isNull); // Final semester
      expect(AcademicProgressionHelper.getNextSemester(' 2-1 '), equals('2-2')); // Whitespace tolerance
      expect(AcademicProgressionHelper.getNextSemester('invalid'), isNull);
      expect(AcademicProgressionHelper.getNextSemester('Graduated'), isNull);
    });

    test('AcademicProgressionHelper isGraduating detects 4-2 batch', () {
      expect(AcademicProgressionHelper.isGraduating('4-2'), isTrue);
      expect(AcademicProgressionHelper.isGraduating(' 4-2 '), isTrue);
      expect(AcademicProgressionHelper.isGraduating('4-1'), isFalse);
      expect(AcademicProgressionHelper.isGraduating('1-1'), isFalse);
      expect(AcademicProgressionHelper.isGraduating('Graduated'), isFalse);
    });

    test('AcademicProgressionHelper calculateParity and calculateAcademicWeek', () {
      final start = DateTime(2026, 7, 15);

      // Same day (day 0) -> Week 1 -> odd
      expect(AcademicProgressionHelper.calculateAcademicWeek(start, DateTime(2026, 7, 15)), equals(1));
      expect(AcademicProgressionHelper.calculateParity(start, DateTime(2026, 7, 15)), equals('odd'));

      // Day 6 -> still Week 1 -> odd
      expect(AcademicProgressionHelper.calculateAcademicWeek(start, DateTime(2026, 7, 21)), equals(1));
      expect(AcademicProgressionHelper.calculateParity(start, DateTime(2026, 7, 21)), equals('odd'));

      // Day 7 -> Week 2 -> even
      expect(AcademicProgressionHelper.calculateAcademicWeek(start, DateTime(2026, 7, 22)), equals(2));
      expect(AcademicProgressionHelper.calculateParity(start, DateTime(2026, 7, 22)), equals('even'));

      // Day 14 -> Week 3 -> odd
      expect(AcademicProgressionHelper.calculateAcademicWeek(start, DateTime(2026, 7, 29)), equals(3));
      expect(AcademicProgressionHelper.calculateParity(start, DateTime(2026, 7, 29)), equals('odd'));

      // Day 21 -> Week 4 -> even
      expect(AcademicProgressionHelper.calculateAcademicWeek(start, DateTime(2026, 8, 5)), equals(4));
      expect(AcademicProgressionHelper.calculateParity(start, DateTime(2026, 8, 5)), equals('even'));

      // Future start date clamps week to at least 1
      expect(AcademicProgressionHelper.calculateAcademicWeek(start, DateTime(2026, 7, 1)), equals(1));
    });

    test('RoutineHelper calculateParity delegates cleanly to AcademicProgressionHelper', () {
      final start = DateTime(2026, 7, 15);
      expect(RoutineHelper.calculateParity(start, DateTime(2026, 7, 15)), equals('odd'));
      expect(RoutineHelper.calculateParity(start, DateTime(2026, 7, 22)), equals('even'));
    });

    test('BatchModel semester progression and status flags', () {
      final activeBatch = BatchModel(
        id: 'batch-21',
        batchNumber: 21,
        name: 'Batch 21',
        code: 'ICE-21',
        status: 'active',
        currentSemester: '4-1',
        semesterStartDate: DateTime(2026, 7, 15),
      );
      expect(activeBatch.isActive, isTrue);
      expect(activeBatch.isGraduated, isFalse);
      expect(activeBatch.currentSemester, equals('4-1'));
      expect(activeBatch.semesterStartDate, equals(DateTime(2026, 7, 15)));

      // Test serialization to JSON
      final json = activeBatch.toJson();
      expect(json['id'], equals('batch-21'));
      expect(json['batch_number'], equals(21));
      expect(json['status'], equals('active'));
      expect(json['current_semester'], equals('4-1'));
      expect(json['semester_start_date'], equals('2026-07-15'));

      // Test deserialization from JSON
      final parsed = BatchModel.fromJson(json);
      expect(parsed.id, equals('batch-21'));
      expect(parsed.batchNumber, equals(21));
      expect(parsed.currentSemester, equals('4-1'));
      expect(parsed.semesterStartDate, equals(DateTime(2026, 7, 15)));
      expect(parsed.isActive, isTrue);
      expect(parsed.isGraduated, isFalse);

      // Test graduated batch (case-insensitive)
      final gradBatch1 = BatchModel(
        id: 'batch-18',
        batchNumber: 18,
        status: 'graduated',
        currentSemester: 'Graduated',
      );
      expect(gradBatch1.isActive, isFalse);
      expect(gradBatch1.isGraduated, isTrue);

      final gradBatch2 = BatchModel.fromJson({
        'id': 'batch-17',
        'batch_number': 17,
        'status': 'GRADUATED',
        'current_semester': 'Graduated',
      });
      expect(gradBatch2.isActive, isFalse);
      expect(gradBatch2.isGraduated, isTrue);
    });
  });

  group('Faculty Directory & Model Tests', () {
    test('FacultyModel serialization, deserialization, and mock email fallback', () {
      final json = {
        'initials': 'MIH',
        'full_name': 'Dr. Md. Imran Hossain',
        'department': 'ICE',
        'designation': 'Associate Professor',
        'email': 'imran@ice.dept',
        'user_id': 'user-mih-123',
      };

      final model = FacultyModel.fromJson(json);
      expect(model.displayInitials, equals('MIH'));
      expect(model.fullName, equals('Dr. Md. Imran Hossain'));
      expect(model.displayDesignation, equals('Associate Professor'));
      expect(model.displayEmail, equals('imran@ice.dept'));
      expect(model.department, equals('ICE'));
      expect(model.userId, equals('user-mih-123'));

      // Test mock email fallback when email is null or empty
      final nullEmailModel = FacultyModel.fromJson({
        'initial': 'MAH',
        'full_name': 'Prof. Dr. Md. Anwar Hossain',
      });
      expect(nullEmailModel.displayInitials, equals('MAH'));
      expect(nullEmailModel.displayEmail, equals('mah@ice.dept'));

      final outJson = model.toJson();
      expect(outJson['initials'], equals('MIH'));
      expect(outJson['initial'], equals('MIH'));
      expect(outJson['full_name'], equals('Dr. Md. Imran Hossain'));
      expect(outJson['designation'], equals('Associate Professor'));
    });

    test('FacultyModel derives rank/designation accurately from titles and known faculty initials', () {
      expect(
        const FacultyModel(initials: 'MAH', fullName: 'Prof. Dr. Md. Anwar Hossain').displayDesignation,
        equals('Professor'),
      );
      expect(
        const FacultyModel(initials: 'MSH', fullName: 'Prof. Dr. Md. Sarwar Hosain').displayDesignation,
        equals('Professor'),
      );
      expect(
        const FacultyModel(initials: 'MIH', fullName: 'Dr. Md. Imran Hossain').displayDesignation,
        equals('Associate Professor'),
      );
      expect(
        const FacultyModel(initials: 'DAF', fullName: 'Dr. A. F. M. Zainul Abadin').displayDesignation,
        equals('Associate Professor'),
      );
      expect(
        const FacultyModel(initials: 'TNT', fullName: 'Taskin Noor Turna').displayDesignation,
        equals('Assistant Professor'),
      );
      expect(
        const FacultyModel(initials: 'TD', fullName: 'Tarun Debnath').displayDesignation,
        equals('Assistant Professor'),
      );
      expect(
        const FacultyModel(initials: 'AM', fullName: 'Akif Mahdi').displayDesignation,
        equals('Lecturer'),
      );
      expect(
        const FacultyModel(initials: 'XYZ', fullName: 'John Doe', department: 'Associate Professor, ICE').displayDesignation,
        equals('Associate Professor'),
      );
      expect(
        const FacultyModel(initials: 'XYZ', fullName: 'John Doe', department: 'Assistant Professor, ICE').displayDesignation,
        equals('Assistant Professor'),
      );
      expect(
        const FacultyModel(initials: 'XYZ', fullName: 'John Doe', department: 'Professor of Electronics').displayDesignation,
        equals('Professor'),
      );
      expect(
        const FacultyModel(initials: 'XYZ', fullName: 'John Doe', department: 'Lecturer in Telecom').displayDesignation,
        equals('Lecturer'),
      );
      expect(
        const FacultyModel(initials: 'XYZ', fullName: 'John Doe').displayDesignation,
        equals('Faculty'),
      );
    });

    test('FacultyModel officialFacultyList contains all 13 official faculty and is sorted alphabetically', () {
      final list = FacultyModel.officialFacultyList;
      expect(list.length, equals(13));

      final initials = list.map((f) => f.displayInitials).toList();
      final expectedInitials = [
        'AM',
        'DAF',
        'KK',
        'MAH',
        'MAR',
        'MIH',
        'MIK',
        'MKIC',
        'MOF',
        'MSH',
        'SS',
        'TD',
        'TNT',
      ];
      expect(initials, equals(expectedInitials));

      // Verify all required faculty codes are present
      const requiredCodes = [
        'MAH', 'MSH', 'MOF', 'MIH', 'TNT', 'TD', 'AM', 'MAR', 'MIK', 'MKIC', 'KK', 'SS', 'DAF'
      ];
      for (final code in requiredCodes) {
        expect(initials.contains(code), isTrue, reason: 'Expected $code to be in official faculty directory');
      }

      // Verify each entry has valid full name, designation, and email
      for (final faculty in list) {
        expect(faculty.fullName.trim().isNotEmpty, isTrue);
        expect(faculty.displayDesignation.trim().isNotEmpty, isTrue);
        expect(faculty.displayEmail.contains('@ice.dept'), isTrue);
      }
    });

    test('FacultyModel toUserModel converts cleanly to teacher UserModel', () {
      const fac = FacultyModel(
        initials: 'MIH',
        fullName: 'Dr. Md. Imran Hossain',
        designation: 'Associate Professor',
        email: 'imran@ice.dept',
        userId: 'auth-user-mih',
      );

      final user = fac.toUserModel();
      expect(user.id, equals('auth-user-mih'));
      expect(user.name, equals('Dr. Md. Imran Hossain'));
      expect(user.email, equals('imran@ice.dept'));
      expect(user.role, equals(UserRole.teacher));
      expect(user.initials, equals('MIH'));
      expect(user.displayInitials, equals('MIH'));
    });

    test('RoutineService fallback faculty map resolves DAF and official faculty names', () async {
      final routineService = RoutineService.instance;
      final dafName = await routineService.resolveTeacherFullName('DAF');
      expect(dafName, equals('Dr. A. F. M. Zainul Abadin'));

      final mihName = await routineService.resolveTeacherFullName('MIH');
      expect(mihName, equals('Dr. Md. Imran Hossain'));

      final mahName = await routineService.resolveTeacherFullName('MAH');
      expect(mahName, equals('Prof. Dr. Md. Anwar Hossain'));
    });
  });
}
