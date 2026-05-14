import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../features/calls/call_models.dart';
import '../features/calls/call_signaling_service.dart';
import '../features/calls/calls_providers.dart';
import '../features/calls/jitsi_service.dart';
import '../features/conversations/conversations_providers.dart';
import '../features/user/user_providers.dart';
import '../theme/app_theme.dart';
import 'message_screen.dart';

class CallsScreen extends ConsumerStatefulWidget {
  const CallsScreen({super.key});

  @override
  ConsumerState<CallsScreen> createState() => _CallsScreenState();
}

class _CallsScreenState extends ConsumerState<CallsScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    ref.invalidate(callHistoryProvider);
    await ref.read(callHistoryProvider.future);
  }

  Future<void> _startCallFromHistory(
      CallHistoryEntry entry, bool isVideo) async {
    final me = ref.read(meProvider).valueOrNull;
    if (me == null) return;

    final granted = await JitsiService.requestCallPermissions();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Camera and microphone permissions are required.')),
        );
      }
      return;
    }

    try {
      final jwt = await CallSignalingService.startCall(
        userId: me.id,
        conversationId: entry.conversationId,
        convTitle: entry.convTitle,
        participants: entry.participants,
        companyId: me.companyId,
        isGroup: entry.isGroup,
      );

      if (jwt == null || jwt.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to start call.')),
          );
        }
        return;
      }

      final convId = entry.conversationId;
      final fullName = '${me.firstname} ${me.lastname}'.trim();

      await JitsiService.join(
        conversationId: convId,
        jwtToken: jwt,
        isVideo: isVideo,
        userName: fullName,
        userEmail: me.email,
        userAvatar: me.img,
        onReadyToClose: () async {
          try {
            await CallSignalingService.hangupCall(
              userId: me.id,
              userFullName: fullName,
              conversationId: convId,
            );
          } catch (_) {}
          if (mounted) ref.invalidate(callHistoryProvider);
        },
      );
    } catch (e) {
      debugPrint('[CallsScreen] Start call failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Call failed: $e')),
        );
      }
    }
  }

  void _openConversation(CallHistoryEntry entry) {
    final selfId = ref.read(meProvider).valueOrNull?.id ?? '';
    final rooms = ref.read(sortedRoomsProvider).valueOrNull;
    final room = rooms?.firstWhere(
          (r) => r.id == entry.conversationId,
          orElse: () => entry.toRoom(),
        ) ??
        entry.toRoom();

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessageScreen(room: room, selfId: selfId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final callsAsync = ref.watch(callHistoryProvider);
    final selfId = ref.watch(meProvider).valueOrNull?.id ?? '';

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: SafeArea(
        child: Column(
          children: [
            _buildSearchBar(),
            Expanded(
              child: callsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: AppTheme.primary,
                    strokeWidth: 2,
                  ),
                ),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          color: AppTheme.danger, size: 32),
                      const SizedBox(height: 8),
                      Text('Failed to load call history',
                          style: AppTheme.bodySmall),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: _refresh,
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (entries) {
                  final filtered = _searchQuery.isEmpty
                      ? entries
                      : entries
                          .where((e) => e.convTitle
                              .toLowerCase()
                              .contains(_searchQuery.toLowerCase()))
                          .toList();

                  if (filtered.isEmpty) return _buildEmpty();

                  final sections = _groupByDate(filtered);
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    color: AppTheme.primary,
                    child: ListView.builder(
                      padding: const EdgeInsets.only(bottom: 24),
                      itemCount: _flatCount(sections),
                      itemBuilder: (_, i) =>
                          _buildFlatItem(sections, i, selfId),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Date grouping ───────────────────────────────────────────────────────────

  List<_Section> _groupByDate(List<CallHistoryEntry> entries) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));

    final Map<String, List<CallHistoryEntry>> bucket = {};
    final List<String> order = [];

    for (final e in entries) {
      final d = DateTime(e.createdAt.year, e.createdAt.month, e.createdAt.day);
      final String key;
      if (d == today) {
        key = 'Today';
      } else if (d == yesterday) {
        key = 'Yesterday';
      } else {
        key = DateFormat('EEE, MMM d').format(e.createdAt);
      }
      if (!bucket.containsKey(key)) {
        order.add(key);
        bucket[key] = [];
      }
      bucket[key]!.add(e);
    }

    return order.map((k) => _Section(label: k, entries: bucket[k]!)).toList();
  }

  int _flatCount(List<_Section> sections) =>
      sections.fold(0, (sum, s) => sum + 1 + s.entries.length);

  Widget _buildFlatItem(List<_Section> sections, int index, String selfId) {
    int cursor = 0;
    for (final section in sections) {
      if (cursor == index) return _buildDateHeader(section.label);
      cursor++;
      for (final entry in section.entries) {
        if (cursor == index) return _buildCallTile(entry, selfId);
        cursor++;
      }
    }
    return const SizedBox.shrink();
  }

  // ── Widgets ─────────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return Container(
      color: AppTheme.bgCard,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.bgElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: TextField(
          controller: _searchController,
          style: AppTheme.bodyMedium,
          onChanged: (v) => setState(() => _searchQuery = v),
          decoration: InputDecoration(
            hintText: 'Search calls…',
            hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.textDim),
            prefixIcon: const Icon(Icons.search_rounded,
                color: AppTheme.textDim, size: 18),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: const Icon(Icons.close_rounded,
                        color: AppTheme.textDim, size: 18),
                  )
                : null,
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(vertical: 10),
          ),
        ),
      ),
    );
  }

  Widget _buildDateHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        label,
        style: AppTheme.caption.copyWith(
          fontWeight: FontWeight.w700,
          color: AppTheme.textMuted,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Widget _buildCallTile(CallHistoryEntry entry, String selfId) {
    final direction = entry.direction(selfId);
    final isMissed = direction == CallDirection.missed;

    return InkWell(
      onTap: () => _openConversation(entry),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          border: Border(
            bottom: BorderSide(color: AppTheme.border, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            _buildAvatar(entry),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (entry.isGroup) ...[
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 5, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppTheme.accentSoft,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(Icons.group_rounded,
                              size: 12, color: AppTheme.primary),
                        ),
                      ],
                      Expanded(
                        child: Text(
                          entry.convTitle,
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w600,
                            color: isMissed
                                ? AppTheme.danger
                                : AppTheme.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      _directionIcon(direction),
                      const SizedBox(width: 4),
                      Text(
                        _directionLabel(direction),
                        style: AppTheme.bodySmall.copyWith(
                          color:
                              isMissed ? AppTheme.danger : AppTheme.textMuted,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(
                        entry.isVideo
                            ? Icons.videocam_rounded
                            : Icons.phone_rounded,
                        size: 13,
                        color: AppTheme.textDim,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _formatTime(entry.createdAt),
                        style: AppTheme.caption,
                      ),
                      if (entry.callDuration.isNotEmpty) ...[
                        Text(' · ', style: AppTheme.caption),
                        Text(
                          entry.callDuration,
                          style: AppTheme.caption,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            _CallActionButton(
              icon: Icons.phone_rounded,
              color: AppTheme.success,
              onTap: () => _startCallFromHistory(entry, false),
            ),
            const SizedBox(width: 8),
            _CallActionButton(
              icon: Icons.videocam_rounded,
              color: AppTheme.primary,
              onTap: () => _startCallFromHistory(entry, true),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(CallHistoryEntry entry) {
    final img = entry.convImg;
    final hasValidUrl = img != null &&
        img.isNotEmpty &&
        (img.startsWith('http://') || img.startsWith('https://'));

    if (hasValidUrl) {
      final isGroup = entry.isGroup;
      return ClipRRect(
        borderRadius:
            isGroup ? BorderRadius.circular(14) : BorderRadius.circular(25),
        child: CachedNetworkImage(
          imageUrl: img,
          width: 50,
          height: 50,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _initialsAvatar(entry),
        ),
      );
    }
    return _initialsAvatar(entry);
  }

  Widget _initialsAvatar(CallHistoryEntry entry) {
    final isGroup = entry.isGroup;
    const palettes = [
      [Color(0xFF6366F1), Color(0xFF8B5CF6)],
      [Color(0xFFEC4899), Color(0xFFF43F5E)],
      [Color(0xFF3B82F6), Color(0xFF06B6D4)],
      [Color(0xFF10B981), Color(0xFF059669)],
      [Color(0xFFF59E0B), Color(0xFFD97706)],
      [Color(0xFFEF4444), Color(0xFFDC2626)],
    ];
    final index = entry.convTitle.hashCode % palettes.length;
    final colors = palettes[index];
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: isGroup ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: isGroup ? BorderRadius.circular(14) : null,
      ),
      child: Center(
        child: Text(
          entry.initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _directionIcon(CallDirection direction) {
    switch (direction) {
      case CallDirection.incoming:
        return const Icon(Icons.call_received_rounded,
            size: 14, color: AppTheme.success);
      case CallDirection.outgoing:
        return const Icon(Icons.call_made_rounded,
            size: 14, color: AppTheme.success);
      case CallDirection.missed:
        return const Icon(Icons.call_missed_rounded,
            size: 14, color: AppTheme.danger);
    }
  }

  String _directionLabel(CallDirection direction) {
    switch (direction) {
      case CallDirection.incoming:
        return 'Incoming';
      case CallDirection.outgoing:
        return 'Outgoing';
      case CallDirection.missed:
        return 'Missed';
    }
  }

  String _formatTime(DateTime dt) {
    final h = dt.hour == 0
        ? 12
        : dt.hour > 12
            ? dt.hour - 12
            : dt.hour;
    final m = dt.minute.toString().padLeft(2, '0');
    final suffix = dt.hour >= 12 ? 'PM' : 'AM';
    return '$h:$m $suffix';
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _searchQuery.isNotEmpty
                ? Icons.search_off_rounded
                : Icons.phone_missed_rounded,
            size: 52,
            color: AppTheme.textDim,
          ),
          const SizedBox(height: 16),
          Text(
            _searchQuery.isNotEmpty
                ? 'No results for "$_searchQuery"'
                : 'No call history yet',
            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600),
          ),
          if (_searchQuery.isEmpty) ...[
            const SizedBox(height: 6),
            Text(
              'Your call history will appear here',
              style: AppTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

// ── Supporting types ──────────────────────────────────────────────────────────

class _Section {
  const _Section({required this.label, required this.entries});
  final String label;
  final List<CallHistoryEntry> entries;
}

class _CallActionButton extends StatelessWidget {
  const _CallActionButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }
}
