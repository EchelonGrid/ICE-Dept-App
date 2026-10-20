import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/chat_message_model.dart';
import '../../models/user_model.dart';
import '../../services/auth_service.dart';
import '../../widgets/profile_avatar_button.dart';
import 'info_channel_screen.dart';
import 'open_group_screen.dart';

class ChatListScreen extends StatefulWidget {
  final String? sharedText;
  const ChatListScreen({super.key, this.sharedText});

  @override
  State<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends State<ChatListScreen> {
  String? _activeSharedText;

  @override
  void initState() {
    super.initState();
    _activeSharedText = widget.sharedText;
  }

  @override
  void didUpdateWidget(covariant ChatListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.sharedText != oldWidget.sharedText) {
      _activeSharedText = widget.sharedText;
    }
  }

  void _navigateToOpenGroup(ChatScope scope) {
    final textToSend = _activeSharedText;
    setState(() {
      _activeSharedText = null;
    });

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => OpenGroupScreen(
          scope: scope,
          initialDraftText: textToSend,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final user = authService.currentUser;
    final profile = authService.studentProfile;
    final batchNum = profile?.batchNumber ?? 21;
    final isCr = profile?.isCr ?? false;
    final canAccessCrGroup = isCr || user?.role == UserRole.admin;

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Batch Messages',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFF0F172A), letterSpacing: -0.3),
            ),
            Text(
              'Batch $batchNum & Department Hub',
              style: const TextStyle(fontSize: 11, color: Color(0xFF0284C7), fontWeight: FontWeight.w600),
            ),
          ],
        ),
        actions: const [
          ProfileAvatarButton(),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Incoming Shared Text/Link Banner
            if (_activeSharedText != null && _activeSharedText!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFE0F2FE),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF38BDF8)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.share, color: Color(0xFF0284C7), size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Shared Link Received',
                            style: TextStyle(
                              color: Color(0xFF0369A1),
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                        ),
                        IconButton(
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(),
                          icon: const Icon(Icons.close, size: 16, color: Color(0xFF0369A1)),
                          onPressed: () => setState(() => _activeSharedText = null),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _activeSharedText!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF0F172A),
                        fontWeight: FontWeight.w600,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Tap any group below to post this shared link directly.',
                      style: TextStyle(color: Color(0xFF64748B), fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],

            // Batch Info Top Badge
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF1E293B)),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.school_outlined, color: Color(0xFF38BDF8), size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              'ICE BATCH $batchNum',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 13,
                                letterSpacing: 0.5,
                              ),
                            ),
                            if (isCr) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF00B4D8).withValues(alpha: 0.25),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: const Text(
                                  'CR PRIVILEGE',
                                  style: TextStyle(color: Color(0xFF38BDF8), fontSize: 9, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        const Text(
                          'Strictly isolated batch channels & global department forums.',
                          style: TextStyle(color: Color(0xFF94A3B8), fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // SECTION 1: BATCH EXCLUSIVE CHANNELS
            const Text(
              'BATCH CHANNELS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Color(0xFF64748B),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),

            // Tile 1: Batch Information Group (Megaphone / Official Channel)
            _buildChatChannelTile(
              context: context,
              icon: Icons.campaign_outlined,
              iconColor: const Color(0xFF0284C7),
              iconBgColor: const Color(0xFFE0F2FE),
              title: 'Batch Information Group',
              subtitle: 'Batch $batchNum Official Channel • Broadcasts & Notices',
              tagText: isCr ? 'CR BROADCAST' : 'READ-ONLY',
              tagColor: isCr ? const Color(0xFF0284C7) : const Color(0xFF64748B),
              description: 'Official department announcements, exam notices, and CR updates. Tap to read broadcasts or leave a comment.',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const InfoChannelScreen()),
                );
              },
            ),
            const SizedBox(height: 10),

            // Tile 2: Batch Open Group (Chat bubbles / Ephemeral Chat)
            _buildChatChannelTile(
              context: context,
              icon: Icons.forum_outlined,
              iconColor: const Color(0xFF10B981),
              iconBgColor: const Color(0xFFD1FAE5),
              title: 'Batch Open Group',
              subtitle: 'Batch $batchNum Discussion Forum • 24h Ephemeral Chat',
              tagText: '24H EPHEMERAL',
              tagColor: const Color(0xFF10B981),
              description: 'Open discussion forum for all batch members. Discuss classes, exams, and comment on notice threads.',
              onTap: () => _navigateToOpenGroup(ChatScope.batch),
            ),
            const SizedBox(height: 20),

            // SECTION 2: GLOBAL & EXCLUSIVE CHANNELS
            const Text(
              'DEPARTMENT & COUNCIL CHANNELS',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 11,
                color: Color(0xFF64748B),
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 10),

            // Tile 3: Department Open Group (Global across all batches)
            _buildChatChannelTile(
              context: context,
              icon: Icons.public_outlined,
              iconColor: const Color(0xFF6366F1),
              iconBgColor: const Color(0xFFEEF2FF),
              title: 'Department Open Group',
              subtitle: 'All Department Batches • 24h Ephemeral Global Chat',
              tagText: 'GLOBAL 24H',
              tagColor: const Color(0xFF6366F1),
              description: 'Department-wide communication hub connecting students across all 4 academic years.',
              onTap: () => _navigateToOpenGroup(ChatScope.department),
            ),
            const SizedBox(height: 10),

            // Tile 4: CR Info Group (Hidden, visible only to CRs and Admin/Clerk)
            if (canAccessCrGroup) ...[
              _buildChatChannelTile(
                context: context,
                icon: Icons.shield_outlined,
                iconColor: const Color(0xFFF59E0B),
                iconBgColor: const Color(0xFFFEF3C7),
                title: 'CR Info Group',
                subtitle: 'Class Representatives & Department Council • 7-Day Ephemeral',
                tagText: 'CR ONLY • 7 DAYS',
                tagColor: const Color(0xFFF59E0B),
                description: 'Exclusive communication channel for Batch Class Representatives and department administration. Messages auto-purge after 1 week (7 days).',
                onTap: () => _navigateToOpenGroup(ChatScope.cr),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildChatChannelTile({
    required BuildContext context,
    required IconData icon,
    required Color iconColor,
    required Color iconBgColor,
    required String title,
    required String subtitle,
    required String tagText,
    required Color tagColor,
    required String description,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFFE2E8F0), width: 1.0),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: iconBgColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: iconColor, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 14.5,
                                color: Color(0xFF0F172A),
                                letterSpacing: -0.2,
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: tagColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              tagText,
                              style: TextStyle(
                                color: tagColor,
                                fontSize: 9.5,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF64748B),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                const Icon(Icons.chevron_right, color: Color(0xFF94A3B8), size: 20),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              description,
              style: const TextStyle(
                fontSize: 11.5,
                color: Color(0xFF475569),
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
