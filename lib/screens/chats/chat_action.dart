import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';

/// Bottom sheet modal for message long-press actions.
///
/// Displays emoji reactions and message actions
/// (Flag, Reply, Forward, Copy, Add title, Edit, Delete).
class ChatActionModal extends ConsumerWidget {
  final String messageText;

  /// Whether this is the current user's message (for edit/delete)
  final bool isOwnMessage;

  const ChatActionModal({
    super.key,
    required this.messageText,
    this.isOwnMessage = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle bar indicator
                Container(
                  margin: const EdgeInsets.only(bottom: 20, top: 16),
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),

                // Reaction bar
                _buildReactionBar(context),

                const SizedBox(height: 16),

                // Divider
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Divider(
                    color: AppTheme.border,
                    height: 1,
                  ),
                ),

                const SizedBox(height: 8),

                // Action menu items
                _buildActionList(context, ref),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReactionBar(BuildContext context) {
    final reactions = [
      const _ReactionData(icon: Icons.thumb_up_rounded, label: 'Like'),
      const _ReactionData(icon: Icons.favorite_rounded, label: 'Love'),
      const _ReactionData(icon: Icons.favorite_rounded, label: 'Care'),
      const _ReactionData(icon: Icons.mood_rounded, label: 'Wow'),
      const _ReactionData(icon: Icons.emoji_emotions_rounded, label: 'Haha'),
      const _ReactionData(
          icon: Icons.sentiment_dissatisfied_rounded, label: 'Sad'),
      const _ReactionData(
          icon: Icons.sentiment_very_dissatisfied_rounded, label: 'Angry'),
      const _ReactionData(
          icon: Icons.volunteer_activism_rounded, label: 'Thanks'),
    ];

    return SizedBox(
      height: 48,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: reactions.length,
        itemBuilder: (context, index) {
          final reaction = reactions[index];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _ReactionButton(
              icon: reaction.icon,
              label: reaction.label,
              onTap: () {
                Navigator.of(context).pop();
                // TODO: Implement reaction logic
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildActionList(BuildContext context, WidgetRef ref) {
    final actions = <_ActionItem>[
      _ActionItem(
        icon: Icons.flag_rounded,
        label: 'Flag',
        isDestructive: false,
      ),
      _ActionItem(
        icon: Icons.reply_rounded,
        label: 'Reply',
        isDestructive: false,
      ),
      _ActionItem(
        icon: Icons.forward_rounded,
        label: 'Forward',
        isDestructive: false,
      ),
      _ActionItem(
        icon: Icons.copy_all_rounded,
        label: 'Copy',
        isDestructive: false,
      ),
      _ActionItem(
        icon: Icons.edit_note_rounded,
        label: 'Add message title',
        isDestructive: false,
      ),
    ];

    // Add Edit and Delete only for own messages
    if (isOwnMessage) {
      actions.add(_ActionItem(
        icon: Icons.edit_rounded,
        label: 'Edit',
        isDestructive: false,
      ));
      actions.add(_ActionItem(
        icon: Icons.delete_rounded,
        label: 'Delete Message',
        isDestructive: true,
      ));
    }

    return Column(
      children: [
        for (int i = 0; i < actions.length; i++) ...[
          _ActionTile(
            icon: actions[i].icon,
            label: actions[i].label,
            isDestructive: actions[i].isDestructive,
            onTap: () => _handleAction(context, ref, i, actions[i]),
          ),
          if (i < actions.length - 1) const SizedBox(height: 4),
        ],
      ],
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    int index,
    _ActionItem action,
  ) async {
    Navigator.of(context).pop();

    switch (action.label) {
      case 'Flag':
        // TODO: Implement flag logic
        break;
      case 'Reply':
        // TODO: Implement reply logic
        break;
      case 'Forward':
        // TODO: Implement forward logic
        break;
      case 'Copy':
        // TODO: Implement copy logic
        break;
      case 'Add message title':
        // TODO: Implement add title logic
        break;
      case 'Edit':
        // TODO: Implement edit logic
        break;
      case 'Delete Message':
        // TODO: Implement delete logic
        break;
    }
  }
}

// ── Reaction data model ──────────────────────────────────────────────────────

class _ReactionData {
  final IconData icon;
  final String label;
  const _ReactionData({
    required this.icon,
    required this.label,
  });
}

// ── Action item model ────────────────────────────────────────────────────────

class _ActionItem {
  final IconData icon;
  final String label;
  final bool isDestructive;
  const _ActionItem({
    required this.icon,
    required this.label,
    required this.isDestructive,
  });
}

// ── Reaction button widget ───────────────────────────────────────────────────

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.bgElevated,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.border),
        ),
        child: Icon(
          icon,
          size: 22,
          color: AppTheme.textPrimary,
        ),
      ),
    );
  }
}

// ── Action tile widget ───────────────────────────────────────────────────────

class _ActionTile extends StatelessWidget {
  const _ActionTile({
    required this.icon,
    required this.label,
    required this.isDestructive,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool isDestructive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? AppTheme.danger : AppTheme.textPrimary;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppTheme.bgElevated,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.border),
              ),
              child: Center(
                child: Icon(icon, size: 18, color: color),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: AppTheme.bodyLarge.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
