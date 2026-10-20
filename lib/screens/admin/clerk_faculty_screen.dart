import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../models/faculty_model.dart';
import '../../models/user_model.dart';
import '../../services/db_service.dart';
import '../../widgets/app_text_field.dart';

import '../../services/supabase_service.dart';

class ClerkFacultyScreen extends StatefulWidget {
  final bool isEmbedded;
  final List<dynamic>? initialFaculty;

  const ClerkFacultyScreen({
    super.key,
    this.isEmbedded = false,
    this.initialFaculty,
  });

  @override
  State<ClerkFacultyScreen> createState() => _ClerkFacultyScreenState();
}

class _ClerkFacultyScreenState extends State<ClerkFacultyScreen> {
  final DbService _dbService = DbService();
  final TextEditingController _searchController = TextEditingController();

  List<FacultyModel> _allFaculty = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedRank = 'All';

  List<FacultyModel> _parseInitialFaculty(List<dynamic> list) {
    return list.map((item) {
      if (item is FacultyModel) return item;
      if (item is UserModel) {
        return FacultyModel(
          id: item.id.startsWith('faculty_') ? null : item.id,
          initials: item.displayInitials,
          fullName: item.name,
          email: item.email,
          userId: item.id.startsWith('faculty_') ? null : item.id,
        );
      }
      return FacultyModel.fromJson(item as Map<String, dynamic>);
    }).toList();
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialFaculty != null && widget.initialFaculty!.isNotEmpty) {
      _allFaculty = _parseInitialFaculty(widget.initialFaculty!);
      _isLoading = false;
    }
    _loadFacultyList();
  }

  @override
  void didUpdateWidget(covariant ClerkFacultyScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialFaculty != null &&
        widget.initialFaculty != oldWidget.initialFaculty &&
        widget.initialFaculty!.isNotEmpty) {
      setState(() {
        _allFaculty = _parseInitialFaculty(widget.initialFaculty!);
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Queries public.faculty_directory ordered by initials ascending
  Future<void> _loadFacultyList() async {
    if (_allFaculty.isEmpty) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      // Check if Supabase client is accessible
      if (!SupabaseService.isInitialized) {
        if (_allFaculty.isEmpty) {
          final fallback = await _dbService.getFacultyDirectory();
          if (mounted) {
            setState(() {
              _allFaculty = fallback;
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
        return;
      }

      // Step 1: Query public.faculty_directory ordered by initials ascending
      final facultyList = await Supabase.instance.client
          .from('faculty_directory')
          .select()
          .order('initials', ascending: true);

      final List<FacultyModel> loaded = [];
      for (final row in (facultyList as List)) {
        loaded.add(FacultyModel.fromJson(row as Map<String, dynamic>));
      }

      // If database returned empty or offline, fallback to official list
      if (loaded.isEmpty) {
        if (_allFaculty.isEmpty) {
          final fallback = await _dbService.getFacultyDirectory();
          if (mounted) {
            setState(() {
              _allFaculty = fallback;
              _isLoading = false;
            });
          }
        } else {
          if (mounted) {
            setState(() => _isLoading = false);
          }
        }
        return;
      }

      // Check if all official faculty are present; if any are missing, merge with official list
      final existingInitials = loaded.map((f) => f.displayInitials).toSet();
      final List<FacultyModel> missing = [];
      for (final official in FacultyModel.officialFacultyList) {
        if (!existingInitials.contains(official.displayInitials)) {
          missing.add(official);
        }
      }

      if (missing.isNotEmpty) {
        try {
          await Supabase.instance.client.from('faculty_directory').upsert(
            missing.map((m) => m.toJson()).toList(),
            onConflict: 'initials',
          );
        } catch (_) {}
        loaded.addAll(missing);
      }

      loaded.sort((a, b) => a.displayInitials.compareTo(b.displayInitials));

      if (mounted) {
        setState(() {
          _allFaculty = loaded;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading faculty_directory: $e');
      if (_allFaculty.isEmpty) {
        final fallback = await _dbService.getFacultyDirectory();
        if (mounted) {
          setState(() {
            _allFaculty = fallback;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    }
  }

  List<FacultyModel> get _filteredFaculty {
    final query = _searchController.text.trim().toLowerCase();
    return _allFaculty.where((f) {
      final matchesQuery = query.isEmpty ||
          f.fullName.toLowerCase().contains(query) ||
          f.displayInitials.toLowerCase().contains(query) ||
          f.displayEmail.toLowerCase().contains(query) ||
          f.displayDesignation.toLowerCase().contains(query);

      final matchesRank = _selectedRank == 'All' ||
          f.displayDesignation.toLowerCase().contains(_selectedRank.toLowerCase());

      return matchesQuery && matchesRank;
    }).toList();
  }

  Color _getRankColor(String designation) {
    final lower = designation.toLowerCase();
    if (lower.contains('professor') && !lower.contains('assoc') && !lower.contains('asst')) {
      return const Color(0xFF6366F1); // Indigo
    } else if (lower.contains('assoc')) {
      return const Color(0xFF2563EB); // Royal Blue
    } else if (lower.contains('asst')) {
      return const Color(0xFF0D9488); // Teal
    } else if (lower.contains('lecturer')) {
      return const Color(0xFFD97706); // Amber
    }
    return AppTheme.accent;
  }

  @override
  Widget build(BuildContext context) {
    final content = _buildContent();
    if (widget.isEmbedded) {
      return SingleChildScrollView(
        child: content,
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Faculty & Staff Directory'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Directory',
            onPressed: _loadFacultyList,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1200),
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    final filtered = _filteredFaculty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header Section
        LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 650;
            final headerText = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Official ICE Faculty Directory',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Managing ${_allFaculty.length} official faculty members synchronized with master routine short codes',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            );

            return Flex(
              direction: isNarrow ? Axis.vertical : Axis.horizontal,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.center,
              children: [
                if (isNarrow)
                  headerText
                else
                  Expanded(child: headerText),
                if (isNarrow) const SizedBox(height: 16),
                if (!isNarrow) const SizedBox(width: 16),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _loadFacultyList,
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Refresh'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.textSecondary,
                        side: const BorderSide(color: AppTheme.border),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      ),
                    ),
                    ElevatedButton.icon(
                      onPressed: _showAddFacultyDialog,
                      icon: const Icon(Icons.person_add_alt_1, size: 18),
                      label: const Text('Add Teacher'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),

        const SizedBox(height: 20),

        // Quick Stats Ribbon
        _buildStatsRibbon(),

        const SizedBox(height: 20),

        // Search and Filter Bar
        _buildSearchAndFilterBar(),

        const SizedBox(height: 20),

        // Faculty Grid / List
        if (_isLoading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48.0),
            child: Center(
              child: Column(
                children: [
                  CircularProgressIndicator(strokeWidth: 2.5),
                  SizedBox(height: 16),
                  Text('Loading official faculty directory from Supabase...', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                ],
              ),
            ),
          )
        else if (_errorMessage != null)
          Card(
            color: AppTheme.error.withValues(alpha: 0.08),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: AppTheme.error.withValues(alpha: 0.3)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                children: [
                  const Icon(Icons.error_outline, color: AppTheme.error),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppTheme.error, fontSize: 13),
                    ),
                  ),
                  TextButton(
                    onPressed: _loadFacultyList,
                    child: const Text('Retry'),
                  ),
                ],
              ),
            ),
          )
        else if (filtered.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(48.0),
              child: Center(
                child: Column(
                  children: [
                    const Icon(Icons.person_search_outlined, size: 48, color: AppTheme.textMuted),
                    const SizedBox(height: 12),
                    const Text(
                      'No faculty members found',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppTheme.textPrimary),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _searchController.text.isNotEmpty
                          ? 'Try adjusting your search query or clear the rank filter.'
                          : 'No entries registered in public.faculty_directory.',
                      style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 760;
              if (isWide) {
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    mainAxisExtent: 164,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) => _buildFacultyCard(filtered[index]),
                );
              }

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, index) => _buildFacultyCard(filtered[index]),
              );
            },
          ),
      ],
    );
  }

  Widget _buildStatsRibbon() {
    int profCount = 0;
    int assocCount = 0;
    int asstCount = 0;
    int lectCount = 0;

    for (final f in _allFaculty) {
      final rank = f.displayDesignation.toLowerCase();
      if (rank.contains('professor') && !rank.contains('assoc') && !rank.contains('asst')) {
        profCount++;
      } else if (rank.contains('assoc')) {
        assocCount++;
      } else if (rank.contains('asst')) {
        asstCount++;
      } else if (rank.contains('lecturer')) {
        lectCount++;
      }
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _buildStatPill('Total Faculty', _allFaculty.length, AppTheme.primary),
          const SizedBox(width: 12),
          _buildStatPill('Professors', profCount, const Color(0xFF6366F1)),
          const SizedBox(width: 12),
          _buildStatPill('Assoc. Professors', assocCount, const Color(0xFF2563EB)),
          const SizedBox(width: 12),
          _buildStatPill('Asst. Professors', asstCount, const Color(0xFF0D9488)),
          const SizedBox(width: 12),
          _buildStatPill('Lecturers', lectCount, const Color(0xFFD97706)),
        ],
      ),
    );
  }

  Widget _buildStatPill(String title, int count, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppTheme.textSecondary),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: color),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilterBar() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.search, color: AppTheme.textMuted, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search by full name, initials [MIH], rank, or email...',
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 18, color: AppTheme.textMuted),
                    onPressed: () => setState(() => _searchController.clear()),
                  ),
              ],
            ),
            const Divider(height: 16),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const Text('Rank Filter:', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
                  const SizedBox(width: 8),
                  ...['All', 'Professor', 'Associate Professor', 'Assistant Professor', 'Lecturer'].map((rank) {
                    final isSelected = _selectedRank == rank;
                    return Padding(
                      padding: const EdgeInsets.only(right: 6.0),
                      child: FilterChip(
                        label: Text(rank, style: TextStyle(fontSize: 12, color: isSelected ? Colors.white : AppTheme.textPrimary)),
                        selected: isSelected,
                        selectedColor: AppTheme.primary,
                        backgroundColor: const Color(0xFFF1F5F9),
                        checkmarkColor: Colors.white,
                        onSelected: (val) {
                          setState(() {
                            _selectedRank = val ? rank : 'All';
                          });
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFacultyCard(FacultyModel faculty) {
    final displayInit = faculty.displayInitials;
    final designation = faculty.displayDesignation;
    final rankColor = _getRankColor(designation);
    final email = faculty.displayEmail;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppTheme.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14.0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Avatar with initials
            CircleAvatar(
              radius: 22,
              backgroundColor: AppTheme.primary.withValues(alpha: 0.12),
              child: Text(
                displayInit,
                style: const TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            const SizedBox(width: 14),

            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Full Name and Monospace Badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          faculty.fullName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppTheme.textPrimary,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Monospace Initials Badge matching routine short codes
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFCBD5E1)),
                        ),
                        child: Text(
                          '[$displayInit]',
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                            color: Color(0xFF334155),
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Designation Badge & Department
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: rankColor.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: rankColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(
                          designation,
                          style: TextStyle(
                            color: rankColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: const Color(0xFFE2E8F0)),
                        ),
                        child: Text(
                          faculty.department,
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textMuted,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 6),

                  // Email with Icon
                  Row(
                    children: [
                      const Icon(Icons.email_outlined, size: 14, color: AppTheme.textSecondary),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          email,
                          style: const TextStyle(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 6),

            // Edit Action Button
            IconButton(
              icon: const Icon(Icons.edit_outlined, size: 20, color: AppTheme.textSecondary),
              tooltip: 'Edit Faculty Member',
              onPressed: () => _showEditFacultyDialog(faculty),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddFacultyDialog() {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController();
    final initialsCtrl = TextEditingController();
    final emailCtrl = TextEditingController();
    final passCtrl = TextEditingController(text: 'teacher123');
    String selectedDesignation = 'Associate Professor';
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Add Faculty Member'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    controller: nameCtrl,
                    label: 'Faculty Full Name',
                    hint: 'Dr. Md. Imran Hossain',
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Full name is required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: initialsCtrl,
                    label: 'Teacher Initials / Routine Short Code (e.g. MIH, MAH)',
                    hint: 'MIH',
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 5,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                    ],
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Teacher initials are required';
                      if (!RegExp(r'^[a-zA-Z0-9]{2,5}$').hasMatch(val.trim())) {
                        return 'Initials must be 2-5 alphanumeric characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedDesignation,
                    decoration: const InputDecoration(labelText: 'Designation / Academic Rank'),
                    items: const [
                      DropdownMenuItem(value: 'Professor', child: Text('Professor')),
                      DropdownMenuItem(value: 'Associate Professor', child: Text('Associate Professor')),
                      DropdownMenuItem(value: 'Assistant Professor', child: Text('Assistant Professor')),
                      DropdownMenuItem(value: 'Lecturer', child: Text('Lecturer')),
                      DropdownMenuItem(value: 'Faculty', child: Text('Faculty Member')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedDesignation = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: emailCtrl,
                    label: 'Official Email (Optional)',
                    hint: 'imran@ice.dept',
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: passCtrl,
                    label: 'Default Password',
                    hint: 'teacher123',
                    isPassword: true,
                    validator: (val) {
                      if (val == null || val.length < 6) return 'Password must be at least 6 characters';
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setModalState(() => isSubmitting = true);
                      try {
                        final cleanInit = initialsCtrl.text.trim().toUpperCase();
                        final email = emailCtrl.text.trim().isNotEmpty
                            ? emailCtrl.text.trim()
                            : '${cleanInit.toLowerCase()}@ice.dept';

                        await _dbService.createTeacherUser(
                          email: email,
                          password: passCtrl.text,
                          name: nameCtrl.text.trim(),
                          initials: cleanInit,
                          designation: selectedDesignation,
                        );

                        if (ctx.mounted) Navigator.pop(ctx);
                        await _loadFacultyList();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Faculty member ${nameCtrl.text.trim()} [$cleanInit] added successfully!'),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        }
                      } catch (e) {
                        setModalState(() => isSubmitting = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to add faculty: $e'), backgroundColor: AppTheme.error),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Add Faculty'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditFacultyDialog(FacultyModel faculty) {
    final formKey = GlobalKey<FormState>();
    final nameCtrl = TextEditingController(text: faculty.fullName);
    final initialsCtrl = TextEditingController(text: faculty.displayInitials);
    final emailCtrl = TextEditingController(text: faculty.email ?? faculty.displayEmail);
    final oldInitials = faculty.displayInitials;
    String selectedDesignation = faculty.displayDesignation;
    final standardRanks = ['Professor', 'Associate Professor', 'Assistant Professor', 'Lecturer', 'Faculty'];
    if (!standardRanks.contains(selectedDesignation)) {
      selectedDesignation = 'Faculty';
    }
    bool isSaving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AlertDialog(
          title: const Text('Edit Faculty Member'),
          content: SingleChildScrollView(
            child: Form(
              key: formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AppTextField(
                    controller: nameCtrl,
                    label: 'Faculty Full Name',
                    hint: 'Dr. Md. Imran Hossain',
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Full name is required';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: initialsCtrl,
                    label: 'Teacher Initials / Short Code (e.g. MIH, MAH)',
                    hint: 'MIH',
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 5,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z0-9]')),
                    ],
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return 'Teacher initials are required';
                      if (!RegExp(r'^[a-zA-Z0-9]{2,5}$').hasMatch(val.trim())) {
                        return 'Initials must be 2-5 alphanumeric characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    initialValue: selectedDesignation,
                    decoration: const InputDecoration(labelText: 'Designation / Academic Rank'),
                    items: const [
                      DropdownMenuItem(value: 'Professor', child: Text('Professor')),
                      DropdownMenuItem(value: 'Associate Professor', child: Text('Associate Professor')),
                      DropdownMenuItem(value: 'Assistant Professor', child: Text('Assistant Professor')),
                      DropdownMenuItem(value: 'Lecturer', child: Text('Lecturer')),
                      DropdownMenuItem(value: 'Faculty', child: Text('Faculty Member')),
                    ],
                    onChanged: (val) {
                      if (val != null) setModalState(() => selectedDesignation = val);
                    },
                  ),
                  const SizedBox(height: 12),
                  AppTextField(
                    controller: emailCtrl,
                    label: 'Official Email',
                    hint: 'imran@ice.dept',
                    keyboardType: TextInputType.emailAddress,
                    validator: (val) {
                      if (val != null && val.trim().isNotEmpty && !val.contains('@')) {
                        return 'Enter a valid email address';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: isSaving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: isSaving
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setModalState(() => isSaving = true);
                      try {
                        final newInit = initialsCtrl.text.trim().toUpperCase();
                        final newName = nameCtrl.text.trim();
                        final newEmail = emailCtrl.text.trim().isNotEmpty ? emailCtrl.text.trim() : null;
                        final updatedFaculty = faculty.copyWith(
                          fullName: newName,
                          initials: newInit,
                          email: newEmail,
                          designation: selectedDesignation,
                        );

                        // Optimistically update local state immediately
                        final index = _allFaculty.indexWhere((f) =>
                            (faculty.id != null && f.id == faculty.id) ||
                            f.displayInitials == oldInitials);
                        if (index != -1) {
                          setState(() {
                            _allFaculty[index] = updatedFaculty;
                          });
                        }

                        await _dbService.updateFacultyMember(
                          facultyId: faculty.id,
                          userId: faculty.userId,
                          name: newName,
                          initials: newInit,
                          email: newEmail,
                          designation: selectedDesignation,
                          oldInitials: oldInitials,
                        );

                        if (ctx.mounted) Navigator.pop(ctx);
                        await _loadFacultyList();
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Faculty updated to $newName [$newInit]'),
                              backgroundColor: AppTheme.success,
                            ),
                          );
                        }
                      } catch (e) {
                        setModalState(() => isSaving = false);
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Failed to update faculty: $e'), backgroundColor: AppTheme.error),
                          );
                        }
                      }
                    },
              child: isSaving
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save Changes'),
            ),
          ],
        ),
      ),
    );
  }
}
