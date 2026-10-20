import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../models/user_model.dart';
import '../../models/chat_message_model.dart';
import '../../services/auth_service.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/force_password_change_screen.dart';
import '../../screens/admin/admin_dashboard_screen.dart';
import '../../screens/admin/batch_details_screen.dart';
import '../../screens/teacher/teacher_main_screen.dart';
import '../../screens/student/student_main_screen.dart';
import '../../features/resources/resource_screen.dart';
import '../../screens/chat/chat_list_screen.dart';
import '../../screens/chat/info_channel_screen.dart';
import '../../screens/chat/open_group_screen.dart';

class AppRouter {
  static GoRouter createRouter(AuthService authService) {
    return GoRouter(
      initialLocation: '/login',
      debugLogDiagnostics: true,
      errorBuilder: (context, state) => Scaffold(
        backgroundColor: const Color(0xFF0F172A),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, color: Color(0xFFEF4444), size: 48),
                const SizedBox(height: 16),
                const Text(
                  'Navigation Routing Error',
                  style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Text(
                  state.error?.toString() ?? 'Unknown route exception',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 13),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/login'),
                  child: const Text('Return to Login'),
                ),
              ],
            ),
          ),
        ),
      ),
      refreshListenable: authService,
      redirect: (BuildContext context, GoRouterState state) {
        // Wait for AuthService to restore initial session before routing
        if (!authService.isInitialized) {
          return null;
        }

        final isAuthenticated = authService.isAuthenticated;
        final user = authService.currentUser;
        final isLoggingIn = state.matchedLocation == '/login';
        final isForceChange = state.matchedLocation == '/force-password-change';

        if (!isAuthenticated || user == null) {
          return isLoggingIn ? null : '/login';
        }

        // Force password change on first login
        if (!user.passwordChanged) {
          return isForceChange ? null : '/force-password-change';
        }

        // If authenticated and password is changed, prevent access to login / force change
        if (isLoggingIn || isForceChange) {
          switch (user.role) {
            case UserRole.admin:
              return '/admin';
            case UserRole.teacher:
              return '/teacher';
            case UserRole.student:
              return '/student';
          }
        }

        // Restrict all Chat routes exclusively to students (including CRs) and admins/clerks
        // Forcefully redirect teachers to their home dashboard if attempting to access /chat or /chat/*
        if (user.role == UserRole.teacher && state.matchedLocation.startsWith('/chat')) {
          return '/teacher';
        }

        return null;
      },
      routes: [
        GoRoute(
          path: '/login',
          builder: (context, state) => const LoginScreen(),
        ),
        GoRoute(
          path: '/force-password-change',
          builder: (context, state) {
            final user = authService.currentUser;
            return ForcePasswordChangeScreen(
              user: user ?? UserModel(
                id: '',
                email: '',
                name: 'User',
                role: UserRole.student,
              ),
            );
          },
        ),
        GoRoute(
          path: '/admin',
          builder: (context, state) => const AdminDashboardScreen(),
        ),
        GoRoute(
          path: '/admin/batch/:batchName',
          name: 'batch_details',
          builder: (context, state) {
            final param = state.pathParameters['batchName'] ?? 'Batch';
            final extra = state.extra;

            String? batchId;
            String? batchName;
            int? batchNumber;

            if (extra is Map<String, dynamic>) {
              batchId = extra['batchId'] as String?;
              batchNumber = extra['batchNumber'] as int?;
              batchName = extra['batchName'] as String?;
            } else if (extra is String) {
              batchName = extra;
            }

            final isUuid = RegExp(
              r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
            ).hasMatch(param);

            if (isUuid) {
              batchId ??= param;
            } else {
              batchName ??= param;
            }

            return BatchDetailsScreen(
              batchId: batchId,
              batchNumber: batchNumber,
              batchName: batchName ?? 'Batch',
            );
          },
        ),
        GoRoute(
          path: '/teacher',
          builder: (context, state) => const TeacherMainScreen(),
        ),
        GoRoute(
          path: '/student',
          builder: (context, state) => const StudentMainScreen(),
        ),
        GoRoute(
          path: '/resources',
          builder: (context, state) => const ResourceScreen(),
        ),
        GoRoute(
          path: '/chat',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            final sharedText = state.uri.queryParameters['sharedText'] ?? extra?['sharedText'] as String?;
            return ChatListScreen(sharedText: sharedText);
          },
        ),
        GoRoute(
          path: '/chat/info',
          builder: (context, state) => const InfoChannelScreen(),
        ),
        GoRoute(
          path: '/chat/open',
          builder: (context, state) {
            final extra = state.extra as Map<String, dynamic>?;
            final scopeParam = state.uri.queryParameters['scope'] ?? extra?['scope'] as String?;
            final scope = ChatScope.fromString(scopeParam);
            final initialDraftText = state.uri.queryParameters['text'] ?? extra?['initialDraftText'] as String?;

            return OpenGroupScreen(
              scope: scope,
              initialReferencedNoticeId: extra?['referencedNoticeId'] as String?,
              initialReferencedNoticeTitle: extra?['referencedNoticeTitle'] as String?,
              initialDraftText: initialDraftText,
            );
          },
        ),
      ],
    );
  }
}
