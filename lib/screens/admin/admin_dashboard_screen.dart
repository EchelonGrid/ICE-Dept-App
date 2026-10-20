import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/theme/app_theme.dart';
import '../../models/batch_model.dart';
import '../../models/user_model.dart';
import '../../models/student_profile_model.dart';
import '../../services/auth_service.dart';
import '../../services/db_service.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_text_field.dart';
import '../../widgets/skeleton_loader.dart';
import '../../widgets/profile_avatar_button.dart';
import '../auth/login_screen.dart';
import 'clerk_routine_upload_screen.dart';
import 'batch_details_screen.dart';
import 'clerk_notices_screen.dart';
import 'clerk_faculty_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  final DbService _dbService = DbService();
  int _selectedTabIndex = 0;

  List<BatchModel> _batches = [];
  List<StudentProfileModel> _students = [];
  List<UserModel> _teachers = [];
  bool _isLoading = true;
  int _batchFilterIndex = 0; // 0: Active Batches, 1: Alumni / Graduated

  List<BatchModel> get _filteredBatches {
    if (_batchFilterIndex == 0) {
      return _batches.where((b) => b.isActive).toList();
    } else {
      return _batches.where((b) => b.isGraduated).toList();
    }
  }

  // Dedicated private instance FormKey and TextEditingControllers
  final _onboardFormKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController(text: 'ice123456');
  final _nameController = TextEditingController();
  final _rollController = TextEditingController();
  String? _selectedBatchId;
  bool _isCr = false;

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    _rollController.dispose();
    super.dispose();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      final batches = await _dbService.getBatches();
      final students = await _dbService.getStudents();
      final teachers = await _dbService.getTeachers();

      if (mounted) {
        setState(() {
          _batches = batches;
          _students = students;
          _teachers = teachers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading data: $e'), backgroundColor: AppTheme.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width >= 900;

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: Row(
        children: [
          // Sidebar for Web/Desktop
          _buildSidebar(isDesktop),

          // Main Content Area
          Expanded(
            child: Column(
              children: [
                _buildTopBar(isDesktop),
                Expanded(
                  child: _isLoading
                      ? SkeletonLoader.listSkeleton(count: 5)
                      : SingleChildScrollView(
                          padding: EdgeInsets.all(isDesktop ? 24.0 : 16.0),
                          child: Center(
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 1200),
                              child: _buildCurrentTab(),
                            ),
                          ),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSidebar(bool isDesktop) {
    return Container(
      width: isDesktop ? 260 : 72,
      color: AppTheme.primary,
      child: Column(
        children: [
          // Department Header
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 20 : 12,
              vertical: 24,
            ),
            child: Row(
              mainAxisAlignment: isDesktop ? MainAxisAlignment.start : MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppTheme.accent,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.hub, color: Colors.white, size: 20),
                ),
                if (isDesktop) ...[
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'ICE Dept App',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Clerk Portal',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          const Divider(color: Color(0xFF334155), height: 1),

          // Navigation Links
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 16),
              children: [
                _buildNavItem(0, Icons.group_outlined, 'Batch & Students', isDesktop),
                _buildNavItem(1, Icons.person_add_alt_1_outlined, 'Onboard Student', isDesktop),
                _buildNavItem(2, Icons.badge_outlined, 'Faculty & Staff', isDesktop),
                _buildNavItem(3, Icons.calendar_month_outlined, 'Master Routine', isDesktop),
                _buildNavItem(4, Icons.campaign_outlined, 'Notices', isDesktop),
              ],
            ),
          ),

          // Sign Out Button
          Padding(
            padding: EdgeInsets.all(isDesktop ? 16.0 : 8.0),
            child: InkWell(
              onTap: () async {
                final authService = Provider.of<AuthService>(context, listen: false);
                await authService.signOut();
                if (mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                }
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 16 : 8,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisAlignment: isDesktop ? MainAxisAlignment.start : MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.logout, color: AppTheme.error, size: 20),
                    if (isDesktop) ...[
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Sign Out',
                          style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String title, bool isDesktop) {
    final isSelected = _selectedTabIndex == index;
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 12 : 8, vertical: 4),
      child: InkWell(
        onTap: () => setState(() => _selectedTabIndex = index),
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 16 : 8,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accent.withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: isSelected ? Border.all(color: AppTheme.accent, width: 1) : null,
          ),
          child: Row(
            mainAxisAlignment: isDesktop ? MainAxisAlignment.start : MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: isSelected ? AppTheme.accent : const Color(0xFF94A3B8),
                size: 20,
              ),
              if (isDesktop) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      color: isSelected ? Colors.white : const Color(0xFF94A3B8),
                      fontSize: 14,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(bool isDesktop) {
    return Container(
      height: 64,
      padding: EdgeInsets.symmetric(horizontal: isDesktop ? 24 : 12),
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          const Expanded(
            child: Text(
              'Admin Dashboard',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.refresh, color: AppTheme.textSecondary),
            onPressed: _loadDashboardData,
            tooltip: 'Refresh Data',
          ),
          if (isDesktop) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppTheme.accent.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.verified, size: 16, color: AppTheme.accent),
                  SizedBox(width: 6),
                  Text(
                    'Clerk Mode',
                    style: TextStyle(
                      color: AppTheme.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(width: 8),
          const ProfileAvatarButton(),
        ],
      ),
    );
  }

  Widget _buildCurrentTab() {
    switch (_selectedTabIndex) {
      case 0:
        return _buildBatchesAndStudentsView();
      case 1:
        return _buildStudentOnboardingForm();
      case 2:
        return _buildFacultyManagementView();
      case 3:
        return _buildRoutineManagementView();
      case 4:
        return _buildNoticesManagementView();
      default:
        return const SizedBox();
    }
  }

  // ================= 1. BATCHES & STUDENTS VIEW =================
  Widget _buildBatchesAndStudentsView() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 550;
              return Flex(
                direction: isNarrow ? Axis.vertical : Axis.horizontal,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: isNarrow ? CrossAxisAlignment.start : CrossAxisAlignment.center,
                children: [
                  Flexible(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Active Batches & Enrolled Students',
                          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Managing ${_batches.length} batches and ${_students.length} students',
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (isNarrow) const SizedBox(height: 12),
                  ElevatedButton.icon(
                    onPressed: _showCreateBatchDialog,
                    icon: const Icon(Icons.add, size: 18),
                    label: const Text('Add Batch'),
                    style: ElevatedButton.styleFrom(minimumSize: const Size(130, 42)),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 20),

          // Filter Tabs (Active vs. Alumni)
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _buildBatchFilterPill(
                title: 'Active Batches (${_batches.where((b) => b.isActive).length})',
                isSelected: _batchFilterIndex == 0,
                icon: Icons.school_outlined,
                onTap: () => setState(() => _batchFilterIndex = 0),
              ),
              _buildBatchFilterPill(
                title: 'Alumni / Graduated (${_batches.where((b) => b.isGraduated).length})',
                isSelected: _batchFilterIndex == 1,
                icon: Icons.history_edu_outlined,
                onTap: () => setState(() => _batchFilterIndex = 1),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Batches Cards Row
          if (_filteredBatches.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppTheme.border),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _batchFilterIndex == 0 ? Icons.school_outlined : Icons.history_edu_outlined,
                      size: 40,
                      color: AppTheme.textMuted,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _batchFilterIndex == 0 ? 'No active batches found.' : 'No alumni batches archived yet.',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.textSecondary),
                    ),
                  ],
                ),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final double cardWidth;
                if (constraints.maxWidth < 560) {
                  if (constraints.maxWidth < 380) {
                    cardWidth = constraints.maxWidth;
                  } else {
                    cardWidth = (constraints.maxWidth - 16) / 2;
                  }
                } else if (constraints.maxWidth < 900) {
                  cardWidth = (constraints.maxWidth - (16 * 2)) / 3;
                } else {
                  cardWidth = (constraints.maxWidth - (16 * 3)) / 4;
                }
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: _filteredBatches.map((batch) {
                    final studentCount = _students.where((s) => s.batchId == batch.id).length;
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          final batchName = 'Batch ${batch.batchNumber}';
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => BatchDetailsScreen(
                                batchId: batch.id,
                                batchNumber: batch.batchNumber,
                                batchName: batchName,
                              ),
                            ),
                          ).then((_) => _loadDashboardData());
                        },
                        child: Container(
                          width: cardWidth,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: AppTheme.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppTheme.border),
                            boxShadow: AppTheme.softCardShadow,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      'Batch ${batch.batchNumber} • ${batch.currentSemester}',
                                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: batch.isActive
                                          ? AppTheme.success.withValues(alpha: 0.12)
                                          : Colors.blueGrey.shade100,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Text(
                                      batch.isActive ? 'ACTIVE' : 'ALUMNI',
                                      style: TextStyle(
                                        color: batch.isActive ? AppTheme.success : Colors.blueGrey.shade800,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    '$studentCount Students Enrolled',
                                    style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const Icon(Icons.arrow_forward_ios, size: 12, color: AppTheme.textMuted),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                );
              },
            ),
          const SizedBox(height: 32),

          // Student Data Table
          SizedBox(
            width: double.infinity,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Student Directory', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    if (_students.isEmpty)
                      const Padding(
                        padding: EdgeInsets.all(32.0),
                        child: Center(child: Text('No students onboarded yet. Use the Onboard Student tab.')),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: ConstrainedBox(
                              constraints: BoxConstraints(minWidth: constraints.maxWidth),
                              child: Theme(
                                data: Theme.of(context).copyWith(
                                  dividerColor: Colors.grey.shade200,
                                ),
                                child: DataTable(
                                  columnSpacing: 24.0,
                                  horizontalMargin: 20.0,
                                  headingRowColor: WidgetStateProperty.all(const Color(0xFFF8FAFC)),
                                  columns: const [
                                    DataColumn(label: Text('Roll Number', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Name', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Email', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Batch', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Role / CR', style: TextStyle(fontWeight: FontWeight.bold))),
                                    DataColumn(label: Text('Actions', style: TextStyle(fontWeight: FontWeight.bold))),
                                  ],
                                  rows: _students.map((student) {
                                    return DataRow(cells: [
                                      DataCell(Text(student.studentIdRoll, style: const TextStyle(fontWeight: FontWeight.w600))),
                                      DataCell(Text(student.userName ?? 'Student')),
                                      DataCell(Text(student.userEmail ?? '-')),
                                      DataCell(Text('Batch ${student.batchNumber ?? '-'}')),
                                      DataCell(
                                        student.isCr
                                            ? Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: AppTheme.accent.withValues(alpha: 0.12),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: const Text('CR', style: TextStyle(color: AppTheme.accent, fontWeight: FontWeight.bold, fontSize: 12)),
                                              )
                                            : const Text('Student', style: TextStyle(color: AppTheme.textSecondary)),
                                      ),
                                      DataCell(
                                        IconButton(
                                          icon: Icon(student.isCr ? Icons.star : Icons.star_border, color: student.isCr ? AppTheme.warning : AppTheme.textMuted),
                                          tooltip: student.isCr ? 'Revoke CR Status' : 'Make Class Representative (CR)',
                                          onPressed: () async {
                                            await _dbService.updateCrStatus(student.userId, !student.isCr);
                                            await _loadDashboardData();
                                          },
                                        ),
                                      ),
                                    ]);
                                  }).toList(),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBatchFilterPill({
    required String title,
    required bool isSelected,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.accent : AppTheme.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppTheme.accent : AppTheme.border,
            width: isSelected ? 1.5 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppTheme.accent.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : AppTheme.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: TextStyle(
                color: isSelected ? Colors.white : AppTheme.textPrimary,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showCreateBatchDialog() {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add New Batch'),
        content: SingleChildScrollView(
          child: AppTextField(
            controller: controller,
            label: 'Batch Number',
            hint: 'e.g. 25',
            keyboardType: TextInputType.number,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final batchNum = int.tryParse(controller.text.trim());
              if (batchNum != null) {
                Navigator.pop(ctx);
                await _dbService.createBatch(batchNum);
                await _loadDashboardData();
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  // ================= 2. STUDENT ONBOARDING FORM =================
  Widget _buildStudentOnboardingForm() {
    final defaultBatchId = _selectedBatchId ?? (_batches.isNotEmpty ? _batches.first.id : null);

    return SingleChildScrollView(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Card(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Form(
              key: _onboardFormKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Onboard New Student',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Admin manually creates credentials. Students will be prompted to change their password on first login.',
                    style: TextStyle(color: AppTheme.textSecondary, fontSize: 13),
                  ),
                  const SizedBox(height: 24),

                  AppTextField(
                    controller: _nameController,
                    label: 'Full Name',
                    hint: 'e.g. Alex Johnson',
                    prefixIcon: Icons.person_outline,
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  AppTextField(
                    controller: _rollController,
                    label: 'Student Roll / ID',
                    hint: 'e.g. 2108001',
                    prefixIcon: Icons.badge_outlined,
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  AppTextField(
                    controller: _emailController,
                    label: 'Student Email',
                    hint: 'alex.2108001@ice.dept',
                    prefixIcon: Icons.email_outlined,
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  AppTextField(
                    controller: _passwordController,
                    label: 'Default Password',
                    hint: 'ice123456',
                    prefixIcon: Icons.lock_outline,
                    validator: (v) => v!.trim().isEmpty ? 'Required' : null,
                  ),
                  const SizedBox(height: 16),

                  // Batch Dropdown
                  const Text('Assigned Batch', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        isExpanded: true,
                        value: defaultBatchId,
                        items: _batches.map((b) {
                          return DropdownMenuItem(
                            value: b.id,
                            child: Text('Batch ${b.batchNumber} (${b.status})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          setState(() => _selectedBatchId = val);
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // CR Checkbox
                  CheckboxListTile(
                    value: _isCr,
                    title: const Text('Designate as Class Representative (CR)', style: TextStyle(fontSize: 14)),
                    subtitle: const Text('Grants notice posting and CT countdown privileges', style: TextStyle(fontSize: 12, color: AppTheme.textSecondary)),
                    onChanged: (v) => setState(() => _isCr = v ?? false),
                    controlAffinity: ListTileControlAffinity.leading,
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 24),

                  AppButton(
                    text: 'Register & Provision Student',
                    onPressed: () async {
                      if (!_onboardFormKey.currentState!.validate()) return;

                      final targetBatchId = defaultBatchId;
                      if (targetBatchId == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please select a batch first.')),
                        );
                        return;
                      }

                      final messenger = ScaffoldMessenger.of(context);
                      try {
                        await _dbService.createStudentUser(
                          email: _emailController.text.trim(),
                          password: _passwordController.text,
                          name: _nameController.text.trim(),
                          batchId: targetBatchId,
                          rollNumber: _rollController.text.trim(),
                          isCr: _isCr,
                        );

                        if (mounted) {
                          messenger.showSnackBar(
                            const SnackBar(content: Text('Student onboarded successfully!'), backgroundColor: AppTheme.success),
                          );
                          _nameController.clear();
                          _rollController.clear();
                          _emailController.clear();
                          _passwordController.text = 'ice123456';
                          _isCr = false;
                          await _loadDashboardData();
                          setState(() => _selectedTabIndex = 0);
                        }
                      } catch (e) {
                        if (mounted) {
                          messenger.showSnackBar(
                            SnackBar(content: Text('Error: $e'), backgroundColor: AppTheme.error),
                          );
                        }
                      }
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ================= 3. FACULTY MANAGEMENT VIEW =================
  Widget _buildFacultyManagementView() {
    return ClerkFacultyScreen(
      isEmbedded: true,
      initialFaculty: _teachers,
    );
  }

  // ================= 4. ROUTINE MANAGEMENT VIEW =================
  Widget _buildRoutineManagementView() {
    final batchNames = _batches.map((b) => 'Batch ${b.batchNumber}').toList();
    return ClerkRoutineUploadScreen(
      initialBatches: batchNames.isNotEmpty ? batchNames : null,
    );
  }

  // ================= 5. NOTICES MANAGEMENT VIEW =================
  Widget _buildNoticesManagementView() {
    final batchNames = _batches.map((b) => 'Batch ${b.batchNumber}').toList();
    return ClerkNoticesScreen(
      initialBatches: batchNames.isNotEmpty ? batchNames : null,
    );
  }
}
