import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/conversation_models.dart';
import '../../features/conversations/conversations_providers.dart';
import '../../features/conversations/conversations_service.dart';
import '../../theme/app_theme.dart';

/// Bottom sheet modal for room/chat long-press actions.
///
/// Displays a list of actions (Pin/Unpin, Mute/Unmute, Lock/Unlock, Archive)
/// that can be performed on a room or conversation.
class ChatListActionModal extends ConsumerWidget {
  /// The room/conversation to perform actions on
  final Room room;

  /// The current user's ID
  final String selfId;

  const ChatListActionModal({
    super.key,
    required this.room,
    required this.selfId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = [
      _ActionItem(
        icon: room.isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
        label: room.isPinned ? 'Unpin' : 'Pin',
        isDestructive: room.isPinned,
      ),
      _ActionItem(
        icon: room.isMuted ? Icons.volume_up_rounded : Icons.volume_off_rounded,
        label: room.isMuted ? 'Unmute' : 'Mute',
        isDestructive: false,
      ),
      _ActionItem(
        icon: room.isClosedFor ? Icons.lock_open_rounded : Icons.lock_rounded,
        label: room.isClosedFor ? 'Unlock Room' : 'Lock Room',
        isDestructive: room.isClosedFor,
      ),
      _ActionItem(
        icon: Icons.archive_rounded,
        label: 'Archive Room',
        isDestructive: false,
      ),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle bar indicator
            Container(
              margin: const EdgeInsets.only(bottom: 16, top: 16),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Action items
            for (int i = 0; i < actions.length; i++) ...[
              _ActionTile(
                icon: actions[i].icon,
                label: actions[i].label,
                isDestructive: actions[i].isDestructive,
                onTap: () => _handleAction(context, ref, i),
              ),
              if (i < actions.length - 1) const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    int index,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();

    try {
      switch (index) {
        case 0:
          await ConversationsService.togglePin(room.id, selfId);
        case 1:
          await ConversationsService.toggleMute(room.id, selfId);
        case 2:
          await ConversationsService.toggleClose(room.id);
        case 3:
          await ConversationsService.archiveConv(room.id);
      }
      ref.invalidate(roomsProvider);
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content:
              Text('Failed: ${e.toString().replaceFirst('Exception: ', '')}'),
        ),
      );
    }
  }
}

// ── Action item model ──────────────────────────────────────────────────────────

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

// ── Action row tile ────────────────────────────────────────────────────────────

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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.bgElevated,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppTheme.border),
              ),
              child: Center(
                child: Icon(icon, size: 18, color: color),
              ),
            ),
            const SizedBox(width: 14),
            Text(
              label,
              style: AppTheme.bodyLarge.copyWith(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
