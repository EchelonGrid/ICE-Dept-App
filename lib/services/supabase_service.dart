import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/app_constants.dart';

class SupabaseService {
  static SupabaseService? _instance;
  static SupabaseService get instance => _instance ??= SupabaseService._();

  SupabaseService._();

  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: ".env");
    } catch (e) {
      // On web or environments where .env is unavailable as asset, fallback to defaults
      // ignore: avoid_print
      print('Notice: .env file not loaded from asset, using default configuration ($e)');
    }

    final supabaseUrl = dotenv.env[AppConstants.envSupabaseUrl] ?? AppConstants.defaultSupabaseUrl;
    final supabaseAnonKey = dotenv.env[AppConstants.envSupabaseAnonKey] ?? AppConstants.defaultSupabaseAnonKey;

    await Supabase.initialize(
      url: supabaseUrl,
      // ignore: deprecated_member_use
      anonKey: supabaseAnonKey,
      realtimeClientOptions: const RealtimeClientOptions(
        eventsPerSecond: 10,
      ),
    );
  }

  static bool get isInitialized {
    try {
      final _ = Supabase.instance;
      return true;
    } catch (_) {
      return false;
    }
  }

  SupabaseClient? get clientOrNull {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  SupabaseClient get client => Supabase.instance.client;
}
