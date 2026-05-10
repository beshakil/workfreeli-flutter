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
    final meAsync = ref.watch(meProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          _buildHeader(context, meAsync),
          _buildSearchBar(),
          Expanded(
            child: roomsAsync.when(
              loading: () => _buildSkeletons(),
              error: (err, _) => _buildError(
                err.toString().replaceFirst('Exception: ', ''),
                onRetry: () => ref.invalidate(roomsProvider),
              ),
              data: (rooms) {
                final filtered = _searchQuery.isEmpty
                    ? rooms
                    : rooms
                        .where((r) => r.title
                            .toLowerCase()
                            .contains(_searchQuery.toLowerCase()))
                        .toList();

                if (filtered.isEmpty) {
                  return _searchQuery.isNotEmpty
                      ? _buildNoResults()
                      : _buildEmpty();
                }

                final selfId = meAsync.valueOrNull?.id ?? '';
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

  Widget _buildHeader(BuildContext context, AsyncValue meAsync) {
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 12,
        left: 20,
        right: 20,
        bottom: 14,
      ),
      color: AppTheme.bgCard,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Messages', style: AppTheme.headingMedium),
                const SizedBox(height: 2),
                meAsync.maybeWhen(
                  data: (user) => Text(
                    user.companyName,
                    style: AppTheme.caption.copyWith(color: AppTheme.accent),
                  ),
                  orElse: () => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
          _HeaderBtn(icon: Icons.edit_square, onTap: () {}),
        ],
      ),
    );
  }

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
            Text(message,
                style: AppTheme.caption, textAlign: TextAlign.center),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Retry'),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 24, vertical: 10),
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
              style:
                  AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text('Your conversations will appear here',
              style: AppTheme.caption),
        ],
      ),
    );
  }

  Widget _buildNoResults() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.search_off_rounded,
              size: 48, color: AppTheme.textDim),
          const SizedBox(height: 16),
          Text('No results for "$_searchQuery"',
              style:
                  AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ── Header button ─────────────────────────────────────────────────────────────

class _HeaderBtn extends StatelessWidget {
  const _HeaderBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: AppTheme.bgElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppTheme.border),
        ),
        child: Icon(icon, color: AppTheme.textMuted, size: 18),
      ),
    );
  }
}

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
                        border: Border.all(
                            color: AppTheme.bg, width: 1.5),
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
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            if (room.isPinned) ...[
                              Icon(Icons.push_pin_rounded,
                                  size: 12, color: AppTheme.accent),
                              const SizedBox(width: 4),
                            ],
                            Expanded(
                              child: Text(
                                room.title,
                                style: AppTheme.bodyMedium.copyWith(
                                  fontWeight: unread > 0
                                      ? FontWeight.w700
                                      : FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (room.formattedTime.isNotEmpty) ...[
                        const SizedBox(width: 8),
                        Text(
                          room.formattedTime,
                          style: AppTheme.caption.copyWith(
                            color: unread > 0
                                ? AppTheme.primary
                                : AppTheme.textDim,
                            fontWeight: unread > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(
                        room.isGroup
                            ? Icons.group_rounded
                            : Icons.person_rounded,
                        size: 13,
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
                            color: unread > 0
                                ? AppTheme.textMuted
                                : AppTheme.textDim,
                            fontWeight: unread > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (room.isMuted) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.volume_off_rounded,
                            size: 13, color: AppTheme.textDim),
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
            borderRadius:
                BorderRadius.circular(room.isGroup ? 14 : 25),
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
