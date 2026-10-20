import 'dart:convert';
import 'dart:typed_data';

class LocalNoteModel {
  final String id;
  final String subjectCode;
  final String subjectName;
  final String title;
  final String fileName;
  final int fileSizeBytes;
  final String? filePath; // For native mobile/desktop
  final String? base64Content; // For web / offline persistence
  final DateTime addedAt;
  final String? customRemarks;

  const LocalNoteModel({
    required this.id,
    required this.subjectCode,
    required this.subjectName,
    required this.title,
    required this.fileName,
    required this.fileSizeBytes,
    this.filePath,
    this.base64Content,
    required this.addedAt,
    this.customRemarks,
  });

  Uint8List? get bytes {
    if (base64Content != null && base64Content!.isNotEmpty) {
      return base64Decode(base64Content!);
    }
    return null;
  }

  String get formattedFileSize {
    if (fileSizeBytes < 1024) {
      return '$fileSizeBytes B';
    } else if (fileSizeBytes < 1024 * 1024) {
      return '${(fileSizeBytes / 1024).toStringAsFixed(1)} KB';
    } else {
      return '${(fileSizeBytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
  }

  factory LocalNoteModel.fromJson(Map<String, dynamic> json) {
    return LocalNoteModel(
      id: json['id'] as String,
      subjectCode: json['subject_code'] as String,
      subjectName: json['subject_name'] as String? ?? '',
      title: json['title'] as String,
      fileName: json['file_name'] as String,
      fileSizeBytes: json['file_size_bytes'] as int? ?? 0,
      filePath: json['file_path'] as String?,
      base64Content: json['base64_content'] as String?,
      addedAt: json['added_at'] != null
          ? DateTime.parse(json['added_at'] as String)
          : DateTime.now(),
      customRemarks: json['custom_remarks'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'subject_code': subjectCode,
      'subject_name': subjectName,
      'title': title,
      'file_name': fileName,
      'file_size_bytes': fileSizeBytes,
      if (filePath != null) 'file_path': filePath,
      if (base64Content != null) 'base64_content': base64Content,
      'added_at': addedAt.toIso8601String(),
      if (customRemarks != null) 'custom_remarks': customRemarks,
    };
  }
}
