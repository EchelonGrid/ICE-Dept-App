import 'dart:convert';
import 'dart:io' show File;
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:crypto/crypto.dart';
import '../models/local_note_model.dart';

class LocalNotesService {
  static const String _prefKeyPrefix = 'personal_notes_';

  String _getKey(String subjectCode) => '$_prefKeyPrefix$subjectCode';

  /// Get all local personal notes for a specific subject
  Future<List<LocalNoteModel>> getNotesForSubject(String subjectCode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getKey(subjectCode);
      final rawList = prefs.getStringList(key) ?? [];

      return rawList
          .map((itemStr) => LocalNoteModel.fromJson(jsonDecode(itemStr) as Map<String, dynamic>))
          .toList()
        ..sort((a, b) => b.addedAt.compareTo(a.addedAt));
    } catch (e) {
      debugPrint('[LocalNotesService] Error loading notes for $subjectCode: $e');
      return [];
    }
  }

  /// Save a new personal note strictly to local storage
  Future<void> saveNote(LocalNoteModel note) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKey(note.subjectCode);
    final rawList = prefs.getStringList(key) ?? [];

    // Check if duplicate ID exists and replace, or append
    final updatedList = rawList.where((itemStr) {
      final data = jsonDecode(itemStr) as Map<String, dynamic>;
      return data['id'] != note.id;
    }).toList();

    updatedList.add(jsonEncode(note.toJson()));
    await prefs.setStringList(key, updatedList);
  }

  /// Delete a personal note by ID from local storage
  Future<void> deleteNote(String subjectCode, String noteId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _getKey(subjectCode);
    final rawList = prefs.getStringList(key) ?? [];

    final updatedList = rawList.where((itemStr) {
      final data = jsonDecode(itemStr) as Map<String, dynamic>;
      return data['id'] != noteId;
    }).toList();

    await prefs.setStringList(key, updatedList);
  }

  /// Trigger system file picker to select a local PDF note
  /// Safely handles Flutter Web by relying on [file.bytes] instead of [file.path].
  Future<LocalNoteModel?> pickAndAddNote({
    required String subjectCode,
    required String subjectName,
    String? customTitle,
  }) async {
    try {
      debugPrint('[LocalNotesService] Opening file picker for PDF note (kIsWeb: $kIsWeb)...');
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
        withData: true, // Ensures file.bytes is populated on both Web and mobile
      );

      if (result == null || result.files.isEmpty) {
        debugPrint('[LocalNotesService] File picker dismissed without selection.');
        return null;
      }

      final file = result.files.first;
      Uint8List? bytes;
      String? filePath;

      if (kIsWeb) {
        // On Flutter Web, file.path is null. We must safely read file.bytes.
        bytes = file.bytes;
        if (bytes == null || bytes.isEmpty) {
          debugPrint('[LocalNotesService] Warning: file.bytes is null or empty on Web.');
          throw Exception('Unable to read selected PDF file bytes from the browser.');
        }
        filePath = null;
      } else {
        // On native mobile/desktop platforms, safely obtain file.path
        filePath = file.path;
        bytes = file.bytes;

        // Fallback: If bytes is null on native platform, read from filePath
        if (bytes == null && filePath != null && filePath.isNotEmpty) {
          try {
            final ioFile = File(filePath);
            if (await ioFile.exists()) {
              bytes = await ioFile.readAsBytes();
            }
          } catch (ioErr) {
            debugPrint('[LocalNotesService] Note: Failed to read bytes directly from native path: $ioErr');
          }
        }
      }

      final String? base64Str = bytes != null ? base64Encode(bytes) : null;
      final String noteId = md5.convert(utf8.encode('${file.name}_${DateTime.now().millisecondsSinceEpoch}')).toString();

      final newNote = LocalNoteModel(
        id: noteId,
        subjectCode: subjectCode,
        subjectName: subjectName,
        title: customTitle?.trim().isNotEmpty == true ? customTitle!.trim() : file.name.replaceAll('.pdf', ''),
        fileName: file.name,
        fileSizeBytes: bytes?.length ?? file.size,
        filePath: filePath,
        base64Content: base64Str,
        addedAt: DateTime.now(),
      );

      await saveNote(newNote);
      debugPrint('[LocalNotesService] Successfully saved note "${newNote.fileName}" (bytes: ${bytes?.length ?? 0}, path: $filePath)');
      return newNote;
    } catch (e, stack) {
      debugPrint('[LocalNotesService] Error during pickAndAddNote: $e\n$stack');
      rethrow;
    }
  }
}
