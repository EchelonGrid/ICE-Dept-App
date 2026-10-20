import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:ice_dept_app/core/theme/app_theme.dart';
import 'package:ice_dept_app/models/department_routine_model.dart';
import 'package:ice_dept_app/models/user_model.dart';
import 'package:ice_dept_app/screens/teacher/teacher_direct_inbox_screen.dart';
import 'package:ice_dept_app/screens/teacher/teacher_home_screen.dart';
import 'package:ice_dept_app/screens/teacher/teacher_resources_tab.dart';
import 'package:ice_dept_app/screens/teacher/teacher_schedule_tab.dart';
import 'package:ice_dept_app/services/auth_service.dart';
import 'package:ice_dept_app/services/routine_service.dart';
import 'package:ice_dept_app/utils/routine_helper.dart';
import 'package:ice_dept_app/screens/teacher/teacher_attendance_history_screen.dart';
import 'package:ice_dept_app/utils/csv_exporter.dart';
import 'package:ice_dept_app/models/student_profile_model.dart';
import 'package:ice_dept_app/services/attendance_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MockAuthService extends ChangeNotifier implements AuthService {
  @override
  UserModel? currentUser = UserModel(
    id: '9d3b6545-1d6c-4d7d-8aed-ce5ef1589015',
    email: 'anwar.ice@pust.ac.bd',
    name: 'Prof. Dr. Md. Anwar Hossain',
    role: UserRole.teacher,
    initials: 'MAH',
    passwordChanged: true,
  );

  @override
  StudentProfileModel? get studentProfile => null;

  @override
  bool get isLoading => false;

  @override
  bool get isInitialized => true;

  @override
  bool get isAuthenticated => true;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class MockAuthServiceCustom extends ChangeNotifier implements AuthService {
  final UserModel? user;
  MockAuthServiceCustom(this.user);

  @override
  UserModel? get currentUser => user;

  @override
  StudentProfileModel? get studentProfile => null;

  @override
  bool get isLoading => false;

  @override
  bool get isInitialized => true;

  @override
  bool get isAuthenticated => true;

  @override
  Stream<AuthState> get authStateChanges => const Stream.empty();

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

Widget createTestableWidget(Widget child, [AuthService? authService]) {
  return ChangeNotifierProvider<AuthService>(
    create: (_) => authService ?? MockAuthService(),
    child: MaterialApp(
      theme: AppTheme.lightTheme,
      home: child,
    ),
  );
}

void main() {
  group('Step 1 & Step 2: Academic Calendar & Routine Sync Tests', () {
    test('academicDays constant strictly contains Saturday to Wednesday', () {
      expect(academicDays, equals(['Sat', 'Sun', 'Mon', 'Tue', 'Wed']));
      expect(academicDays.length, equals(5));
      expect(academicDays.contains('Thu'), isFalse);
      expect(academicDays.contains('Fri'), isFalse);
    });

    test('RoutineHelper.normalizeDayName normalizes short and lowercase day strings', () {
      expect(RoutineHelper.normalizeDayName('Sat'), equals('Saturday'));
      expect(RoutineHelper.normalizeDayName('sat'), equals('Saturday'));
      expect(RoutineHelper.normalizeDayName('Sunday'), equals('Sunday'));
      expect(RoutineHelper.normalizeDayName('sun'), equals('Sunday'));
      expect(RoutineHelper.normalizeDayName('Mon'), equals('Monday'));
      expect(RoutineHelper.normalizeDayName('tue'), equals('Tuesday'));
      expect(RoutineHelper.normalizeDayName('Wed'), equals('Wednesday'));
      expect(RoutineHelper.normalizeDayName('Thu'), equals('Thursday'));
      expect(RoutineHelper.normalizeDayName('fri'), equals('Friday'));
    });

    test('RoutineHelper course title lookup resolves all assigned teacher courses', () {
      expect(RoutineHelper.lookupCourseTitle('ICE-2202'), equals('Signals and Systems'));
      expect(RoutineHelper.lookupCourseTitle('ICE-4116'), equals('Cellular & Mobile Communication'));
      expect(RoutineHelper.lookupCourseTitle('ICE-4117'), equals('Mobile Communication Lab'));
      expect(RoutineHelper.lookupCourseTitle('ICE-1106'), equals('Structured Programming Lab'));
      expect(RoutineHelper.lookupCourseTitle('ICE-1105'), equals('Structured Programming Language'));
    });

    test('Dr. Anwar Hossain (MAH) routine query supports short day codes and case-insensitivity', () async {
      final routineService = RoutineService.instance;
      final satRoutines = await routineService.getRoutinesForTeacher(
        teacherInitial: 'MAH',
        dayOfWeek: 'Sat',
      );
      expect(satRoutines.length, equals(1));
      expect(satRoutines.first.courseCode, equals('ICE-2202'));
      expect(satRoutines.first.roomNumber, equals('921'));

      final satLowerRoutines = await routineService.getRoutinesForTeacher(
        teacherInitial: 'MAH',
        dayOfWeek: 'saturday',
      );
      expect(satLowerRoutines.length, equals(1));
      expect(satLowerRoutines.first.courseCode, equals('ICE-2202'));
    });

    test('Dr. Anwar Hossain (MAH) routine query returns complete Sat-Wed timetable', () async {
      final routineService = RoutineService.instance;
      final allRoutines = await routineService.getRoutinesForTeacher(teacherInitial: 'MAH');

      expect(allRoutines.isNotEmpty, isTrue);

      // Verify Saturday: ICE-2202 (2:00 PM, Room 921)
      final satRoutines = allRoutines.where((r) => r.dayOfWeek == 'Saturday').toList();
      expect(satRoutines.length, equals(1));
      expect(satRoutines.first.courseCode, equals('ICE-2202'));
      expect(satRoutines.first.startTime, equals('14:00:00'));
      expect(satRoutines.first.roomNumber, equals('921'));

      // Verify Sunday: ICE-4117 [Odd Week Lab], ICE-1106 (Room 920)
      final sunRoutines = allRoutines.where((r) => r.dayOfWeek == 'Sunday').toList();
      expect(sunRoutines.length, equals(2));
      final labClass = sunRoutines.firstWhere((r) => r.courseCode == 'ICE-4117');
      expect(labClass.isLab, isTrue);
      expect(labClass.weekParity, equals('odd'));
      final theoryClass = sunRoutines.firstWhere((r) => r.courseCode == 'ICE-1106');
      expect(theoryClass.roomNumber, equals('920'));

      // Verify Monday: ICE-2202 (11:00 AM, Room 903)
      final monRoutines = allRoutines.where((r) => r.dayOfWeek == 'Monday').toList();
      expect(monRoutines.length, equals(1));
      expect(monRoutines.first.courseCode, equals('ICE-2202'));
      expect(monRoutines.first.startTime, equals('11:00:00'));
      expect(monRoutines.first.roomNumber, equals('903'));

      // Verify Tuesday: ICE-4116 (11:00 AM - 1:00 PM, Room 904), ICE-2202 Lab
      final tueRoutines = allRoutines.where((r) => r.dayOfWeek == 'Tuesday').toList();
      expect(tueRoutines.length, equals(2));
      final c4116 = tueRoutines.firstWhere((r) => r.courseCode == 'ICE-4116');
      expect(c4116.startTime, equals('11:00:00'));
      expect(c4116.endTime, equals('13:00:00'));
      expect(c4116.roomNumber, equals('904'));
      final c2202Lab = tueRoutines.firstWhere((r) => r.courseCode == 'ICE-2202');
      expect(c2202Lab.isLab, isTrue);

      // Verify Wednesday: ICE-4116 (9:00 AM, Room 904)
      final wedRoutines = allRoutines.where((r) => r.dayOfWeek == 'Wednesday').toList();
      expect(wedRoutines.length, equals(1));
      expect(wedRoutines.first.courseCode, equals('ICE-4116'));
      expect(wedRoutines.first.startTime, equals('09:00:00'));
      expect(wedRoutines.first.roomNumber, equals('904'));
    });

    test('Dr. Anwar Hossain (MAH) workload totals exactly 9 hours across 4 courses and 3 batches', () async {
      final routineService = RoutineService.instance;
      final routines = await routineService.getRoutinesForTeacher(teacherInitial: 'MAH');

      // 1. Active Courses count = 4 (ICE-2202, ICE-4117, ICE-1106, ICE-4116)
      final uniqueCourses = routines.map((r) => r.courseCode).toSet();
      expect(uniqueCourses.length, equals(4));

      // 2. Weekly Workload = exactly 9 hours
      int totalMinutes = 0;
      for (final r in routines) {
        final start = r.startTime.split(':');
        final end = r.endTime.split(':');
        final sMin = int.parse(start[0]) * 60 + int.parse(start[1]);
        final eMin = int.parse(end[0]) * 60 + int.parse(end[1]);
        totalMinutes += (eMin - sMin);
      }
      expect(totalMinutes / 60, equals(9.0));

      // 3. Target Batches: ICE-14, ICE-16, ICE-18
      final batches = routines.map((r) => r.batch).toSet();
      expect(batches, containsAll(['ICE-14', 'ICE-16', 'ICE-18']));
    });

    test('DepartmentRoutineModel toRoutineModel converts cleanly for attendance QR session', () {
      final deptRoutine = DepartmentRoutineModel(
        id: 'test-routine-1',
        batch: 'ICE-18',
        dayOfWeek: 'Saturday',
        startTime: '14:00:00',
        endTime: '15:00:00',
        courseCode: 'ICE-2202',
        teacherInitial: 'MAH',
        roomNumber: '921',
      );

      final model = deptRoutine.toRoutineModel();
      expect(model.id, equals('test-routine-1'));
      expect(model.batchNumber, equals(18));
      expect(model.dayOfWeek, equals(DateTime.saturday));
      expect(model.courseName, contains('ICE-2202'));
      expect(model.courseName, contains('Signals and Systems'));
      expect(model.roomNumber, equals('921'));
    });
  });

  group('Step 3: Teacher Dashboard Home Tab Widget Tests', () {
    testWidgets('Renders Profile Card with bold [MAH] avatar and Professor & Chairman designation', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestableWidget(
        TeacherHomeScreen(onNavigateTab: (_) {}),
      ));
      await tester.pumpAndSettle();

      // Check initials avatar
      expect(find.text('[MAH]'), findsOneWidget);

      // Check teacher name
      expect(find.text('Prof. Dr. Md. Anwar Hossain'), findsWidgets);

      // Check designation pill
      expect(find.text('Professor & Chairman'), findsOneWidget);

      // Check Step 1 Dynamic Assigned Courses Card (replaced vanity cards)
      expect(find.text('4 Active Courses Assigned'), findsOneWidget);
      expect(find.text('ICE-2202'), findsWidgets);
      expect(find.textContaining('Batch 14'), findsWidgets);
      expect(find.textContaining('Batch 18'), findsWidgets);
    });

    testWidgets('Renders Hero Attendance Launcher, Recent Attendance Logs, and dual-column desktop layout', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // On weekend Friday
      await tester.pumpWidget(createTestableWidget(
        TeacherHomeScreen(onNavigateTab: (_) {}, referenceDate: DateTime(2026, 9, 4)),
      ));
      await tester.pumpAndSettle();

      // Hero attendance launcher card on weekend
      expect(find.textContaining('Next Lecture'), findsOneWidget);
      expect(find.textContaining('Saturday 2:00 PM'), findsOneWidget);

      // Recent Attendance Logs in right column
      expect(find.text('Recent Attendance Logs'), findsOneWidget);
      expect(find.text('Verified'), findsWidgets);

      // Quick shortcuts and security badge
      expect(find.text('Faculty Quick Actions'), findsOneWidget);
      expect(find.text('Anti-Proxy QR Protocol Active'), findsOneWidget);
    });

    testWidgets('Renders responsive single-column layout on mobile viewports without overflow', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestableWidget(
        TeacherHomeScreen(onNavigateTab: (_) {}),
      ));
      await tester.pumpAndSettle();

      // Verify all components exist in single scrollable mobile stack
      expect(find.text('[MAH]'), findsOneWidget);
      expect(find.text('Recent Attendance Logs'), findsOneWidget);
      expect(find.text('Faculty Quick Actions'), findsOneWidget);
      expect(find.text('Anti-Proxy QR Protocol Active'), findsOneWidget);
    });
  });

  group('Step 1: Teacher Schedule Tab Widget Tests', () {
    testWidgets('Renders official academic day tabs (Sat, Sun, Mon, Tue, Wed) and switches routines', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestableWidget(
        TeacherScheduleTab(referenceDate: DateTime(2026, 9, 4)),
      ));
      await tester.pumpAndSettle();

      // Check academic day pills
      expect(find.text('Sat'), findsOneWidget);
      expect(find.text('Sun'), findsOneWidget);
      expect(find.text('Mon'), findsOneWidget);
      expect(find.text('Tue'), findsOneWidget);
      expect(find.text('Wed'), findsOneWidget);
      expect(find.text('Thu'), findsNothing);
      expect(find.text('Fri'), findsNothing);

      // On weekend (today is Friday), banner appears with default Saturday timetable
      expect(find.text('Weekend / Off Day'), findsOneWidget);
      expect(find.textContaining("Displaying Saturday's timetable by default."), findsOneWidget);

      // Tap Saturday tab
      await tester.tap(find.text('Sat'));
      await tester.pumpAndSettle();
      expect(find.text('ICE-2202'), findsOneWidget);
      expect(find.text('Signals and Systems'), findsOneWidget);
      expect(find.textContaining('Room 921'), findsOneWidget);

      // Tap Sunday tab - banner dynamically updates message
      await tester.tap(find.text('Sun'));
      await tester.pumpAndSettle();
      expect(find.textContaining("Viewing Sunday's timetable."), findsOneWidget);
      expect(find.text('ICE-4117'), findsOneWidget);
      expect(find.text('ODD WEEK LAB'), findsOneWidget);
      expect(find.text('ICE-1106'), findsOneWidget);

      // Tap Tuesday tab - verifies both theory and lab session
      await tester.tap(find.text('Tue'));
      await tester.pumpAndSettle();
      expect(find.textContaining("Viewing Tuesday's timetable."), findsOneWidget);
      expect(find.text('ICE-4116'), findsOneWidget);
      expect(find.text('Cellular & Mobile Communication'), findsOneWidget);
      expect(find.textContaining('Room 904'), findsOneWidget);
      expect(find.text('ICE-2202'), findsOneWidget);
      expect(find.text('LAB SESSION'), findsOneWidget);

      // Tap Wednesday tab
      await tester.tap(find.text('Wed'));
      await tester.pumpAndSettle();
      expect(find.text('ICE-4116'), findsOneWidget);
    });
  });

  group('Step 4: Direct CR Channel & Materials Vault Widget Tests', () {
    testWidgets('Direct CR Channel renders CR list for Batches 14, 16, 18 and Post Notice button', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestableWidget(
        const TeacherDirectInboxScreen(),
      ));
      await tester.pumpAndSettle();

      // Post Notice to Class button
      expect(find.text('Post Notice to Class'), findsOneWidget);

      // Check instructed batches CR entries
      expect(find.textContaining('Batch 14'), findsWidgets);
      expect(find.textContaining('Batch 16'), findsWidgets);
      expect(find.textContaining('Batch 18'), findsWidgets);

      // Tap Post Notice button to verify dialog opens
      await tester.tap(find.text('Post Notice to Class'));
      await tester.pumpAndSettle();

      expect(find.text('Notice Title'), findsOneWidget);
      expect(find.text('Broadcast Notice'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });

    testWidgets('Teacher Resources Tab filters to 4 assigned courses with + Upload Handout button', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestableWidget(
        const TeacherResourcesTab(),
      ));
      await tester.pumpAndSettle();

      // 4 assigned subjects
      expect(find.text('ICE-1105'), findsOneWidget);
      expect(find.text('ICE-2202'), findsOneWidget);
      expect(find.text('ICE-4116'), findsOneWidget);
      expect(find.text('ICE-4117'), findsOneWidget);

      // + Upload Handout / Slide buttons inside cards
      expect(find.text('+ Upload Handout / Slide'), findsNWidgets(4));

      // Tap upload on first course
      await tester.tap(find.text('+ Upload Handout / Slide').first);
      await tester.pumpAndSettle();

      expect(find.text('Document Title'), findsOneWidget);
      expect(find.text('Upload Document'), findsOneWidget);

      // Close dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
    });
  });

  group('Step 2, 3 & 4: Cancel Class, Reschedule, History & CSV Tests', () {
    testWidgets('Today hero card shows Cancel Class and Reschedule actions on academic day', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Saturday at 13:00 (before 14:00 class)
      await tester.pumpWidget(createTestableWidget(
        TeacherHomeScreen(
          onNavigateTab: (_) {},
          referenceDate: DateTime(2026, 9, 5, 13, 0),
        ),
      ));
      await tester.pumpAndSettle();

      expect(find.text('CLASS SCHEDULED TODAY'), findsOneWidget);
      expect(find.text('ICE-2202'), findsWidgets);
      expect(find.text('Cancel Class'), findsOneWidget);
      expect(find.text('Reschedule'), findsWidgets);

      // Tap Cancel Class opens dialog
      await tester.tap(find.text('Cancel Class'));
      await tester.pumpAndSettle();

      expect(find.text('Cancel Class Today'), findsOneWidget);
      expect(find.text('Reason for cancellation:'), findsOneWidget);

      // Dismiss dialog cleanly
      await tester.tap(find.text('Keep Class'));
      await tester.pumpAndSettle();
      expect(find.text('Cancel Class Today'), findsNothing);

      // Tap Reschedule opens reschedule dialog
      await tester.tap(find.text('Reschedule').first);
      await tester.pumpAndSettle();

      expect(find.text('Reschedule Class'), findsOneWidget);
      expect(find.text('New Time Slot:'), findsOneWidget);
      expect(find.text('New Room Number:'), findsOneWidget);

      // Dismiss reschedule dialog
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text('Cancel')));
      await tester.pumpAndSettle();
      expect(find.text('Reschedule Class'), findsNothing);
    });

    testWidgets('TeacherAttendanceHistoryScreen renders batch filter pills, sessions, and roster modal', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestableWidget(
        const TeacherAttendanceHistoryScreen(),
      ));
      await tester.pumpAndSettle();

      // Verify header
      expect(find.text('Attendance Records & Logs'), findsOneWidget);
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Batch 14'), findsWidgets);
      expect(find.text('Batch 18'), findsWidgets);

      // Sessions list
      expect(find.text('ICE-2202'), findsOneWidget);
      expect(find.text('ICE-4116'), findsOneWidget);

      // Tap session to open student roster modal
      await tester.tap(find.text('ICE-2202'));
      await tester.pumpAndSettle();

      expect(find.text('Student Roster'), findsOneWidget);
      expect(find.text('Alex Rahman'), findsOneWidget);
      expect(find.text('2108001'), findsOneWidget);
      expect(find.text('Export CSV'), findsWidgets);

      // Tap toggle icon to flip status
      final toggleFinder = find.byIcon(Icons.check_circle_rounded).first;
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      // Student is now marked ABSENT
      expect(find.text('ABSENT'), findsWidgets);
    });

    test('exportCsvFile saves file in test environment without hanging', () async {
      final res = await exportCsvFile(csvContent: 'test', fileName: 'test.csv');
      expect(res, isNotNull);
      expect(File(res!).existsSync(), isTrue);
    });

    test('Attendance CSV builder generates expected format according to specification', () {
      final rows = [
        AttendanceCsvRow(
          rollNumber: '2108001',
          studentName: 'Alex Rahman',
          status: 'PRESENT',
          courseCode: 'ICE-2202',
          batch: 'Batch 18',
          date: '2026-09-05',
        ),
        AttendanceCsvRow(
          rollNumber: '2108002',
          studentName: 'Sarah Khan',
          status: 'PRESENT',
          courseCode: 'ICE-2202',
          batch: 'Batch 18',
          date: '2026-09-05',
        ),
        AttendanceCsvRow(
          rollNumber: '2108003',
          studentName: 'Tanvir Hossain',
          status: 'ABSENT',
          courseCode: 'ICE-2202',
          batch: 'Batch 18',
          date: '2026-09-05',
        ),
      ];

      final csvString = buildAttendanceCsv(rows);
      expect(
        csvString.split('\n')[0].trim(),
        equals('Roll Number,Student Name,Status,Course Code,Batch,Date'),
      );
      expect(csvString, contains('2108001,"Alex Rahman",PRESENT,ICE-2202,Batch 18,2026-09-05'));
      expect(csvString, contains('2108002,"Sarah Khan",PRESENT,ICE-2202,Batch 18,2026-09-05'));
      expect(csvString, contains('2108003,"Tanvir Hossain",ABSENT,ICE-2202,Batch 18,2026-09-05'));
    });

    testWidgets('Cancelling one class does not cancel another class with the same course code', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      // Tuesday has both ICE-4116 (11:00 AM) and ICE-2202 Lab (14:00 PM)
      await tester.pumpWidget(createTestableWidget(
        TeacherHomeScreen(
          onNavigateTab: (_) {},
          referenceDate: DateTime(2026, 9, 8, 10, 0), // Tuesday 10:00 AM
        ),
      ));
      await tester.pumpAndSettle();

      // Find mini routine items
      expect(find.text('Today\'s Class Schedule'), findsOneWidget);
      expect(find.text('Cancel'), findsWidgets);

      // Cancel the first class (ICE-4116)
      await tester.tap(find.text('Cancel').first);
      await tester.pumpAndSettle();

      // Confirm cancel
      await tester.tap(find.text('Confirm Cancel'));
      await tester.pumpAndSettle();

      // The cancelled class now shows Class Cancelled for Today badge
      expect(find.text('Class Cancelled for Today'), findsWidgets);

      // The other class on Tuesday still has its Cancel button available (not cancelled)
      expect(find.text('Cancel'), findsWidgets);
    });

    testWidgets('Teacher with no assigned routines shows No Active Courses Assigned instead of MAH fallback', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final unknownTeacher = UserModel(
        id: 'unknown-id-123',
        email: 'new.faculty@pust.ac.bd',
        name: 'New Faculty Member',
        role: UserRole.teacher,
        initials: 'NFM',
        passwordChanged: true,
      );

      await tester.pumpWidget(createTestableWidget(
        TeacherHomeScreen(
          onNavigateTab: (_) {},
          referenceDate: DateTime(2026, 9, 5, 10, 0),
        ),
        MockAuthServiceCustom(unknownTeacher),
      ));
      await tester.pumpAndSettle();

      expect(find.text('No Active Courses Assigned'), findsOneWidget);
      expect(find.text('No routine records found for faculty'), findsOneWidget);
      expect(find.text('4 Active Courses Assigned'), findsNothing);
    });

    testWidgets('TeacherAttendanceHistoryScreen retains all batch options when initialBatch is passed', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestableWidget(
        const TeacherAttendanceHistoryScreen(initialBatch: 'Batch 18'),
      ));
      await tester.pumpAndSettle();

      // All batch pills must still be available
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Batch 14'), findsWidgets);
      expect(find.text('Batch 16'), findsWidgets);
      expect(find.text('Batch 18'), findsWidgets);

      // Filtered to Batch 18: only ICE-2202 appears in session list, ICE-4116 is filtered out
      expect(find.text('ICE-2202'), findsOneWidget);
      expect(find.text('ICE-4116'), findsNothing);

      // Tap 'All' chip
      await tester.tap(find.text('All'));
      await tester.pumpAndSettle();

      // Now ICE-4116 appears as well
      expect(find.text('ICE-4116'), findsOneWidget);
    });

    test('AttendanceService updateRecordStatus sets scannedAt when PRESENT and clears when ABSENT', () async {
      final service = AttendanceService();
      // Test setting status to PRESENT sets scannedAt
      await service.updateRecordStatus(
        recordId: 'rec-3', // Tanvir Hossain, originally ABSENT
        status: 'PRESENT',
      );

      final records = await service.getSessionRecords('sess-mah-1');
      final updatedRec = records.firstWhere((r) => r.id == 'rec-3');
      expect(updatedRec.status, equals('PRESENT'));
      expect(updatedRec.scannedAt, isNotNull);

      // Toggle back to ABSENT clears scannedAt
      await service.updateRecordStatus(
        recordId: 'rec-3',
        status: 'ABSENT',
      );

      final recordsAbsent = await service.getSessionRecords('sess-mah-1');
      final absentRec = recordsAbsent.firstWhere((r) => r.id == 'rec-3');
      expect(absentRec.status, equals('ABSENT'));
      expect(absentRec.scannedAt, isNull);
    });

    testWidgets('Toggling student status in modal updates live roster before CSV export', (tester) async {
      tester.view.physicalSize = const Size(1280, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(createTestableWidget(
        const TeacherAttendanceHistoryScreen(),
      ));
      await tester.pumpAndSettle();

      // Open ICE-2202 modal
      await tester.tap(find.text('ICE-2202'));
      await tester.pumpAndSettle();

      // Initially Tanvir Hossain is listed
      expect(find.text('Tanvir Hossain'), findsOneWidget);
      expect(find.text('ABSENT'), findsWidgets);

      // Toggle first absent student (Tanvir Hossain / rec-3) to PRESENT
      final cancelIconFinder = find.byIcon(Icons.cancel_rounded);
      expect(cancelIconFinder, findsWidgets);
      await tester.tap(cancelIconFinder.first);
      await tester.pumpAndSettle();

      // Verified toggle snackbar appeared
      expect(find.textContaining('marked PRESENT'), findsOneWidget);

      // Tap modal Export CSV button
      final modalExportBtn = find.widgetWithText(ElevatedButton, 'Export CSV');
      expect(modalExportBtn, findsOneWidget);
      await tester.tap(modalExportBtn);
      await tester.pumpAndSettle();

      // Verify success snackbar with count
      expect(find.textContaining('Exported 6 records'), findsOneWidget);
    });
  });
}
