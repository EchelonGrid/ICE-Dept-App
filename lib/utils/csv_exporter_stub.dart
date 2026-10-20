import 'dart:io';
import 'package:path_provider/path_provider.dart';

/// Stub implementation for non-web platforms (mobile, desktop, and test VM).
Future<String?> exportCsvFile({
  required String csvContent,
  required String fileName,
}) async {
  if (Platform.environment.containsKey('FLUTTER_TEST')) {
    try {
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/$fileName');
      file.writeAsStringSync(csvContent);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  try {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(csvContent);
    return file.path;
  } catch (_) {
    try {
      final tempDir = Directory.systemTemp;
      final file = File('${tempDir.path}/$fileName');
      await file.writeAsString(csvContent);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}
