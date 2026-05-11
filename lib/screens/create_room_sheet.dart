import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/conversations/conversations_providers.dart';
import '../features/user/user_models.dart';
import '../features/user/user_providers.dart';
import '../theme/app_theme.dart';

/// Bottom sheet for creating a new group room.
///
/// Returns `({Room room, String selfId})` via [Navigator.pop] so the caller
/// can immediately push the MessageScreen after the sheet closes.
class CreateRoomSheet extends ConsumerStatefulWidget {
  const CreateRoomSheet({super.key});

  @override
  ConsumerState<CreateRoomSheet> createState() => _CreateRoomSheetState();
}

class _CreateRoomSheetState extends ConsumerState<CreateRoomSheet> {
  final _titleController = TextEditingController();
  final _memberSearchController = TextEditingController();
  String _memberQuery = '';
  String _privacy = 'public';
  final Set<String> _selectedIds = {};
  bool _creating = false;
  String? _titleError;

  // Cached list populated when companyUsersProvider resolves.
  List<CompanyUser> _allUsers = [];

  @override
  void dispose() {
    _titleController.dispose();
    _memberSearchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(companyUsersProvider);
    final me = ref.watch(meProvider).valueOrNull;

    // Keep _allUsers in sync for chip label resolution.
    if (usersAsync.hasValue) _allUsers = usersAsync.value!;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.92,
      child: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 20),
                  _sectionLabel('Room Name'),
                  const SizedBox(height: 8),
                  _buildRoomNameField(),
                  const SizedBox(height: 20),
                  _sectionLabel('Privacy'),
                  const SizedBox(height: 8),
                  _buildPrivacyRow(),
                  const SizedBox(height: 20),
                  _buildMembersHeader(),
                  const SizedBox(height: 8),
                  if (_selectedIds.isNotEmpty) ...[
                    _buildSelectedChips(),
                    const SizedBox(height: 12),
                  ],
                  _buildMemberSearch(),
                  const SizedBox(height: 8),
                  _buildMemberList(usersAsync, me?.id ?? ''),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
          _buildCreateButton(),
        ],
      ),
    );
  }

  // ── Header ─────────────────────────────────────────────────────────────────

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          // Drag handle + title stacked
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.border,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text('Create Room', style: AppTheme.headingSmall),
                const SizedBox(height: 2),
                Text('Set up a new group channel',
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

  // ── Section label ──────────────────────────────────────────────────────────

  Widget _sectionLabel(String text) {
    return Text(text, style: AppTheme.labelSmall);
  }

  // ── Room name ──────────────────────────────────────────────────────────────

  Widget _buildRoomNameField() {
    return TextField(
      controller: _titleController,
      onChanged: (_) => setState(() => _titleError = null),
      style: AppTheme.bodyMedium,
      textCapitalization: TextCapitalization.words,
      decoration: InputDecoration(
        hintText: 'e.g. Design Team',
        hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.textDim),
        errorText: _titleError,
        filled: true,
        fillColor: AppTheme.bgElevated,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppTheme.danger),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
    );
  }

  // ── Privacy ────────────────────────────────────────────────────────────────

  Widget _buildPrivacyRow() {
    return Row(
      children: [
        _PrivacyChip(
          icon: Icons.lock_open_rounded,
          label: 'Public',
          selected: _privacy == 'public',
          onTap: () => setState(() => _privacy = 'public'),
        ),
        const SizedBox(width: 12),
        _PrivacyChip(
          icon: Icons.lock_rounded,
          label: 'Private',
          selected: _privacy == 'private',
          onTap: () => setState(() => _privacy = 'private'),
        ),
      ],
    );
  }

  // ── Members header ─────────────────────────────────────────────────────────

  Widget _buildMembersHeader() {
    return Row(
      children: [
        _sectionLabel('Members'),
        const Spacer(),
        if (_selectedIds.isNotEmpty)
          Text(
            '${_selectedIds.length} selected',
            style: AppTheme.caption.copyWith(
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  // ── Selected chips ─────────────────────────────────────────────────────────

  Widget _buildSelectedChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _selectedIds.map((id) {
        final name = _allUsers
            .where((u) => u.id == id)
            .map((u) => u.fullName)
            .firstOrNull ?? id;
        return _MemberChip(
          label: name,
          onRemove: () => setState(() => _selectedIds.remove(id)),
        );
      }).toList(),
    );
  }

  // ── Member search ──────────────────────────────────────────────────────────

  Widget _buildMemberSearch() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: TextField(
        controller: _memberSearchController,
        onChanged: (v) => setState(() => _memberQuery = v),
        style: AppTheme.bodySmall,
        decoration: InputDecoration(
          hintText: 'Search members…',
          hintStyle: AppTheme.bodySmall.copyWith(color: AppTheme.textDim),
          prefixIcon: const Icon(Icons.search_rounded,
              color: AppTheme.textDim, size: 18),
          border: InputBorder.none,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        ),
      ),
    );
  }

  // ── Member list ────────────────────────────────────────────────────────────

  Widget _buildMemberList(AsyncValue<List<CompanyUser>> usersAsync, String selfId) {
    return usersAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 24),
        child: Center(
          child: CircularProgressIndicator(
              color: AppTheme.primary, strokeWidth: 2),
        ),
      ),
      error: (e, _) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppTheme.danger, size: 28),
              const SizedBox(height: 8),
              Text('Failed to load teammates',
                  style: AppTheme.bodySmall),
              TextButton(
                onPressed: () => ref.invalidate(companyUsersProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
      data: (users) {
        final filtered = users
            .where((u) => u.id != selfId)
            .where((u) =>
                _memberQuery.isEmpty || u.matches(_memberQuery))
            .toList();

        if (filtered.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Center(
              child: Text(
                _memberQuery.isEmpty
                    ? 'No teammates available'
                    : 'No results for "$_memberQuery"',
                style: AppTheme.bodySmall,
              ),
            ),
          );
        }

        return ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: filtered.length,
          itemBuilder: (_, i) {
            final u = filtered[i];
            final selected = _selectedIds.contains(u.id);
            return _CheckableUserTile(
              user: u,
              selected: selected,
              onChanged: (checked) => setState(() {
                if (checked) {
                  _selectedIds.add(u.id);
                } else {
                  _selectedIds.remove(u.id);
                }
              }),
            );
          },
        );
      },
    );
  }

  // ── Create button ──────────────────────────────────────────────────────────

  Widget _buildCreateButton() {
    return Container(
      padding: EdgeInsets.fromLTRB(
          20, 12, 20, MediaQuery.of(context).padding.bottom + 16),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: SizedBox(
        width: double.infinity,
        height: 50,
        child: ElevatedButton(
          onPressed: _creating ? null : _createRoom,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primary,
            disabledBackgroundColor: AppTheme.primary.withValues(alpha: 0.4),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14)),
            elevation: 0,
          ),
          child: _creating
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                      color: Colors.white, strokeWidth: 2),
                )
              : const Text(
                  'Create Room',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                ),
        ),
      ),
    );
  }

  // ── Create room action ─────────────────────────────────────────────────────

  Future<void> _createRoom() async {
    final me = ref.read(meProvider).valueOrNull;
    if (me == null) return;
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = 'Room name is required');
      return;
    }

    setState(() => _creating = true);
    try {
      final participants = <String>[me.id, ..._selectedIds];
      final room = await ConversationsService.createRoom(
        title: title,
        participants: participants,
        companyId: me.companyId,
        group: 'yes',
        privacy: _privacy,
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

// ── Privacy chip ──────────────────────────────────────────────────────────────

class _PrivacyChip extends StatelessWidget {
  const _PrivacyChip({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.10)
              : AppTheme.bgElevated,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? AppTheme.primary : AppTheme.textDim,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: AppTheme.bodySmall.copyWith(
                color: selected ? AppTheme.primary : AppTheme.textMuted,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Selected member chip ──────────────────────────────────────────────────────

class _MemberChip extends StatelessWidget {
  const _MemberChip({required this.label, required this.onRemove});

  final String label;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(10, 5, 6, 5),
      decoration: BoxDecoration(
        color: AppTheme.accentSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: AppTheme.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: AppTheme.caption.copyWith(
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: const Icon(Icons.close_rounded,
                size: 14, color: AppTheme.primary),
          ),
        ],
      ),
    );
  }
}

// ── Checkable user tile ───────────────────────────────────────────────────────

class _CheckableUserTile extends StatelessWidget {
  const _CheckableUserTile({
    required this.user,
    required this.selected,
    required this.onChanged,
  });

  final CompanyUser user;
  final bool selected;
  final ValueChanged<bool> onChanged;

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
      onTap: () => onChanged(!selected),
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(19),
              ),
              child: Center(
                child: Text(
                  user.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
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
                        .copyWith(fontWeight: FontWeight.w500),
                  ),
                  if (user.email != null && user.email!.isNotEmpty) ...[
                    const SizedBox(height: 1),
                    Text(user.email!, style: AppTheme.caption),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? AppTheme.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: selected ? AppTheme.primary : AppTheme.border,
                  width: 1.5,
                ),
              ),
              child: selected
                  ? const Icon(Icons.check_rounded,
                      size: 14, color: Colors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
