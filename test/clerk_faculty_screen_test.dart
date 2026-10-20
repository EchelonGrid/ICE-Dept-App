import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ice_dept_app/models/user_model.dart';
import 'package:ice_dept_app/screens/admin/clerk_faculty_screen.dart';

void main() {
  final testFaculty = [
    UserModel(
      id: 'teach-1',
      name: 'Prof. Dr. Md. Anwar Hossain',
      email: 'anwar@ice.dept',
      role: UserRole.teacher,
      initials: 'MAH',
    ),
    UserModel(
      id: 'teach-2',
      name: 'Dr. Md. Imran Hossain',
      email: 'imran@ice.dept',
      role: UserRole.teacher,
      initials: 'MIH',
    ),
    UserModel(
      id: 'teach-3',
      name: 'Akif Mahdi',
      email: 'akif@ice.dept',
      role: UserRole.teacher,
      initials: 'AM',
    ),
  ];

  Widget buildTestableWidget(Widget child) {
    return MaterialApp(
      home: Scaffold(
        body: child,
      ),
    );
  }

  testWidgets('ClerkFacultyScreen renders faculty cards with initials, badge, designation, and mock email', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildTestableWidget(
        ClerkFacultyScreen(
          isEmbedded: true,
          initialFaculty: testFaculty,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title
    expect(find.text('Official ICE Faculty Directory'), findsOneWidget);

    // Verify Teacher names
    expect(find.text('Dr. Md. Imran Hossain'), findsOneWidget);
    expect(find.text('Prof. Dr. Md. Anwar Hossain'), findsOneWidget);
    expect(find.text('Akif Mahdi'), findsOneWidget);

    // Verify Monospace Badges
    expect(find.text('[MIH]'), findsOneWidget);
    expect(find.text('[MAH]'), findsOneWidget);
    expect(find.text('[AM]'), findsOneWidget);

    // Verify Initials in Avatar circle
    expect(find.text('MIH'), findsWidgets);
    expect(find.text('MAH'), findsWidgets);
    expect(find.text('AM'), findsWidgets);

    // Verify Designations
    expect(find.text('Associate Professor'), findsWidgets);
    expect(find.text('Professor'), findsWidgets);
    expect(find.text('Lecturer'), findsWidgets);

    // Verify Emails
    expect(find.text('imran@ice.dept'), findsOneWidget);
    expect(find.text('anwar@ice.dept'), findsOneWidget);
    expect(find.text('akif@ice.dept'), findsOneWidget);

    // Verify Edit Action Button exists
    expect(find.byIcon(Icons.edit_outlined), findsWidgets);
  });

  testWidgets('ClerkFacultyScreen search filters faculty members accurately', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildTestableWidget(
        ClerkFacultyScreen(
          isEmbedded: true,
          initialFaculty: testFaculty,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Search for "Imran"
    await tester.enterText(find.byType(TextField), 'Imran');
    await tester.pumpAndSettle();

    expect(find.text('Dr. Md. Imran Hossain'), findsOneWidget);
    expect(find.text('Prof. Dr. Md. Anwar Hossain'), findsNothing);
    expect(find.text('Akif Mahdi'), findsNothing);

    // Clear search
    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();

    expect(find.text('Dr. Md. Imran Hossain'), findsOneWidget);
    expect(find.text('Prof. Dr. Md. Anwar Hossain'), findsOneWidget);
    expect(find.text('Akif Mahdi'), findsOneWidget);
  });

  testWidgets('ClerkFacultyScreen opens Edit Faculty dialog on edit button tap and cancels cleanly', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildTestableWidget(
        ClerkFacultyScreen(
          isEmbedded: true,
          initialFaculty: testFaculty,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap first edit icon
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();

    expect(find.text('Edit Faculty Member'), findsOneWidget);
    expect(find.text('Save Changes'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);

    // Tap cancel to close dialog
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(find.text('Edit Faculty Member'), findsNothing);
  });

  testWidgets('ClerkFacultyScreen saves edited faculty member and immediately reflects updates in UI', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildTestableWidget(
        ClerkFacultyScreen(
          isEmbedded: true,
          initialFaculty: testFaculty,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Tap edit icon on the second faculty member (Dr. Md. Imran Hossain)
    final editIcons = find.byIcon(Icons.edit_outlined);
    expect(editIcons, findsWidgets);
    await tester.tap(editIcons.at(1));
    await tester.pumpAndSettle();

    expect(find.text('Edit Faculty Member'), findsOneWidget);

    // Find Name and Initials TextFormFields in Dialog
    final textFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextFormField),
    );
    // TextFormField 0: Name, 1: Initials, 2: Email
    await tester.enterText(textFields.at(0), 'Dr. Md. Imran Hossain Updated');
    await tester.enterText(textFields.at(1), 'MIHU');
    await tester.pump();

    // Tap Save Changes
    await tester.tap(find.text('Save Changes'));
    await tester.pumpAndSettle();

    // Verify dialog closed and updated name/badge appears in UI
    expect(find.text('Edit Faculty Member'), findsNothing);
    expect(find.text('Dr. Md. Imran Hossain Updated'), findsOneWidget);
    expect(find.text('[MIHU]'), findsOneWidget);
  });

  testWidgets('ClerkFacultyScreen responds to didUpdateWidget when initialFaculty changes', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final initialList = [testFaculty[0]];
    await tester.pumpWidget(
      buildTestableWidget(
        ClerkFacultyScreen(
          isEmbedded: true,
          initialFaculty: initialList,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prof. Dr. Md. Anwar Hossain'), findsOneWidget);
    expect(find.text('Dr. Md. Imran Hossain'), findsNothing);

    // Update with full list
    await tester.pumpWidget(
      buildTestableWidget(
        ClerkFacultyScreen(
          isEmbedded: true,
          initialFaculty: testFaculty,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Prof. Dr. Md. Anwar Hossain'), findsOneWidget);
    expect(find.text('Dr. Md. Imran Hossain'), findsOneWidget);
    expect(find.text('Akif Mahdi'), findsOneWidget);
  });

  testWidgets('ClerkFacultyScreen falls back to official list of 13 faculty when initialFaculty is null', (tester) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      buildTestableWidget(
        const ClerkFacultyScreen(
          isEmbedded: true,
          initialFaculty: null,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify official faculty member initials badges are present
    final expectedInitials = ['AM', 'DAF', 'KK', 'MAH', 'MAR', 'MIH', 'MIK', 'MKIC', 'MOF', 'MSH', 'SS', 'TD', 'TNT'];
    for (final init in expectedInitials) {
      expect(find.text('[$init]'), findsOneWidget);
    }
  });
}
