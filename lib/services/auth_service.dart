import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user_model.dart';
import '../models/student_profile_model.dart';
import 'supabase_service.dart';

class AuthService extends ChangeNotifier {
  SupabaseClient get _client => SupabaseService.instance.client;
  
  UserModel? _currentUser;
  StudentProfileModel? _studentProfile;
  bool _isLoading = false;
  bool _isInitialized = false;

  UserModel? get currentUser => _currentUser;
  StudentProfileModel? get studentProfile => _studentProfile;
  bool get isLoading => _isLoading;
  bool get isInitialized => _isInitialized;
  bool get isAuthenticated => _client.auth.currentUser != null;

  Stream<AuthState> get authStateChanges => _client.auth.onAuthStateChange;

  AuthService() {
    _init();
  }

  Future<void> _init() async {
    try {
      if (_client.auth.currentUser != null) {
        await refreshCurrentUser();
      }
    } catch (e) {
      if (kDebugMode) {
        print('AuthService init error: $e');
      }
    } finally {
      _isInitialized = true;
      notifyListeners();
    }

    _client.auth.onAuthStateChange.listen((data) async {
      final AuthChangeEvent event = data.event;
      if (event == AuthChangeEvent.signedIn ||
          event == AuthChangeEvent.tokenRefreshed ||
          event == AuthChangeEvent.userUpdated) {
        await refreshCurrentUser();
      } else if (event == AuthChangeEvent.signedOut) {
        _currentUser = null;
        _studentProfile = null;
        notifyListeners();
      }
    });
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Sign in with email and password
  Future<UserModel> signIn({
    required String email,
    required String password,
  }) async {
    _setLoading(true);
    try {
      final response = await _client.auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      final user = response.user;
      if (user == null) {
        throw const AuthException('Invalid login credentials');
      }

      await refreshCurrentUser();
      return _currentUser!;
    } finally {
      _setLoading(false);
    }
  }

  /// Mandatory Password Update for first-time login
  Future<void> updateMandatoryPassword(String newPassword) async {
    _setLoading(true);
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        throw const AuthException('No active user session found');
      }

      // Update password in Supabase Auth
      await _client.auth.updateUser(
        UserAttributes(password: newPassword),
      );

      // Update password_changed flag in public.users table
      await _client
          .from('users')
          .update({'password_changed': true})
          .eq('id', user.id);

      // Refresh cached user model
      if (_currentUser != null) {
        _currentUser = _currentUser!.copyWith(passwordChanged: true);
      }
      notifyListeners();
    } finally {
      _setLoading(false);
    }
  }

  /// Fetch full user record from public.users table
  Future<UserModel?> refreshCurrentUser() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      _currentUser = null;
      _studentProfile = null;
      notifyListeners();
      return null;
    }

    try {
      final response = await _client
          .from('users')
          .select()
          .eq('id', user.id)
          .maybeSingle();

      if (response != null) {
        _currentUser = UserModel.fromJson(response);

        // If the user is a student, also load their student profile
        if (_currentUser!.role == UserRole.student) {
          await _loadStudentProfile(user.id);
        }
      } else {
        // Fallback profile from auth metadata if DB record is syncing
        _currentUser = UserModel(
          id: user.id,
          email: user.email ?? '',
          name: user.userMetadata?['name'] ?? user.email?.split('@').first ?? 'User',
          role: UserRole.fromString(user.userMetadata?['role'] ?? 'student'),
          passwordChanged: user.userMetadata?['password_changed'] ?? false,
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error refreshing user profile: $e');
      }
    }

    notifyListeners();
    return _currentUser;
  }

  Future<void> _loadStudentProfile(String userId) async {
    try {
      var response = await _client
          .from('student_profiles')
          .select('*, batches(batch_number)')
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        // Auto-provision student profile for default Batch 21
        final batchRes = await _client.from('batches').select('id, batch_number').eq('batch_number', 21).maybeSingle();
        final defaultBatchId = batchRes?['id'] as String? ?? 'cba1ba2e-d3ae-49c6-9d35-ae5753a224dc';

        await _client.from('student_profiles').upsert({
          'user_id': userId,
          'batch_id': defaultBatchId,
          'is_cr': false,
          'student_id_roll': '2108001',
          'current_semester': '3-1',
        });

        response = await _client
            .from('student_profiles')
            .select('*, batches(batch_number)')
            .eq('user_id', userId)
            .maybeSingle();
      }

      if (response != null) {
        _studentProfile = StudentProfileModel.fromJson(response);
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error loading student profile: $e');
      }
    }
  }

  /// Sign out
  Future<void> signOut() async {
    _setLoading(true);
    try {
      await _client.auth.signOut();
      _currentUser = null;
      _studentProfile = null;
    } finally {
      _setLoading(false);
    }
  }
}
