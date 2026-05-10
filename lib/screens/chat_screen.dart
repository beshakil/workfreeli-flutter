import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/models/conversation_models.dart';
import '../features/conversations/conversations_providers.dart';
import '../features/user/user_providers.dart';
import '../theme/app_theme.dart';
import 'message_screen.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'all';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // sortedRoomsProvider merges server rooms with XMPP-driven previews and re-sorts.
    final roomsAsync = ref.watch(sortedRoomsProvider);
    final unreadCounts = ref.watch(unreadCountsProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          _buildSearchBar(),
          _buildFilterBar(),
          Expanded(
            child: roomsAsync.when(
              loading: () => _buildSkeletons(),
              error: (err, _) => _buildError(
                err.toString().replaceFirst('Exception: ', ''),
                onRetry: () => ref.invalidate(roomsProvider),
              ),
              data: (rooms) {
                final filtered = _applyFilters(rooms, unreadCounts);

                if (filtered.isEmpty) {
                  return _searchQuery.isNotEmpty
                      ? _buildNoResults()
                      : _buildEmpty();
                }

                final selfId = ref.read(meProvider).valueOrNull?.id ?? '';
                return RefreshIndicator(
                  onRefresh: () async => ref.invalidate(roomsProvider),
                  color: AppTheme.primary,
                  backgroundColor: AppTheme.bgCard,
                  child: ListView.builder(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.only(bottom: 16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) => _RoomTile(
                      room: filtered[index],
                      selfId: selfId,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      color: AppTheme.bgCard,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
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
            hintText: 'Search conversations…',
            hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.textDim),
            prefixIcon:
                Icon(Icons.search_rounded, color: AppTheme.textDim, size: 18),
            suffixIcon: _searchQuery.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: Icon(Icons.close_rounded,
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

  Widget _buildSkeletons() => ListView.builder(
        itemCount: 10,
        padding: const EdgeInsets.symmetric(vertical: 4),
        itemBuilder: (_, __) => const _SkeletonTile(),
      );

  Widget _buildError(String message, {required VoidCallback onRetry}) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.wifi_off_rounded, size: 52, color: AppTheme.textDim),
            const SizedBox(height: 16),
            Text('Could not load conversations',
                style:
                    AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(message, style: AppTheme.caption, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: AppTheme.bgElevated,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Icon(Icons.chat_bubble_outline_rounded,
                size: 34, color: AppTheme.textDim),
          ),
          const SizedBox(height: 20),
          Text('No conversations yet',
              style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Your conversations will appear here', style: AppTheme.caption),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded, size: 48, color: AppTheme.textDim),
          const SizedBox(height: 16),
          Text('No results for "$_searchQuery"',
              style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  // ── Filter bar ──────────────────────────────────────────────────────────────

  Widget _buildFilterBar() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(
          bottom: BorderSide(color: AppTheme.border, width: 1),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: _filters.map((f) => _buildFilterChip(f)).toList(),
        ),
      ),
    );
  }

  Widget _buildFilterChip(_FilterConfig config) {
    final isSelected = _selectedFilter == config.key;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: () => setState(() => _selectedFilter = config.key),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF0F2750) : AppTheme.bgElevated,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: isSelected ? const Color(0xFF0F2750) : AppTheme.border,
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (config.icon != null) ...[
                Icon(config.icon,
                    size: 16,
                    color: isSelected ? Colors.white : AppTheme.textDim),
                const SizedBox(width: 6),
              ],
              Text(
                config.label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.textMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Room> _applyFilters(List<Room> rooms, Map<String, int> unreadCounts) {
    var filtered = rooms;

    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
              (r) => r.title.toLowerCase().contains(_searchQuery.toLowerCase()))
          .toList();
    }

    switch (_selectedFilter) {
      case 'unread':
        filtered =
            filtered.where((r) => (unreadCounts[r.id] ?? 0) > 0).toList();
      case 'group':
        filtered = filtered.where((r) => r.isGroup).toList();
      case 'archive':
        filtered = filtered.where((r) => r.isArchived).toList();
      case 'locked':
        filtered = filtered.where((r) => r.isClosedFor).toList();
    }

    return filtered;
  }
}

// ── Filter configs ────────────────────────────────────────────────────────────

class _FilterConfig {
  final String key;
  final String label;
  final IconData? icon;
  const _FilterConfig(this.key, this.label, this.icon);
}

const _filters = [
  _FilterConfig('all', 'All', null),
  _FilterConfig('unread', 'Unread', Icons.email_rounded),
  _FilterConfig('favorite', 'Favorite', Icons.star_rounded),
  _FilterConfig('group', 'Group', Icons.group_rounded),
  _FilterConfig('archive', 'Archive', Icons.archive_rounded),
  _FilterConfig('threaded', 'Threaded', Icons.forum_rounded),
  _FilterConfig('locked', 'Locked', Icons.lock_rounded),
];

// ─── Room Tile ────────────────────────────────────────────────────────────────

class _RoomTile extends ConsumerWidget {
  const _RoomTile({required this.room, required this.selfId});

  final Room room;
  final String selfId;

  static const List<List<Color>> _gradients = [
    [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    [Color(0xFFEC4899), Color(0xFFF43F5E)],
    [Color(0xFF3B82F6), Color(0xFF06B6D4)],
    [Color(0xFF10B981), Color(0xFF059669)],
    [Color(0xFFF59E0B), Color(0xFFEF4444)],
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = _gradients[room.id.hashCode.abs() % _gradients.length];
    // Watch per-conversation unread count — rebuilds only this tile.
    final unread = ref.watch(
      unreadCountsProvider.select((m) => m[room.id] ?? 0),
    );

    return InkWell(
      onTap: () {
        Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => MessageScreen(room: room, selfId: selfId),
        ));
      },
      onLongPress: () {
        showDialog(
          context: context,
          barrierColor: Colors.black.withValues(alpha: 0.3),
          builder: (_) => _RoomActionSheet(room: room, selfId: selfId),
        );
      },
      splashColor: AppTheme.primary.withValues(alpha: 0.06),
      highlightColor: AppTheme.primary.withValues(alpha: 0.04),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            // Avatar with unread badge
            Stack(
              children: [
                _RoomAvatar(room: room, colors: colors),
                if (unread > 0)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.danger,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: AppTheme.bg, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          unread > 99 ? '99+' : '$unread',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 14),

            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          room.title,
                          style: AppTheme.bodyMedium.copyWith(
                            fontSize: 16,
                            fontWeight:
                                unread > 0 ? FontWeight.w700 : FontWeight.w600,
                            color: const Color(0xFF0F2750),
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (room.formattedTime.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            room.formattedTime,
                            style: AppTheme.caption.copyWith(
                              fontSize: 12,
                              color: unread > 0
                                  ? AppTheme.primary
                                  : AppTheme.textDim,
                              fontWeight: unread > 0
                                  ? FontWeight.w600
                                  : FontWeight.w400,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        room.isGroup
                            ? Icons.group_rounded
                            : Icons.person_rounded,
                        size: 14,
                        color: AppTheme.textDim,
                      ),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          room.lastMsgPreview?.isNotEmpty == true
                              ? room.lastMsgPreview!
                              : room.isGroup
                                  ? 'Channel'
                                  : 'Direct message',
                          style: AppTheme.caption.copyWith(
                            fontSize: 14,
                            color: unread > 0
                                ? AppTheme.textMuted
                                : AppTheme.textDim,
                            fontWeight:
                                unread > 0 ? FontWeight.w600 : FontWeight.w400,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (room.isPinned) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.push_pin_rounded,
                            size: 14, color: AppTheme.accent),
                      ],
                      if (room.isClosedFor) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.lock_rounded,
                            size: 14, color: AppTheme.textDim),
                      ],
                      if (room.isMuted) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.volume_off_rounded,
                            size: 14, color: AppTheme.textDim),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Long-press action sheet ────────────────────────────────────────────────────

class _RoomActionSheet extends ConsumerWidget {
  const _RoomActionSheet({required this.room, required this.selfId});

  final Room room;
  final String selfId;

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

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      child: Container(
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 24,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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

// ── Avatar ────────────────────────────────────────────────────────────────────

class _RoomAvatar extends StatelessWidget {
  const _RoomAvatar({required this.room, required this.colors});
  final Room room;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
                colors: colors,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(room.isGroup ? 14 : 25),
          ),
          child: Center(
            child: Text(
              room.initials,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
          ),
        ),
        if (room.isClosedFor)
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: AppTheme.textDim,
                shape: BoxShape.circle,
                border: Border.all(color: AppTheme.bg, width: 2),
              ),
              child:
                  const Icon(Icons.lock_rounded, size: 7, color: Colors.white),
            ),
          ),
      ],
    );
  }
}

// ─── Skeleton ─────────────────────────────────────────────────────────────────

class _SkeletonTile extends StatelessWidget {
  const _SkeletonTile();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AppTheme.bgElevated,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 13,
                        decoration: BoxDecoration(
                            color: AppTheme.bgElevated,
                            borderRadius: BorderRadius.circular(7)),
                      ),
                    ),
                    const SizedBox(width: 40),
                    Container(
                        width: 30,
                        height: 11,
                        decoration: BoxDecoration(
                            color: AppTheme.bgElevated,
                            borderRadius: BorderRadius.circular(6))),
                  ],
                ),
                const SizedBox(height: 8),
                Container(
                    height: 11,
                    width: 100,
                    decoration: BoxDecoration(
                        color: AppTheme.bgElevated,
                        borderRadius: BorderRadius.circular(6))),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
