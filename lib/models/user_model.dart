enum UserRole {
  admin,
  teacher,
  student;

  static UserRole fromString(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return UserRole.admin;
      case 'teacher':
        return UserRole.teacher;
      case 'student':
      default:
        return UserRole.student;
    }
  }

  String toDbString() {
    switch (this) {
      case UserRole.admin:
        return 'admin';
      case UserRole.teacher:
        return 'teacher';
      case UserRole.student:
        return 'student';
    }
  }

  String get displayName {
    switch (this) {
      case UserRole.admin:
        return 'Clerk / Admin';
      case UserRole.teacher:
        return 'Faculty Member';
      case UserRole.student:
        return 'Student';
    }
  }
}

class UserModel {
  final String id;
  final String email;
  final String name;
  final UserRole role;
  final bool passwordChanged;
  final DateTime? createdAt;
  final String? initials;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    this.passwordChanged = false,
    this.createdAt,
    this.initials,
  });

  String get displayInitials {
    if (initials != null && initials!.trim().isNotEmpty) {
      return initials!.trim().toUpperCase();
    }
    final cleaned = name.replaceAll(RegExp(r'^(?:(?:Prof|Dr|Mr|Mrs|Ms|Engr)\.?\s*)+', caseSensitive: false), '').trim();
    final parts = cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'FAC';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length.clamp(1, 3)).toUpperCase();
    if (parts.length == 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return '${parts[0][0]}${parts[1][0]}${parts.last[0]}'.toUpperCase();
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      name: json['name'] as String? ?? 'User',
      role: UserRole.fromString(json['role'] as String? ?? 'student'),
      passwordChanged: json['password_changed'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      initials: (json['initials'] as String? ?? json['initial'] as String?)?.trim(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'role': role.toDbString(),
      'password_changed': passwordChanged,
      if (createdAt != null) 'created_at': createdAt!.toIso8601String(),
      if (initials != null && initials!.trim().isNotEmpty) 'initials': initials!.trim().toUpperCase(),
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    UserRole? role,
    bool? passwordChanged,
    DateTime? createdAt,
    String? initials,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      role: role ?? this.role,
      passwordChanged: passwordChanged ?? this.passwordChanged,
      createdAt: createdAt ?? this.createdAt,
      initials: initials ?? this.initials,
    );
  }
}
