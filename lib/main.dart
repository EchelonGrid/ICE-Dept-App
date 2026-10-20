import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'core/theme/app_theme.dart';
import 'core/routes/app_router.dart';
import 'services/auth_service.dart';
import 'services/supabase_service.dart';
import 'services/share_intent_service.dart';
import 'services/theme_service.dart';

void main() async {
  // Step 1: Secure Flutter Engine Binding Synchronously as absolute first line
  WidgetsFlutterBinding.ensureInitialized();

  // Step 2: Inject Global Error Handlers for Console & Terminal Visibility
  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.presentError(details);
    debugPrint('[FLUTTER ERROR CAUGHT]: ${details.exceptionAsString()}');
    if (details.stack != null) {
      debugPrint('[STACK TRACE]: ${details.stack}');
    }
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    debugPrint('[PLATFORM ERROR CAUGHT]: $error');
    debugPrint('[STACK TRACE]: $stack');
    return true;
  };

  // Step 3: Complete Supabase & Theme initialization before launching UI
  try {
    debugPrint('[BOOTSTRAP]: Initializing Supabase...');
    await SupabaseService.initialize();
    debugPrint('[BOOTSTRAP]: Supabase initialized successfully.');
  } catch (e, stack) {
    debugPrint('[BOOTSTRAP ERROR]: Supabase initialization failed: $e\n$stack');
  }

  await ThemeService.instance.initialize();

  // Step 4: Initialize Auth Service & Run App
  final authService = AuthService();
  runApp(
    ChangeNotifierProvider.value(
      value: authService,
      child: ICEDepartmentApp(authService: authService),
    ),
  );
}

class ICEDepartmentApp extends StatefulWidget {
  final AuthService authService;
  const ICEDepartmentApp({super.key, required this.authService});

  @override
  State<ICEDepartmentApp> createState() => _ICEDepartmentAppState();
}

class _ICEDepartmentAppState extends State<ICEDepartmentApp> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = AppRouter.createRouter(widget.authService);

    // Initialize native OS share listener (e.g. YouTube, Browser, external apps)
    ShareIntentService.instance.initialize(_router);
  }

  @override
  void dispose() {
    ShareIntentService.instance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: ThemeService.instance,
      builder: (context, _) {
        return MaterialApp.router(
          title: 'ICE Department App',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: ThemeService.instance.themeMode,
          themeAnimationDuration: Duration.zero,
          routerConfig: _router,
        );
      },
    );
  }
}

