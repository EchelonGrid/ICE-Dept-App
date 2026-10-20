import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import 'profile_modal.dart';

class ProfileAvatarButton extends StatelessWidget {
  final double size;
  final EdgeInsetsGeometry padding;

  const ProfileAvatarButton({
    super.key,
    this.size = 34.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
  });

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
    final initials = _getInitials(user?.name);
    final avatarColor = _getAvatarColor(user?.name);

    return Padding(
      padding: padding,
      child: InkWell(
        onTap: () => showProfileModal(context),
        borderRadius: BorderRadius.circular(size),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: avatarColor,
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.85),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: size * 0.42,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),
            if (student?.isCr == true)
              Positioned(
                bottom: -2,
                right: -2,
                child: Container(
                  width: 13,
                  height: 13,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF59E0B),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 1.5),
                  ),
                  child: const Center(
                    child: Icon(Icons.star, color: Colors.white, size: 7),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
