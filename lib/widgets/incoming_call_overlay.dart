import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/calls/incoming_call_state.dart';
import '../theme/app_theme.dart';

class IncomingCallOverlay extends ConsumerWidget {
  const IncomingCallOverlay({
    super.key,
    required this.state,
    required this.onAccept,
    required this.onDecline,
  });

  final IncomingCallState state;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(
      color: Colors.transparent,
      child: Container(
        color: Colors.black.withValues(alpha: 0.65),
        child: SafeArea(
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.4),
                    blurRadius: 32,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildCallerAvatar(),
                  const SizedBox(height: 16),
                  Text(
                    state.callerName ?? 'Unknown',
                    style: AppTheme.headingSmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        state.isVideo
                            ? Icons.videocam_rounded
                            : Icons.phone_rounded,
                        size: 14,
                        color: AppTheme.textMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        state.isVideo
                            ? 'Incoming video call'
                            : 'Incoming audio call',
                        style: AppTheme.bodySmall,
                      ),
                    ],
                  ),
                  if (state.convTitle != null &&
                      state.convTitle!.isNotEmpty &&
                      state.convTitle != state.callerName) ...[
                    const SizedBox(height: 2),
                    Text(
                      state.convTitle!,
                      style: AppTheme.caption,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 32),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _ActionCircle(
                        icon: Icons.call_end_rounded,
                        color: AppTheme.danger,
                        label: 'Decline',
                        onTap: onDecline,
                      ),
                      _ActionCircle(
                        icon: state.isVideo
                            ? Icons.videocam_rounded
                            : Icons.phone_rounded,
                        color: AppTheme.success,
                        label: 'Accept',
                        onTap: onAccept,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCallerAvatar() {
    final img = state.callerImg;
    final hasUrl = img != null &&
        img.isNotEmpty &&
        (img.startsWith('http://') || img.startsWith('https://'));

    if (hasUrl) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(36),
        child: CachedNetworkImage(
          imageUrl: img,
          width: 72,
          height: 72,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _initialsAvatar(),
        ),
      );
    }
    return _initialsAvatar();
  }

  Widget _initialsAvatar() {
    const palettes = [
      [Color(0xFF6366F1), Color(0xFF8B5CF6)],
      [Color(0xFFEC4899), Color(0xFFF43F5E)],
      [Color(0xFF3B82F6), Color(0xFF06B6D4)],
      [Color(0xFF10B981), Color(0xFF059669)],
      [Color(0xFFF59E0B), Color(0xFFEF4444)],
    ];
    final name = state.callerName ?? '?';
    final colors = palettes[name.hashCode.abs() % palettes.length];
    final words = name.trim().split(RegExp(r'\s+'));
    final initials = words.length >= 2
        ? '${words[0][0]}${words[1][0]}'.toUpperCase()
        : name.isNotEmpty
            ? name[0].toUpperCase()
            : '?';

    return Container(
      width: 72,
      height: 72,
      decoration: BoxDecoration(
        gradient:
            LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(36),
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
              color: Colors.white, fontSize: 26, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }
}

class _ActionCircle extends StatelessWidget {
  const _ActionCircle({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: AppTheme.caption),
        ],
      ),
    );
  }
}
