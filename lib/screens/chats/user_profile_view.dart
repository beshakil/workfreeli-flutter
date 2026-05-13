import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../core/models/conversation_models.dart';
import '../../theme/app_theme.dart';

/// Shows a centered modal dialog displaying user profile information.
Future<void> showUserProfileModal(
  BuildContext context, {
  required Room room,
}) {
  return showDialog(
    context: context,
    builder: (ctx) => UserProfileModal(room: room),
  );
}

class UserProfileModal extends StatelessWidget {
  const UserProfileModal({super.key, required this.room});

  final Room room;

  @override
  Widget build(BuildContext context) {
    final colors = _avatarColors(room.id);

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.border.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close button
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded,
                        color: AppTheme.textMuted, size: 22),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 32),
                  ),
                ],
              ),
            ),

            // Profile Avatar
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: room.convImg == null || room.convImg!.isEmpty
                      ? LinearGradient(
                          colors: colors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  borderRadius: BorderRadius.circular(room.isGroup ? 28 : 50),
                  boxShadow: room.convImg == null || room.convImg!.isEmpty
                      ? [
                          BoxShadow(
                            color: colors[0].withValues(alpha: 0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: room.convImg != null && room.convImg!.isNotEmpty
                    ? ClipRRect(
                        borderRadius:
                            BorderRadius.circular(room.isGroup ? 28 : 50),
                        child: CachedNetworkImage(
                          imageUrl: room.convImg!,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: colors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius:
                                  BorderRadius.circular(room.isGroup ? 28 : 50),
                            ),
                            child: const Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                          errorWidget: (_, __, ___) => Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: colors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius:
                                  BorderRadius.circular(room.isGroup ? 28 : 50),
                            ),
                            child: Center(
                              child: Text(
                                room.initials,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 36,
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                    : Center(
                        child: Text(
                          room.initials,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                            fontSize: 36,
                          ),
                        ),
                      ),
              ),
            ),

            // User Name
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                room.title,
                style: AppTheme.headingSmall.copyWith(
                  fontWeight: FontWeight.w700,
                  fontSize: 22,
                ),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),

            const SizedBox(height: 8),

            // User Email / Type
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    room.isGroup ? Icons.group_rounded : Icons.email_outlined,
                    size: 14,
                    color: AppTheme.textDim,
                  ),
                  const SizedBox(width: 6),
                  Flexible(
                    child: Text(
                      room.isGroup ? 'Channel' : 'user@example.com',
                      style: AppTheme.bodyMedium.copyWith(
                        color: AppTheme.textDim,
                        fontSize: 14,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // Divider
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 20),
              color: AppTheme.border.withValues(alpha: 0.3),
            ),

            const SizedBox(height: 24),

            // Action Buttons
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _ActionButton(
                    icon: Icons.phone_rounded,
                    label: 'Call',
                    color: AppTheme.success,
                    onTap: () {
                      Navigator.of(context).pop();
                      // TODO: Implement call action
                    },
                  ),
                  _ActionButton(
                    icon: Icons.videocam_rounded,
                    label: 'Video',
                    color: AppTheme.primary,
                    onTap: () {
                      Navigator.of(context).pop();
                      // TODO: Implement video call action
                    },
                  ),
                  _ActionButton(
                    icon: Icons.message_rounded,
                    label: 'SMS',
                    color: const Color(0xFFF59E0B),
                    onTap: () {
                      Navigator.of(context).pop();
                      // TODO: Implement SMS action
                    },
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }

  static List<Color> _avatarColors(String id) {
    const palettes = [
      [Color(0xFF6366F1), Color(0xFF8B5CF6)],
      [Color(0xFFEC4899), Color(0xFFF43F5E)],
      [Color(0xFF3B82F6), Color(0xFF06B6D4)],
      [Color(0xFF10B981), Color(0xFF059669)],
      [Color(0xFFF59E0B), Color(0xFFEF4444)],
    ];
    return palettes[id.hashCode.abs() % palettes.length];
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: color.withValues(alpha: 0.3),
                width: 1.5,
              ),
            ),
            child: Icon(
              icon,
              color: color,
              size: 26,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: AppTheme.bodyMedium.copyWith(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
