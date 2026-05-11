import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/conversations/conversations_providers.dart';
import '../features/user/user_models.dart';
import '../features/user/user_providers.dart';
import '../theme/app_theme.dart';

/// Bottom sheet for starting a Direct Message conversation.
///
/// Returns `({Room room, String selfId})` via [Navigator.pop] so the caller
/// can immediately push the MessageScreen after the sheet closes.
class DirectMessageSheet extends ConsumerStatefulWidget {
  const DirectMessageSheet({super.key});

  @override
  ConsumerState<DirectMessageSheet> createState() =>
      _DirectMessageSheetState();
}

class _DirectMessageSheetState extends ConsumerState<DirectMessageSheet> {
  final _searchController = TextEditingController();
  String _query = '';
  bool _creating = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(companyUsersProvider);
    final meValue = ref.watch(meProvider).valueOrNull;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.85,
      child: Column(
        children: [
          _buildDragHandle(),
          _buildHeader(),
          _buildSearchBar(),
          Expanded(
            child: usersAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(
                    color: AppTheme.primary, strokeWidth: 2),
              ),
              error: (e, _) => Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: AppTheme.danger, size: 32),
                    const SizedBox(height: 8),
                    Text('Failed to load teammates',
                        style: AppTheme.bodySmall),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: () =>
                          ref.invalidate(companyUsersProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (users) {
                final selfId = meValue?.id ?? '';
                final filtered = users
                    .where((u) => u.id != selfId)
                    .where((u) =>
                        _query.isEmpty || u.matches(_query))
                    .toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          _query.isEmpty
                              ? Icons.people_outline_rounded
                              : Icons.search_off_rounded,
                          color: AppTheme.textDim,
                          size: 40,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          _query.isEmpty
                              ? 'No teammates found'
                              : 'No results for "$_query"',
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  itemCount: filtered.length,
                  itemBuilder: (_, i) => _UserTile(
                    user: filtered[i],
                    loading: _creating,
                    onTap: () => _startDM(filtered[i]),
                  ),
                );
              },
            ),
          ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }

  Widget _buildDragHandle() {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Center(
        child: Container(
          width: 36,
          height: 4,
          decoration: BoxDecoration(
            color: AppTheme.border,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('New Direct Message', style: AppTheme.headingSmall),
                const SizedBox(height: 2),
                Text('Choose a teammate to chat with',
                    style: AppTheme.caption),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            icon: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppTheme.bgElevated,
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: AppTheme.border),
              ),
              child: const Icon(Icons.close_rounded,
                  size: 16, color: AppTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: AppTheme.bgElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: TextField(
          controller: _searchController,
          onChanged: (v) => setState(() => _query = v),
          style: AppTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: 'Search by name or email…',
            hintStyle:
                AppTheme.bodyMedium.copyWith(color: AppTheme.textDim),
            prefixIcon: const Icon(Icons.search_rounded,
                color: AppTheme.textDim, size: 20),
            border: InputBorder.none,
            contentPadding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 12),
          ),
        ),
      ),
    );
  }

  Future<void> _startDM(CompanyUser user) async {
    if (_creating) return;
    final me = ref.read(meProvider).valueOrNull;
    if (me == null) return;

    // Check local room cache first — avoids creating a duplicate DM.
    final rooms = ref.read(sortedRoomsProvider).valueOrNull;
    if (rooms != null) {
      for (final r in rooms) {
        if (!r.isGroup &&
            r.participants.contains(user.id) &&
            r.participants.contains(me.id)) {
          if (mounted) {
            Navigator.of(context).pop((room: r, selfId: me.id));
          }
          return;
        }
      }
    }

    setState(() => _creating = true);
    try {
      final room = await ConversationsService.createRoom(
        title: user.fullName,
        participants: [me.id, user.id],
        companyId: me.companyId,
        group: 'no',
        selfId: me.id,
      );
      if (mounted) {
        Navigator.of(context).pop((room: room, selfId: me.id));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
              style: AppTheme.bodySmall.copyWith(color: Colors.white),
            ),
            backgroundColor: AppTheme.danger,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }
}

// ── User tile ─────────────────────────────────────────────────────────────────

class _UserTile extends StatelessWidget {
  const _UserTile({
    required this.user,
    required this.onTap,
    this.loading = false,
  });

  final CompanyUser user;
  final VoidCallback onTap;
  final bool loading;

  static const List<List<Color>> _palettes = [
    [Color(0xFF6366F1), Color(0xFF8B5CF6)],
    [Color(0xFFEC4899), Color(0xFFF43F5E)],
    [Color(0xFF3B82F6), Color(0xFF06B6D4)],
    [Color(0xFF10B981), Color(0xFF059669)],
    [Color(0xFFF59E0B), Color(0xFFEF4444)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _palettes[user.id.hashCode.abs() % _palettes.length];
    return InkWell(
      onTap: loading ? null : onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(22),
              ),
              child: Center(
                child: Text(
                  user.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.fullName,
                    style: AppTheme.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600),
                  ),
                  if (user.email != null && user.email!.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(user.email!, style: AppTheme.caption),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: AppTheme.accentSoft,
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(Icons.arrow_forward_ios_rounded,
                  size: 13, color: AppTheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}
