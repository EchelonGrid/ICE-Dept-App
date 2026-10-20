import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../services/auth_service.dart';
import '../services/theme_service.dart';

void showProfileModal(BuildContext context) {
  HapticFeedback.lightImpact();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const ProfileModalSheet(),
  );
}

class ProfileModalSheet extends StatelessWidget {
  const ProfileModalSheet({super.key});

  String _getInitials(String? name) {
    if (name == null || name.trim().isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }

  Color _getAvatarColor(String? name) {
    if (name == null || name.isEmpty) return const Color(0xFF0284C7);
    final hash = name.codeUnits.fold(0, (prev, elem) => prev + elem);
    const colors = [
      Color(0xFF0284C7),
      Color(0xFF10B981),
      Color(0xFF8B5CF6),
      Color(0xFFF59E0B),
      Color(0xFFEC4899),
      Color(0xFF06B6D4),
    ];
    return colors[hash % colors.length];
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final student = authService.studentProfile;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final sheetBg = isDark ? const Color(0xFF0F172A) : Colors.white;
    final cardBg = isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC);
    final borderColor = isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0);
    final textColor = isDark ? Colors.white : const Color(0xFF0F172A);
    final mutedTextColor = isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    final avatarBg = _getAvatarColor(user?.name);
    final initials = _getInitials(user?.name);

    return Material(
      type: MaterialType.transparency,
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        padding: EdgeInsets.only(
          top: 12,
          left: 20,
          right: 20,
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
        ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // 1. Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF334155) : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Google-Style Profile Header Card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: borderColor),
                ),
                child: Column(
                  children: [
                    // Avatar with status ring
                    Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        CircleAvatar(
                          radius: 36,
                          backgroundColor: avatarBg,
                          child: Text(
                            initials,
                            style: const TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: sheetBg,
                            shape: BoxShape.circle,
                          ),
                          child: Container(
                            width: 14,
                            height: 14,
                            decoration: const BoxDecoration(
                              color: Color(0xFF10B981),
                              shape: BoxShape.circle,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),

                    // Legal Name
                    Text(
                      user?.name ?? 'ICE Department Member',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 3),

                    // Email Address
                    Text(
                      user?.email ?? 'No email registered',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        color: mutedTextColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),

                    // Badges row
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 6,
                      children: [
                        // Role Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0284C7).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: const Color(0xFF0284C7).withValues(alpha: 0.3)),
                          ),
                          child: Text(
                            user?.role.name.toUpperCase() ?? 'STUDENT',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0284C7),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),

                        // CR Badge (if applicable)
                        if (student?.isCr == true)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFFF59E0B).withValues(alpha: 0.18),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.4)),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star, size: 12, color: Color(0xFFF59E0B)),
                                SizedBox(width: 4),
                                Text(
                                  'CLASS REPRESENTATIVE',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFFD97706),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Batch Number
                        if (student?.batchNumber != null)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: const Color(0xFF10B981).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.3)),
                            ),
                            child: Text(
                              'BATCH ${student!.batchNumber}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                color: Color(0xFF059669),
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),

                        // Roll Number
                        if (student?.studentIdRoll != null && student!.studentIdRoll.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'ROLL ${student.studentIdRoll}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: isDark ? const Color(0xFFCBD5E1) : const Color(0xFF475569),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),

              // 3. App Appearance / Theme Controls
              ListenableBuilder(
                listenable: ThemeService.instance,
                builder: (context, _) {
                  final currentMode = ThemeService.instance.themeMode;
                  return Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.palette_outlined, size: 18, color: textColor),
                            const SizedBox(width: 8),
                            Text(
                              'App Appearance',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _ThemeOptionButton(
                                key: const ValueKey('theme_btn_light'),
                                label: 'Light',
                                icon: Icons.light_mode_outlined,
                                isSelected: currentMode == ThemeMode.light,
                                isDarkSheet: isDark,
                                onTap: () => ThemeService.instance.setThemeMode(ThemeMode.light),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _ThemeOptionButton(
                                key: const ValueKey('theme_btn_dark'),
                                label: 'Dark',
                                icon: Icons.dark_mode_outlined,
                                isSelected: currentMode == ThemeMode.dark,
                                isDarkSheet: isDark,
                                onTap: () => ThemeService.instance.setThemeMode(ThemeMode.dark),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _ThemeOptionButton(
                                key: const ValueKey('theme_btn_system'),
                                label: 'System',
                                icon: Icons.settings_system_daydream_outlined,
                                isSelected: currentMode == ThemeMode.system,
                                isDarkSheet: isDark,
                                onTap: () => ThemeService.instance.setThemeMode(ThemeMode.system),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 18),

              // 4. Prominent Log Out Action Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (dialogCtx) => AlertDialog(
                        backgroundColor: sheetBg,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                        title: Text(
                          'Sign Out of ICE App?',
                          style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
                        ),
                        content: Text(
                          'Are you sure you want to log out from this account on this device?',
                          style: TextStyle(color: mutedTextColor),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dialogCtx, false),
                            child: Text('Cancel', style: TextStyle(color: mutedTextColor)),
                          ),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFFEF4444),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () => Navigator.pop(dialogCtx, true),
                            child: const Text('Sign Out'),
                          ),
                        ],
                      ),
                    );

                    if (confirmed == true && context.mounted) {
                      Navigator.pop(context); // Close sheet
                      try {
                        await authService.signOut();
                        await Supabase.instance.client.auth.signOut();
                      } catch (e) {
                        debugPrint('[ProfileModal] Error during sign out: $e');
                      }
                      if (context.mounted) {
                        context.go('/login');
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Logged out successfully.'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444), size: 20),
                  label: const Text(
                    'Log Out',
                    style: TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w700, fontSize: 14),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFEF4444).withValues(alpha: 0.1),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: BorderSide(color: const Color(0xFFEF4444).withValues(alpha: 0.25)),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 10),

              // Subtext branding
              Text(
                'Dept. of ICE • System Portal v1.0',
                style: TextStyle(fontSize: 11, color: mutedTextColor, fontWeight: FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }
}

class _ThemeOptionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final bool isDarkSheet;
  final VoidCallback onTap;

  const _ThemeOptionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.isDarkSheet,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final activeBg = isDarkSheet ? const Color(0xFF0284C7).withValues(alpha: 0.2) : const Color(0xFFE0F2FE);
    const activeBorder = Color(0xFF0284C7);
    const activeColor = Color(0xFF0284C7);

    final inactiveBg = isDarkSheet ? const Color(0xFF0F172A) : Colors.white;
    final inactiveBorder = isDarkSheet ? const Color(0xFF334155) : const Color(0xFFCBD5E1);
    final inactiveColor = isDarkSheet ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
          decoration: BoxDecoration(
            color: isSelected ? activeBg : inactiveBg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? activeBorder : inactiveBorder,
              width: isSelected ? 1.5 : 1.0,
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected ? activeColor : inactiveColor,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.w800 : FontWeight.w500,
                  color: isSelected ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
