class ResourceItem {
  final String id;
  final String title;
  final String category; // 'notes', 'question_bank', 'library'
  final String courseName;
  final String? subjectName;
  final String fileUrl;
  final String? filePath;
  final String? uploaderName;
  final DateTime? createdAt;
  final bool isLocal;

  const ResourceItem({
    required this.id,
    required this.title,
    required this.category,
    required this.courseName,
    this.subjectName,
    required this.fileUrl,
    this.filePath,
    this.uploaderName,
    this.createdAt,
    this.isLocal = false,
  });

  factory ResourceItem.fromJson(Map<String, dynamic> json) {
    return ResourceItem(
      id: json['id'] as String? ?? '',
      title: json['title'] as String? ?? 'Untitled Resource',
      category: json['category'] as String? ?? 'notes',
      courseName: json['course_name'] as String? ?? 'General ICE',
      subjectName: json['subject_name'] as String?,
      fileUrl: json['file_url'] as String? ?? '',
      filePath: json['file_path'] as String?,
      uploaderName: json['uploader_name'] as String?,
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at'] as String) : null,
      isLocal: json['is_local'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'category': category,
      'course_name': courseName,
      if (subjectName != null) 'subject_name': subjectName,
      'file_url': fileUrl,
      if (filePath != null) 'file_path': filePath,
      if (uploaderName != null) 'uploader_name': uploaderName,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      'is_local': isLocal,
    };
  }
}
