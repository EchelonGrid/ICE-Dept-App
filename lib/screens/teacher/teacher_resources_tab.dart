import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/curriculum.dart';
import '../../core/theme/app_theme.dart';
import '../../features/resources/resource_screen.dart';
import '../../features/resources/subject_resource_screen.dart';
import '../../services/auth_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/profile_avatar_button.dart';
import '../../widgets/skeleton_loader.dart';

class TeacherResourcesTab extends StatefulWidget {
  const TeacherResourcesTab({super.key});

  @override
  State<TeacherResourcesTab> createState() => _TeacherResourcesTabState();
}

class _TeacherResourcesTabState extends State<TeacherResourcesTab> {
  bool _showAllSemesters = false;
  Map<String, int> _subjectFileCounts = {};
  bool _isLoading = true;

  // The 4 official assigned courses for Dr. Anwar Hossain (MAH)
  static final List<SubjectInfo> _assignedCourses = [
    const SubjectInfo(
      code: 'ICE-1105',
      name: 'Structured Programming Language',
      iconEmoji: '💻',
      iconData: Icons.code_rounded,
    ),
    const SubjectInfo(
      code: 'ICE-2202',
      name: 'Signals and Systems',
      iconEmoji: '🌊',
      iconData: Icons.waves_rounded,
    ),
    const SubjectInfo(
      code: 'ICE-4116',
      name: 'Cellular & Mobile Communication',
      iconEmoji: '📡',
      iconData: Icons.cell_tower_rounded,
    ),
    const SubjectInfo(
      code: 'ICE-4117',
      name: 'Mobile Communication Lab',
      iconEmoji: '🔬',
      iconData: Icons.biotech_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadResourceCounts();
  }

  Future<void> _loadResourceCounts() async {
    setState(() => _isLoading = true);
    try {
      final client = SupabaseService.instance.client;
      final response = await client
          .from('academic_resources')
          .select('subject_name, course_name');

      final Map<String, int> counts = {};
      for (final item in (response as List)) {
        final sName = item['subject_name'] as String?;
        final cName = item['course_name'] as String?;
        if (sName != null) {
          counts[sName] = (counts[sName] ?? 0) + 1;
        }
        if (cName != null) {
          counts[cName] = (counts[cName] ?? 0) + 1;
        }
      }

      if (mounted) {
        setState(() {
          _subjectFileCounts = counts;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  SemesterInfo _getSemesterForCourse(String code) {
    if (code.startsWith('ICE-11')) return DepartmentCurriculum.getSemester('1-1');
    if (code.startsWith('ICE-22')) return DepartmentCurriculum.getSemester('2-2');
    if (code.startsWith('ICE-41')) return DepartmentCurriculum.getSemester('4-1');
    return DepartmentCurriculum.getSemester('3-1');
  }

  void _showUploadDialog(SubjectInfo subject) {
    final titleCtrl = TextEditingController();
    final urlCtrl = TextEditingController();
    String category = 'Lecture Slide';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.upload_file_rounded, color: AppTheme.primary, size: 24),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Upload to ${subject.code}',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.name,
                  style: const TextStyle(fontSize: 12, color: AppTheme.textSecondary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),

                // Category selector
                DropdownButtonFormField<String>(
                  initialValue: category,
                  decoration: InputDecoration(
                    labelText: 'Material Category',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Lecture Slide', child: Text('Lecture Slide / Presentation')),
                    DropdownMenuItem(value: 'Handout', child: Text('Lecture Handout / Notes')),
                    DropdownMenuItem(value: 'Lab Manual', child: Text('Lab Manual / Experiment Sheet')),
                    DropdownMenuItem(value: 'Reference Book', child: Text('Reference Book / Reading Material')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => category = val);
                  },
                ),
                const SizedBox(height: 12),

                // Document Title
                AppTextField(
                  controller: titleCtrl,
                  label: 'Document Title',
                  hint: 'e.g. Chapter 3: Sampling Theorem & Nyquist Rate',
                ),
                const SizedBox(height: 12),

                // Document URL
                AppTextField(
                  controller: urlCtrl,
                  label: 'Document / PDF Web Link',
                  hint: 'https://... or Google Drive public link',
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                final messenger = ScaffoldMessenger.of(context);

                try {
                  final authService = Provider.of<AuthService>(context, listen: false);
                  final client = SupabaseService.instance.client;
                  final fileUrl = urlCtrl.text.trim().isNotEmpty
                      ? urlCtrl.text.trim()
                      : 'https://cdn.syncfusion.com/content/PDFViewer/flutter-succinctly.pdf';

                  await client.from('academic_resources').insert({
                    'title': titleCtrl.text.trim(),
                    'course_name': subject.code,
                    'subject_name': subject.name,
                    'category': category,
                    'file_url': fileUrl,
                    'uploader_id': authService.currentUser?.id ?? '9d3b6545-1d6c-4d7d-8aed-ce5ef1589015',
                  });

                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(
                        content: Text('Uploaded "${titleCtrl.text.trim()}" to ${subject.code}!'),
                        backgroundColor: AppTheme.success,
                      ),
                    );
                    _loadResourceCounts();
                  }
                } catch (e) {
                  if (mounted) {
                    messenger.showSnackBar(
                      SnackBar(content: Text('Upload error: $e'), backgroundColor: AppTheme.error),
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
              ),
              child: const Text('Upload Document'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_showAllSemesters) {
      return Scaffold(
        backgroundColor: AppTheme.background,
        appBar: AppBar(
          title: const Text('All Department Semesters', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
          actions: [
            TextButton.icon(
              onPressed: () => setState(() => _showAllSemesters = false),
              icon: const Icon(Icons.arrow_back, size: 16, color: AppTheme.primary),
              label: const Text('My Courses', style: TextStyle(color: AppTheme.primary, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        body: const ResourceScreen(),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Materials Vault', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
            Text('Assigned Teaching Subjects', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AppTheme.textSecondary),
            tooltip: 'Refresh Vault',
            onPressed: _loadResourceCounts,
          ),
          const ProfileAvatarButton(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadResourceCounts,
        child: _isLoading
            ? SkeletonLoader.listSkeleton(count: 3)
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Banner: 4 Assigned Subjects
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'TEACHER REPOSITORY',
                                  style: TextStyle(
                                    color: Color(0xFF38BDF8),
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w900,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  '4 Assigned Subjects Filtered',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.2,
                                  ),
                                ),
                                SizedBox(height: 2),
                                Text(
                                  'Upload lecture slides, handouts, and laboratory guides directly.',
                                  style: TextStyle(color: Color(0xFF94A3B8), fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                          OutlinedButton(
                            onPressed: () => setState(() => _showAllSemesters = true),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.white,
                              side: const BorderSide(color: Color(0xFF475569)),
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            ),
                            child: const Text('All Semesters', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),

                    const Text(
                      'Your Assigned Courses',
                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 12),

                    // Course Cards Grid / List
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _assignedCourses.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final subject = _assignedCourses[index];
                        final semester = _getSemesterForCourse(subject.code);
                        final fileCount = _subjectFileCounts[subject.code] ??
                            _subjectFileCounts[subject.name] ??
                            4;

                        return _buildCourseCard(subject, semester, fileCount);
                      },
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCourseCard(SubjectInfo subject, SemesterInfo semester, int fileCount) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Code Badge + Semester Tag + Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.primary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(subject.iconData, color: AppTheme.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          subject.code,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900, color: Color(0xFF0F172A)),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        semester.shortTitle,
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B), fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined, color: Color(0xFF10B981), size: 13),
                    const SizedBox(width: 4),
                    Text(
                      '$fileCount files',
                      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF047857)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Course Full Title
          Text(
            subject.name,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
              letterSpacing: -0.2,
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons: + Upload Handout / Slide & Open Folder
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: () => _showUploadDialog(subject),
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                  label: const Text(
                    '+ Upload Handout / Slide',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    elevation: 0,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => SubjectResourceScreen(
                          subject: subject,
                          semester: semester,
                        ),
                      ),
                    ).then((_) => _loadResourceCounts());
                  },
                  icon: const Icon(Icons.folder_open_rounded, size: 16),
                  label: const Text('Folder', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF0F172A),
                    side: const BorderSide(color: Color(0xFFCBD5E1)),
                    minimumSize: const Size(0, 40),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
