import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../core/constants/curriculum.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/date_time_helper.dart';
import '../../models/local_note_model.dart';
import '../../models/resource_item_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../services/local_notes_service.dart';
import '../../services/quick_access_service.dart';
import '../../services/supabase_service.dart';
import '../../widgets/empty_state_view.dart';
import '../../widgets/skeleton_loader.dart';
import 'pdf_viewer_screen.dart';
import 'resource_screen.dart';

class SubjectResourceScreen extends StatefulWidget {
  final SubjectInfo subject;
  final SemesterInfo semester;

  const SubjectResourceScreen({
    super.key,
    required this.subject,
    required this.semester,
  });

  @override
  State<SubjectResourceScreen> createState() => _SubjectResourceScreenState();
}

class _SubjectResourceScreenState extends State<SubjectResourceScreen> {
  int _selectedTab = 0; // 0 = Department Vault, 1 = My Personal Notes
  String _selectedCategory = 'all'; // 'all', 'notes', 'question_bank', 'library'
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  final LocalNotesService _localNotesService = LocalNotesService();

  List<ResourceItem> _vaultResources = [];
  List<LocalNoteModel> _personalNotes = [];
  bool _isLoadingVault = true;
  bool _isLoadingLocal = true;

  @override
  void initState() {
    super.initState();
    _loadSubjectResources();
    _loadPersonalNotes();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSubjectResources() async {
    setState(() => _isLoadingVault = true);
    try {
      final client = SupabaseService.instance.client;
      final response = await client
          .from('academic_resources')
          .select()
          .ilike('subject_name', '%${widget.subject.name}%')
          .order('created_at', ascending: false);

      final List<ResourceItem> fetched = (response as List)
          .map((item) => ResourceItem.fromJson(item as Map<String, dynamic>))
          .toList();

      if (mounted) {
        setState(() {
          _vaultResources = fetched.isNotEmpty ? fetched : _getDefaultSubjectMockResources();
          _isLoadingVault = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _vaultResources = _getDefaultSubjectMockResources();
          _isLoadingVault = false;
        });
      }
    }
  }

  Future<void> _loadPersonalNotes() async {
    setState(() => _isLoadingLocal = true);
    final notes = await _localNotesService.getNotesForSubject(widget.subject.code);
    if (mounted) {
      setState(() {
        _personalNotes = notes;
        _isLoadingLocal = false;
      });
    }
  }

  List<ResourceItem> _getDefaultSubjectMockResources() {
    return [
      ResourceItem(
        id: 's1',
        title: '${widget.subject.name} - Complete Lecture Slide Pack',
        category: 'notes',
        courseName: widget.subject.code,
        subjectName: widget.subject.name,
        fileUrl: 'https://cdn.syncfusion.com/content/PDFViewer/flutter-succinctly.pdf',
        uploaderName: 'Course Faculty',
        createdAt: DateTime.now().subtract(const Duration(days: 3)),
      ),
      ResourceItem(
        id: 's2',
        title: '${widget.subject.name} - Midterm & Term Final Solved Question Papers',
        category: 'question_bank',
        courseName: widget.subject.code,
        subjectName: widget.subject.name,
        fileUrl: 'https://cdn.syncfusion.com/content/PDFViewer/flutter-succinctly.pdf',
        uploaderName: 'CR Academic Repo',
        createdAt: DateTime.now().subtract(const Duration(days: 7)),
      ),
      ResourceItem(
        id: 's3',
        title: '${widget.subject.name} - Standard Textbook & Reference Materials',
        category: 'library',
        courseName: widget.subject.code,
        subjectName: widget.subject.name,
        fileUrl: 'https://cdn.syncfusion.com/content/PDFViewer/flutter-succinctly.pdf',
        uploaderName: 'Department Library',
        createdAt: DateTime.now().subtract(const Duration(days: 14)),
      ),
    ];
  }

  List<ResourceItem> get _filteredVaultResources {
    return _vaultResources.where((r) {
      final matchesCategory = _selectedCategory == 'all' || r.category == _selectedCategory;
      final matchesQuery = _searchQuery.isEmpty ||
          r.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          r.courseName.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCategory && matchesQuery;
    }).toList();
  }

  List<LocalNoteModel> get _filteredPersonalNotes {
    return _personalNotes.where((n) {
      return _searchQuery.isEmpty ||
          n.title.toLowerCase().contains(_searchQuery.toLowerCase()) ||
          n.fileName.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();
  }

  void _openPdfViewer({
    required String title,
    String? subtitle,
    String? fileUrl,
    String? filePath,
    dynamic fileBytes,
  }) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PdfViewerScreen(
          title: title,
          subtitle: subtitle ?? widget.subject.code,
          fileUrl: fileUrl,
          filePath: filePath,
          fileBytes: fileBytes,
        ),
      ),
    );
  }

  Future<void> _pickAndAddPersonalNote() async {
    try {
      final added = await _localNotesService.pickAndAddNote(
        subjectCode: widget.subject.code,
        subjectName: widget.subject.name,
      );

      if (added != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Added "${added.fileName}" to personal notes!'),
            backgroundColor: AppTheme.success,
          ),
        );
        _loadPersonalNotes();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not attach file: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final isTeacherOrCr = user?.role == UserRole.teacher ||
        user?.role == UserRole.admin ||
        (authService.studentProfile?.isCr ?? false);

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.subject.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text('${widget.subject.code} • ${widget.semester.shortTitle}', style: const TextStyle(fontSize: 11, color: AppTheme.accent)),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loadSubjectResources();
              _loadPersonalNotes();
            },
            tooltip: 'Refresh Files',
          ),
          if (_selectedTab == 0 && isTeacherOrCr)
            Padding(
              padding: const EdgeInsets.only(right: 8.0),
              child: IconButton(
                icon: const Icon(Icons.upload_file, color: AppTheme.accent),
                onPressed: () => _showUploadDialog(context),
                tooltip: 'Upload to Vault',
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // ================= 1. SEGMENTED VAULT / PERSONAL NOTES TOGGLE =================
          Container(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            color: AppTheme.surface,
            child: Container(
              decoration: BoxDecoration(
                color: const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: _buildSegmentButton(
                      label: 'Department Vault',
                      icon: Icons.cloud_done_outlined,
                      index: 0,
                    ),
                  ),
                  Expanded(
                    child: _buildSegmentButton(
                      label: 'My Personal Notes',
                      icon: Icons.lock_outline,
                      index: 1,
                      badgeCount: _personalNotes.length,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ================= 2. TAB VIEW CONTENT =================
          Expanded(
            child: _selectedTab == 0
                ? _buildDepartmentVaultTab()
                : _buildPersonalNotesTab(),
          ),
        ],
      ),
    );
  }

  Widget _buildSegmentButton({
    required String label,
    required IconData icon,
    required int index,
    int? badgeCount,
  }) {
    final isSelected = _selectedTab == index;

    return InkWell(
      onTap: () => setState(() => _selectedTab = index),
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primary : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected ? AppTheme.softCardShadow : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: isSelected ? Colors.white : AppTheme.textSecondary),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 12,
              ),
            ),
            if (badgeCount != null && badgeCount > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.accent : const Color(0xFFCBD5E1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    color: isSelected ? const Color(0xFF0F172A) : AppTheme.textPrimary,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  // Tab 0: Cloud Department Vault Files
  Widget _buildDepartmentVaultTab() {
    return RefreshIndicator(
      onRefresh: _loadSubjectResources,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Pinned Official Course Syllabus
            _buildOfficialSyllabusCard(),
            const SizedBox(height: 16),

            // Search Bar within subject
            TextField(
              controller: _searchController,
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
              decoration: InputDecoration(
                hintText: 'Search files in ${widget.subject.code}...',
                prefixIcon: const Icon(Icons.search, color: AppTheme.textSecondary),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () {
                          _searchController.clear();
                          setState(() => _searchQuery = '');
                        },
                      )
                    : null,
                fillColor: AppTheme.surface,
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: AppTheme.border),
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Category Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterChip('All Vault Files', 'all'),
                  const SizedBox(width: 8),
                  _buildFilterChip('📝 Notes & Slides', 'notes'),
                  const SizedBox(width: 8),
                  _buildFilterChip('📑 Question Bank', 'question_bank'),
                  const SizedBox(width: 8),
                  _buildFilterChip('📚 Reference Books', 'library'),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Resource List Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _selectedCategory == 'all'
                      ? 'Cloud Course Repository'
                      : _selectedCategory == 'notes'
                          ? 'Lecture Notes & Handouts'
                          : _selectedCategory == 'question_bank'
                              ? 'Past Exam Papers & CTs'
                              : 'Reference Books & Manuals',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
                ),
                Text(
                  '${_filteredVaultResources.length} items',
                  style: const TextStyle(fontSize: 12, color: AppTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 10),

            // File List
            if (_isLoadingVault)
              SkeletonLoader.listSkeleton(count: 3)
            else if (_filteredVaultResources.isEmpty)
              EmptyStateView(
                icon: Icons.folder_open_outlined,
                title: 'No Documents in this Section',
                description: _searchQuery.isNotEmpty
                    ? 'No files matching "$_searchQuery".'
                    : 'Be the first to upload lecture notes or question sets for ${widget.subject.code}!',
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _filteredVaultResources.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final item = _filteredVaultResources[index];
                  return _buildVaultFileCard(item);
                },
              ),
          ],
        ),
      ),
    );
  }

  // Tab 1: Local Personal Notes (Private on-device storage)
  Widget _buildPersonalNotesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Privacy Banner
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_outlined, color: Color(0xFF10B981), size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Secure Local Device Storage',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Color(0xFF10B981)),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Personal notes & annotations stay strictly on your phone or browser. They are NEVER uploaded to cloud servers.',
                        style: TextStyle(fontSize: 11, color: AppTheme.textSecondary, height: 1.3),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Action Button: Add Note
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: _pickAndAddPersonalNote,
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: Text('Attach Local PDF for ${widget.subject.code}', style: const TextStyle(fontWeight: FontWeight.bold)),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // List Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'My Linked Notes (${_personalNotes.length})',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: AppTheme.textPrimary),
              ),
              if (_personalNotes.isNotEmpty)
                const Text('Tap to view in-app', style: TextStyle(fontSize: 11, color: AppTheme.textMuted)),
            ],
          ),
          const SizedBox(height: 12),

          if (_isLoadingLocal)
            SkeletonLoader.listSkeleton(count: 2)
          else if (_filteredPersonalNotes.isEmpty)
            Container(
              padding: const EdgeInsets.all(28),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Column(
                children: [
                  const Icon(Icons.note_add_outlined, size: 48, color: AppTheme.textMuted),
                  const SizedBox(height: 12),
                  Text(
                    'No Personal Notes for ${widget.subject.code}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppTheme.textPrimary),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'Tap the button above to link lecture handouts or handwritten PDF notes saved on your device.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppTheme.textSecondary),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _filteredPersonalNotes.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final note = _filteredPersonalNotes[index];
                return _buildPersonalNoteCard(note);
              },
            ),
        ],
      ),
    );
  }

  // Personal Note Card
  Widget _buildPersonalNoteCard(LocalNoteModel note) {
    final isPinned = QuickAccessService.instance.isPinned(note.id);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isPinned ? const Color(0xFF0284C7).withValues(alpha: 0.5) : AppTheme.border,
        ),
      ),
      child: InkWell(
        onTap: () {
          _openPdfViewer(
            title: note.title,
            subtitle: '${widget.subject.code} • Local Personal Note',
            filePath: note.filePath,
            fileBytes: note.bytes,
          );
        },
        onLongPress: () => _showQuickAccessModalForNote(note),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF10B981).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.picture_as_pdf, color: Color(0xFF10B981), size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'LOCAL NOTE',
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Color(0xFF10B981)),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          note.formattedFileSize,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                        ),
                        if (isPinned) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.push_pin, size: 9, color: Color(0xFF0284C7)),
                                SizedBox(width: 3),
                                Text(
                                  'PINNED',
                                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      note.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Added ${DateTimeHelper.formatRelativeTime(note.addedAt)} • ${note.fileName}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(
                      isPinned ? Icons.bookmark : Icons.bookmark_outline,
                      color: isPinned ? const Color(0xFF0284C7) : AppTheme.textMuted,
                      size: 20,
                    ),
                    tooltip: isPinned ? 'Remove from Quick Access' : 'Pin to Quick Access',
                    onPressed: () => _showQuickAccessModalForNote(note),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                    tooltip: 'Remove Note',
                    onPressed: () async {
                      await _localNotesService.deleteNote(widget.subject.code, note.id);
                      _loadPersonalNotes();
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Note removed from local list.')),
                        );
                      }
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Pinned Official Syllabus Card
  Widget _buildOfficialSyllabusCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF00B4D8).withValues(alpha: 0.4), width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Color(0x3300B4D8),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF00B4D8).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.subject.iconData, size: 20, color: const Color(0xFF00B4D8)),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'OFFICIAL COURSE SYLLABUS',
                        style: TextStyle(
                          color: Color(0xFF00B4D8),
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${widget.subject.code} Curriculum Spec',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                    ],
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: () {
                  _openPdfViewer(
                    title: '${widget.subject.name} - Official Syllabus',
                    subtitle: '${widget.subject.code} Curriculum Spec',
                    fileUrl: 'https://cdn.syncfusion.com/content/PDFViewer/flutter-succinctly.pdf',
                  );
                },
                icon: const Icon(Icons.menu_book, size: 14),
                label: const Text('Open PDF', style: TextStyle(fontSize: 11)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00B4D8),
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Official departmental syllabus outline, mark distributions, course learning objectives (CLOs), and approved textbooks for ${widget.subject.name}.',
            style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String key) {
    final isSelected = _selectedCategory == key;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedCategory = key);
        }
      },
      selectedColor: AppTheme.primary,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : AppTheme.textSecondary,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 12,
      ),
      backgroundColor: AppTheme.surface,
      side: const BorderSide(color: AppTheme.border),
    );
  }

  Widget _buildVaultFileCard(ResourceItem item) {
    final (Color badgeColor, String categoryLabel, IconData icon) = switch (item.category) {
      'notes' => (const Color(0xFF0284C7), 'Notes', Icons.description_outlined),
      'question_bank' => (const Color(0xFFF59E0B), 'Question Bank', Icons.quiz_outlined),
      'library' => (const Color(0xFF10B981), 'Book', Icons.menu_book_outlined),
      _ => (AppTheme.primary, 'File', Icons.insert_drive_file_outlined),
    };

    final isPinned = QuickAccessService.instance.isPinned(item.id);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: isPinned ? const Color(0xFF0284C7).withValues(alpha: 0.5) : AppTheme.border,
        ),
      ),
      child: InkWell(
        onTap: () {
          _openPdfViewer(
            title: item.title,
            subtitle: '${item.courseName} • Vault Document',
            fileUrl: item.fileUrl,
          );
        },
        onLongPress: () => _showQuickAccessModal(item),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: badgeColor, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: badgeColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            categoryLabel,
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: badgeColor),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          widget.subject.code,
                          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.textMuted),
                        ),
                        if (isPinned) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.push_pin, size: 9, color: Color(0xFF0284C7)),
                                SizedBox(width: 3),
                                Text(
                                  'PINNED',
                                  style: TextStyle(fontSize: 8.5, fontWeight: FontWeight.bold, color: Color(0xFF0284C7)),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      item.title,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (item.uploaderName != null) ...[
                          const Icon(Icons.person_outline, size: 12, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(item.uploaderName!, style: const TextStyle(fontSize: 11, color: AppTheme.textSecondary)),
                          const SizedBox(width: 10),
                        ],
                        if (item.createdAt != null) ...[
                          const Icon(Icons.access_time, size: 12, color: AppTheme.textMuted),
                          const SizedBox(width: 4),
                          Text(DateTimeHelper.formatRelativeTime(item.createdAt!), style: const TextStyle(fontSize: 11, color: AppTheme.textMuted)),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  isPinned ? Icons.bookmark : Icons.bookmark_outline,
                  color: isPinned ? const Color(0xFF0284C7) : AppTheme.textMuted,
                  size: 20,
                ),
                tooltip: isPinned ? 'Remove from Quick Access' : 'Pin to Quick Access',
                onPressed: () => _showQuickAccessModal(item),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Bottom Sheet for Pin / Unpin Quick Access Management
  void _showQuickAccessModal(ResourceItem item) {
    HapticFeedback.lightImpact();
    final isPinned = QuickAccessService.instance.isPinned(item.id);

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

                // Option: Pin / Unpin
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: isPinned
                          ? const Color(0xFFEF4444).withValues(alpha: 0.15)
                          : const Color(0xFF0284C7).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isPinned ? Icons.bookmark_remove_outlined : Icons.push_pin_outlined,
                      color: isPinned ? const Color(0xFFEF4444) : const Color(0xFF38BDF8),
                      size: 20,
                    ),
                  ),
                  title: Text(
                    isPinned ? 'Remove from Quick Access' : 'Pin to Quick Access',
                    style: TextStyle(
                      color: isPinned ? const Color(0xFFEF4444) : Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    isPinned
                        ? 'Remove this file from your top Quick Access bar.'
                        : 'Pin this file to the Quick Access bar on the Resource Vault home screen.',
                    style: const TextStyle(color: Color(0xFF94A3B8), fontSize: 11.5),
                  ),
                  onTap: () async {
                    Navigator.pop(ctx);
                    final nowPinned = await QuickAccessService.instance.togglePin(item);
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          nowPinned
                              ? '📌 Pinned "${item.title}" to Quick Access!'
                              : 'Removed "${item.title}" from Quick Access.',
                        ),
                        backgroundColor: nowPinned ? const Color(0xFF0284C7) : const Color(0xFF475569),
                      ),
                    );
                    setState(() {});
                  },
                ),

                // Option: Open Document
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
                    _openPdfViewer(
                      title: item.title,
                      subtitle: '${item.courseName} • Vault Document',
                      fileUrl: item.isLocal ? null : item.fileUrl,
                      filePath: item.isLocal ? item.filePath : null,
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

  void _showQuickAccessModalForNote(LocalNoteModel note) {
    final item = ResourceItem(
      id: note.id,
      title: note.title,
      category: 'notes',
      courseName: note.subjectCode,
      subjectName: note.subjectName,
      fileUrl: note.filePath ?? '',
      filePath: note.filePath,
      uploaderName: 'Personal Note',
      isLocal: true,
    );
    _showQuickAccessModal(item);
  }

  void _showUploadDialog(BuildContext context) {
    final titleController = TextEditingController();
    final urlController = TextEditingController();
    String uploadCategory = 'notes';

    showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            return AlertDialog(
              title: Text('Upload for ${widget.subject.code}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(labelText: 'Document Title *', hintText: 'e.g. Chapter 3 Notes'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: urlController,
                      decoration: const InputDecoration(labelText: 'Document Download URL *', hintText: 'https://...'),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      initialValue: uploadCategory,
                      decoration: const InputDecoration(labelText: 'Category'),
                      items: const [
                        DropdownMenuItem(value: 'notes', child: Text('📝 Lecture Notes & Slides')),
                        DropdownMenuItem(value: 'question_bank', child: Text('📑 Question Bank & CTs')),
                        DropdownMenuItem(value: 'library', child: Text('📚 Reference Books')),
                      ],
                      onChanged: (val) {
                        if (val != null) setDialogState(() => uploadCategory = val);
                      },
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                ElevatedButton(
                  onPressed: () async {
                    if (titleController.text.trim().isEmpty) return;
                    Navigator.pop(ctx);

                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final authService = Provider.of<AuthService>(context, listen: false);
                      final client = SupabaseService.instance.client;
                      await client.from('academic_resources').insert({
                        'title': titleController.text.trim(),
                        'course_name': widget.subject.code,
                        'subject_name': widget.subject.name,
                        'category': uploadCategory,
                        'file_url': urlController.text.trim().isNotEmpty ? urlController.text.trim() : 'https://cdn.syncfusion.com/content/PDFViewer/flutter-succinctly.pdf',
                        'uploader_id': authService.currentUser?.id,
                        'batch_id': authService.studentProfile?.batchId,
                      });

                      if (mounted) {
                        messenger.showSnackBar(
                          const SnackBar(content: Text('Document added to Subject Repository!'), backgroundColor: AppTheme.success),
                        );
                        _loadSubjectResources();
                      }
                    } catch (e) {
                      if (mounted) {
                        messenger.showSnackBar(
                          SnackBar(content: Text('Upload error: $e'), backgroundColor: AppTheme.error),
                        );
                      }
                    }
                  },
                  child: const Text('Upload'),
                ),
              ],
            );
          },
        );
      },
    );
  }
}
