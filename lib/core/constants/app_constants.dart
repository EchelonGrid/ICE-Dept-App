class AppConstants {
  static const String appName = 'ICE Department';
  static const String deptFullName = 'Department of Information and Communication Engineering';
  static const String appVersion = 'v1.0.0 (Build 2026)';
  
  // Environment Keys
  static const String envSupabaseUrl = 'SUPABASE_URL';
  static const String envSupabaseAnonKey = 'SUPABASE_ANON_KEY';
  static const String defaultSupabaseUrl = 'https://srritixxmnbticfolbnf.supabase.co';
  static const String defaultSupabaseAnonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InNycml0aXh4bW5idGljZm9sYm5mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODgxODI3ODgsImV4cCI6MjEwMzc1ODc4OH0.QDHnonXRNFlvlCJv4TpQwaBlaRd4E64x5rWVi1EKbGA';
  
  // Secret salt for QR attendance anti-proxy tokens (matching DB RPC)
  static const String qrSecretSalt = 'ICE_SECURE_QR_2026';
  
  // QR code refresh interval in seconds
  static const int qrRefreshIntervalSeconds = 10;
  
  // Cutoff time for evening schedule shift (6:00 PM)
  static const int eveningScheduleCutoffHour = 18;
}
