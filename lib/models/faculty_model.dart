import 'user_model.dart';

class FacultyModel {
  final String? id;
  final String initials;
  final String fullName;
  final String? designation;
  final String department;
  final String? email;
  final String? userId;

  const FacultyModel({
    this.id,
    required this.initials,
    required this.fullName,
    this.designation,
    this.department = 'ICE',
    this.email,
    this.userId,
  });

  /// Normalized uppercase initials (matching routine short codes)
  String get displayInitials => initials.trim().toUpperCase();

  /// Returns real email if present, or mock official email: initial.toLowerCase()@ice.dept
  String get displayEmail {
    if (email != null && email!.trim().isNotEmpty) {
      return email!.trim().toLowerCase();
    }
    return '${displayInitials.toLowerCase()}@ice.dept';
  }

  /// Derives designation/rank from explicit field, title in name, department, or known faculty table
  String get displayDesignation {
    if (designation != null && designation!.trim().isNotEmpty) {
      return designation!.trim();
    }
    final deptLower = department.toLowerCase();
    if (deptLower.contains('assoc') && deptLower.contains('prof')) {
      return 'Associate Professor';
    }
    if ((deptLower.contains('asst') || deptLower.contains('assist')) && deptLower.contains('prof')) {
      return 'Assistant Professor';
    }
    if (deptLower.contains('professor')) {
      return 'Professor';
    }
    if (deptLower.contains('lecturer')) {
      return 'Lecturer';
    }

    final lower = fullName.toLowerCase();
    if (lower.contains('assoc') && lower.contains('prof')) {
      return 'Associate Professor';
    }
    if ((lower.contains('asst') || lower.contains('assist')) && lower.contains('prof')) {
      return 'Assistant Professor';
    }
    if (lower.contains('prof.') || lower.contains('professor')) {
      return 'Professor';
    }
    if (lower.contains('dr.') || lower.contains('doctor')) {
      return 'Associate Professor';
    }
    final cleanInit = displayInitials;
    if (['MAH', 'MSH', 'MOF', 'MKIC', 'KK'].contains(cleanInit)) {
      return 'Professor';
    }
    if (['MIH', 'MAR', 'DAF'].contains(cleanInit)) {
      return 'Associate Professor';
    }
    if (['TNT', 'TD', 'MIK', 'SS'].contains(cleanInit)) {
      return 'Assistant Professor';
    }
    if (['AM'].contains(cleanInit)) {
      return 'Lecturer';
    }
    return 'Faculty';
  }

  factory FacultyModel.fromJson(Map<String, dynamic> json) {
    final rawInit = (json['initials'] as String? ?? json['initial'] as String? ?? '').trim();
    final name = (json['full_name'] as String? ?? json['name'] as String? ?? 'Faculty Member').trim();
    return FacultyModel(
      id: json['id']?.toString(),
      initials: rawInit.isNotEmpty ? rawInit.toUpperCase() : _deriveInitials(name),
      fullName: name,
      designation: json['designation'] as String? ?? json['rank'] as String?,
      department: json['department'] as String? ?? 'ICE',
      email: json['email'] as String?,
      userId: json['user_id'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'initials': displayInitials,
      'initial': displayInitials,
      'full_name': fullName,
      if (designation != null) 'designation': designation,
      'department': department,
      'email': displayEmail,
      if (userId != null) 'user_id': userId,
    };
  }

  UserModel toUserModel() {
    return UserModel(
      id: userId ?? id ?? 'faculty_${displayInitials.toLowerCase()}',
      email: displayEmail,
      name: fullName,
      role: UserRole.teacher,
      initials: displayInitials,
    );
  }

  static String _deriveInitials(String name) {
    final cleaned = name.replaceAll(RegExp(r'^(?:(?:Prof|Dr|Mr|Mrs|Ms|Engr)\.?\s*)+', caseSensitive: false), '').trim();
    final parts = cleaned.split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return 'FAC';
    if (parts.length == 1) return parts[0].substring(0, parts[0].length.clamp(1, 3)).toUpperCase();
    if (parts.length == 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    return '${parts[0][0]}${parts[1][0]}${parts.last[0]}'.toUpperCase();
  }

  FacultyModel copyWith({
    String? id,
    String? initials,
    String? fullName,
    String? designation,
    String? department,
    String? email,
    String? userId,
  }) {
    return FacultyModel(
      id: id ?? this.id,
      initials: initials ?? this.initials,
      fullName: fullName ?? this.fullName,
      designation: designation ?? this.designation,
      department: department ?? this.department,
      email: email ?? this.email,
      userId: userId ?? this.userId,
    );
  }

  /// Official ICE Faculty Directory Seed List (Ordered by initials ascending)
  static List<FacultyModel> get officialFacultyList => const [
    FacultyModel(
      initials: 'AM',
      fullName: 'Akif Mahdi',
      designation: 'Lecturer',
      department: 'ICE',
      email: 'akif@ice.dept',
    ),
    FacultyModel(
      initials: 'DAF',
      fullName: 'Dr. A. F. M. Zainul Abadin',
      designation: 'Associate Professor',
      department: 'ICE',
      email: 'daf@ice.dept',
    ),
    FacultyModel(
      initials: 'KK',
      fullName: 'Prof. Dr. Kamruzzaman Khan',
      designation: 'Professor',
      department: 'ICE',
      email: 'kamruzzaman@ice.dept',
    ),
    FacultyModel(
      initials: 'MAH',
      fullName: 'Prof. Dr. Md. Anwar Hossain',
      designation: 'Professor',
      department: 'ICE',
      email: 'anwar@ice.dept',
    ),
    FacultyModel(
      initials: 'MAR',
      fullName: 'Dr. Md. Azizur Rahman',
      designation: 'Associate Professor',
      department: 'ICE',
      email: 'azizur@ice.dept',
    ),
    FacultyModel(
      initials: 'MIH',
      fullName: 'Dr. Md. Imran Hossain',
      designation: 'Associate Professor',
      department: 'ICE',
      email: 'imran@ice.dept',
    ),
    FacultyModel(
      initials: 'MIK',
      fullName: 'Md. Ibrahim Khalil',
      designation: 'Assistant Professor',
      department: 'ICE',
      email: 'ibrahim@ice.dept',
    ),
    FacultyModel(
      initials: 'MKIC',
      fullName: 'Prof. Dr. Mir Khaled Iqbal Chowdhury',
      designation: 'Professor',
      department: 'ICE',
      email: 'khaled@ice.dept',
    ),
    FacultyModel(
      initials: 'MOF',
      fullName: 'Prof. Dr. Md. Omar Faruk',
      designation: 'Professor',
      department: 'ICE',
      email: 'omar@ice.dept',
    ),
    FacultyModel(
      initials: 'MSH',
      fullName: 'Prof. Dr. Md. Sarwar Hosain',
      designation: 'Professor',
      department: 'ICE',
      email: 'sarwar@ice.dept',
    ),
    FacultyModel(
      initials: 'SS',
      fullName: 'Soma Saha',
      designation: 'Assistant Professor',
      department: 'ICE',
      email: 'soma@ice.dept',
    ),
    FacultyModel(
      initials: 'TD',
      fullName: 'Tarun Debnath',
      designation: 'Assistant Professor',
      department: 'ICE',
      email: 'tarun@ice.dept',
    ),
    FacultyModel(
      initials: 'TNT',
      fullName: 'Taskin Noor Turna',
      designation: 'Assistant Professor',
      department: 'ICE',
      email: 'turna@ice.dept',
    ),
  ];
}
