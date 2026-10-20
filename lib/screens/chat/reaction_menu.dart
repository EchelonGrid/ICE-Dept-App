import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/chat_message_model.dart';

class ReactionMenu {
  static const List<String> standardEmojis = ['👍', '❤️', '😂', '😮', '😢', '🙂'];

  static void show({
    required BuildContext context,
    required ChatMessageModel message,
    required bool isMe,
    required bool isAdmin,
    required String? currentUserId,
    required Function(String emoji) onReactionSelected,
    required VoidCallback onEditPressed,
    required VoidCallback onDeletePressed,
    required VoidCallback onReplyPressed,
  }) {
    HapticFeedback.mediumImpact();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1E293B),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Emoji Reaction Bar
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(32),
                    border: Border.all(color: const Color(0xFF334155)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: standardEmojis.map((emoji) {
                      final hasReacted = message.hasReacted(emoji, currentUserId);
                      return GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          Navigator.pop(ctx);
                          onReactionSelected(emoji);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 150),
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: hasReacted
                                ? const Color(0xFF0284C7).withValues(alpha: 0.3)
                                : Colors.transparent,
                            shape: BoxShape.circle,
                            border: hasReacted
                                ? Border.all(color: const Color(0xFF38BDF8), width: 1.5)
                                : null,
                          ),
                          child: Text(
                            emoji,
                            style: const TextStyle(fontSize: 24),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),

                const Divider(color: Color(0xFF334155), height: 16),

                // Reply Action
                ListTile(
                  leading: const Icon(Icons.reply, color: Color(0xFF38BDF8), size: 20),
                  title: const Text('Reply to Message', style: TextStyle(color: Colors.white, fontSize: 14)),
                  onTap: () {
                    Navigator.pop(ctx);
                    onReplyPressed();
                  },
                ),

                // Copy Text Action
                ListTile(
                  leading: const Icon(Icons.copy, color: Colors.white70, size: 20),
                  title: const Text('Copy Text', style: TextStyle(color: Colors.white, fontSize: 14)),
                  onTap: () {
                    Clipboard.setData(ClipboardData(text: message.message));
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Message copied to clipboard.')),
                    );
                  },
                ),

                // Author Only: Edit Message
                if (isMe) ...[
                  ListTile(
                    leading: const Icon(Icons.edit_outlined, color: Color(0xFF38BDF8), size: 20),
                    title: const Text('Edit Message', style: TextStyle(color: Color(0xFF38BDF8), fontSize: 14, fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(ctx);
                      onEditPressed();
                    },
                  ),
                ],

                // Author or Admin: Delete Message
                if (isMe || isAdmin) ...[
                  ListTile(
                    leading: const Icon(Icons.delete_outline, color: Color(0xFFEF4444), size: 20),
                    title: const Text('Delete Message', style: TextStyle(color: Color(0xFFEF4444), fontSize: 14, fontWeight: FontWeight.bold)),
                    onTap: () {
                      Navigator.pop(ctx);
                      onDeletePressed();
                    },
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
