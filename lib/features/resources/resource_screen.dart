import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/curriculum.dart';
import '../../models/resource_item_model.dart';
import '../../services/auth_service.dart';
import '../../services/quick_access_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/profile_avatar_button.dart';
import 'subject_resource_screen.dart';
import 'pdf_viewer_screen.dart';

export '../../models/resource_item_model.dart';

class ResourceScreen extends StatefulWidget {
  const ResourceScreen({super.key});

  @override
  State<ResourceScreen> createState() => _ResourceScreenState();
}

class _ResourceScreenState extends State<ResourceScreen> {
  String _activeSemesterKey = '3-1';
  bool _isInitializedSemester = false;
  Map<String, int> _subjectFileCounts = {};

  @override
  void initState() {
    super.initState();
    QuickAccessService.instance.loadPinnedItems();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitializedSemester) {
      final authService = Provider.of<AuthService>(context, listen: false);
      final studentSemester = authService.studentProfile?.currentSemester;
      if (studentSemester != null && DepartmentCurriculum.semesters.containsKey(studentSemester)) {
        _activeSemesterKey = studentSemester;
      }
      _isInitializedSemester = true;
      _loadSubjectFileCounts();
    }
  }

  Future<void> _loadSubjectFileCounts() async {
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
        });
      }
    } catch (_) {}
  }

  void _switchSemester(String semesterKey) {
    setState(() {
      _activeSemesterKey = semesterKey;
    });
  }

  void _showQuickAccessOptions(ResourceItem item) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: const Color(0xFF334155),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.picture_as_pdf, color: Color(0xFF38BDF8), size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.courseName,
                            style: const TextStyle(color: Color(0xFF38BDF8), fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Divider(color: Color(0xFF1E293B), height: 1),
                const SizedBox(height: 8),

                // Unpin Option
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEF4444).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.bookmark_remove_outlined, color: Color(0xFFEF4444), size: 20),
                  ),
                  title: const Text(
                    'Remove from Quick Access',
                    style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Unpin this file from your top Quick Access bar.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await QuickAccessService.instance.unpin(item.id);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Removed "${item.title}" from Quick Access.')),
                    );
                  },
                ),

                // Open Document
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.open_in_new, color: Colors.white, size: 20),
                  ),
                  title: const Text(
                    'Open Document',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: const Text(
                    'Read document in the built-in PDF viewer.',
                    style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PdfViewerScreen(
                          title: item.title,
                          subtitle: '${item.courseName} • Quick Access',
                          fileUrl: item.isLocal ? null : item.fileUrl,
                          filePath: item.isLocal ? item.filePath : null,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentSemesterInfo = DepartmentCurriculum.getSemester(_activeSemesterKey);
    final authService = Provider.of<AuthService>(context);
    final studentSemesterKey = authService.studentProfile?.currentSemester ?? '3-1';
    final isCurrentEnrolledSemester = _activeSemesterKey == studentSemesterKey;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Resource Vault',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17, color: Color(0xFF0F172A), letterSpacing: -0.3),
            ),
            Text(
              currentSemesterInfo.title,
              style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz_rounded, color: Color(0xFF0284C7)),
            tooltip: 'Switch Semester',
            onPressed: () => _showSemesterPickerModal(context),
          ),
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF64748B)),
            tooltip: 'Refresh Vault',
            onPressed: _loadSubjectFileCounts,
          ),
          const ProfileAvatarButton(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await _loadSubjectFileCounts();
          await QuickAccessService.instance.loadPinnedItems();
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ================= 1. SLIM ACTIVE SEMESTER HERO BANNER =================
              _buildSemesterHeroBanner(currentSemesterInfo, isCurrentEnrolledSemester),
              const SizedBox(height: 16),

              // ================= 2. QUICK ACCESS / BOOKMARKS CAROUSEL =================
              ListenableBuilder(
                listenable: QuickAccessService.instance,
                builder: (context, _) {
                  final pinnedCount = QuickAccessService.instance.count;
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.bookmark_outline, color: Color(0xFF475569), size: 16),
                              SizedBox(width: 6),
                              Text(
                                'Quick Access',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5, color: Color(0xFF0F172A), letterSpacing: -0.2),
                              ),
                            ],
                          ),
                          Text(
                            '$pinnedCount Pinned',
                            style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B), fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildQuickAccessCarousel(),
                    ],
                  );
                },
              ),
              const SizedBox(height: 20),

              // ================= 3. SUBJECT CURRICULUM FOLDERS =================
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.grid_view_outlined, color: Color(0xFF475569), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${currentSemesterInfo.shortTitle} Subjects',
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, color: Color(0xFF0F172A), letterSpacing: -0.2),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Text(
                      '${currentSemesterInfo.subjects.length} Courses',
                      style: const TextStyle(fontSize: 10.5, color: Color(0xFF475569), fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              _buildSubjectFoldersGrid(currentSemesterInfo),
              const SizedBox(height: 20),

              // ================= 4. BROWSE ALL / PREVIOUS SEMESTERS CTA =================
              _buildBrowseSemestersCTA(),
            ],
          ),
        ),
      ),
    );
  }

  // Slim Hero Card highlighting current semester details
  Widget _buildSemesterHeroBanner(SemesterInfo semester, bool isEnrolled) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFF1E293B)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isEnrolled
                            ? const Color(0xFF10B981).withValues(alpha: 0.2)
                            : const Color(0xFF0284C7).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        isEnrolled ? 'ACTIVE SEMESTER' : 'ARCHIVE',
                        style: TextStyle(
                          color: isEnrolled ? const Color(0xFF34D399) : const Color(0xFF38BDF8),
                          fontSize: 9.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  semester.title,
                  style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800, letterSpacing: -0.2),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => _showSemesterPickerModal(context),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: const Color(0xFF334155)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Change', style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11, fontWeight: FontWeight.w600)),
                  SizedBox(width: 4),
                  Icon(Icons.unfold_more, color: Color(0xFF94A3B8), size: 14),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Dynamic Quick Access Horizontal Carousel with direct unpin and long press
  Widget _buildQuickAccessCarousel() {
    final pinnedResources = QuickAccessService.instance.pinnedItems;

    if (pinnedResources.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0)),
        ),
        child: const Row(
          children: [
            Icon(Icons.push_pin_outlined, color: Color(0xFF94A3B8), size: 22),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'No Pinned Resources',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12.5, color: Color(0xFF0F172A)),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Long-press any file in subject folders to pin it here for instant access.',
                    style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return SizedBox(
      height: 94,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: pinnedResources.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = pinnedResources[index];
          return InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => PdfViewerScreen(
                    title: item.title,
                    subtitle: '${item.courseName} • Quick Access',
                    fileUrl: item.isLocal ? null : item.fileUrl,
                    filePath: item.isLocal ? item.filePath : null,
                  ),
                ),
              );
            },
            onLongPress: () => _showQuickAccessOptions(item),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              width: 220,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          item.courseName,
                          style: const TextStyle(color: Color(0xFF0F172A), fontSize: 9.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                      // Bookmark Icon Tap to quickly Unpin
                      InkWell(
                        onTap: () async {
                          HapticFeedback.lightImpact();
                          await QuickAccessService.instance.unpin(item.id);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Unpinned "${item.title}" from Quick Access'),
                                duration: const Duration(seconds: 2),
                              ),
                            );
                          }
                        },
                        borderRadius: BorderRadius.circular(4),
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(Icons.bookmark, color: Color(0xFF0284C7), size: 16),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 11.5,
                      color: Color(0xFF0F172A),
                      height: 1.25,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // GridView of Subject Folders with Flat Sharp Cards & Minimalist Monochrome Icons
  Widget _buildSubjectFoldersGrid(SemesterInfo semester) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 1.05,
      ),
      itemCount: semester.subjects.length,
      itemBuilder: (context, index) {
        final subject = semester.subjects[index];
        final fileCount = _subjectFileCounts[subject.name] ??
            _subjectFileCounts[subject.code] ??
            3;

        return _buildFolderCard(subject, semester, fileCount);
      },
    );
  }

  // Flat, Sharp Subject Card
  Widget _buildFolderCard(SubjectInfo subject, SemesterInfo semester, int fileCount) {
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => SubjectResourceScreen(
              subject: subject,
              semester: semester,
            ),
          ),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            // Top Row: Minimalist Monochrome Icon + Code Badge
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: Icon(
                    subject.iconData,
                    size: 18,
                    color: const Color(0xFF334155),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    subject.code,
                    style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.bold, color: Color(0xFF64748B)),
                  ),
                ),
              ],
            ),

            // Bottom Column: Bold Sharp Subject Name + Subtle File Count Subtitle
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  subject.name,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: Color(0xFF0F172A),
                    height: 1.25,
                    letterSpacing: -0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.insert_drive_file_outlined, size: 11, color: Color(0xFF94A3B8)),
                    const SizedBox(width: 4),
                    Text(
                      '$fileCount documents',
                      style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Flat Minimalist Bottom Callout
  Widget _buildBrowseSemestersCTA() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Icon(Icons.history_edu_outlined, color: Color(0xFF334155), size: 18),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Browse Previous Semesters',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13, color: Color(0xFF0F172A), letterSpacing: -0.2),
                ),
                SizedBox(height: 2),
                Text(
                  'Access 1st to 4th year past notes & archives',
                  style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () => _showSemesterPickerModal(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF0F172A),
              side: const BorderSide(color: Color(0xFFCBD5E1)),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
            ),
            child: const Text('All Semesters', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Modal to select any of the 8 ICE Semesters
  void _showSemesterPickerModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Select ICE Curriculum Semester',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, color: Color(0xFF0F172A), letterSpacing: -0.2),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView.separated(
                    itemCount: DepartmentCurriculum.allSemesters.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Color(0xFFF1F5F9)),
                    itemBuilder: (context, index) {
                      final sem = DepartmentCurriculum.allSemesters[index];
                      final isSelected = sem.key == _activeSemesterKey;

                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        leading: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFFF1F5F9),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            sem.key,
                            style: TextStyle(
                              color: isSelected ? Colors.white : const Color(0xFF334155),
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        ),
                        title: Text(
                          sem.title,
                          style: TextStyle(
                            fontWeight: isSelected ? FontWeight.w800 : FontWeight.w600,
                            color: isSelected ? const Color(0xFF0F172A) : const Color(0xFF334155),
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          '${sem.subjects.length} Courses: ${sem.subjects.map((s) => s.code).join(", ")}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check, color: Color(0xFF0284C7), size: 18)
                            : null,
                        onTap: () {
                          _switchSemester(sem.key);
                          Navigator.pop(ctx);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
