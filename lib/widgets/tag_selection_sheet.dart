import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/files/file_models.dart';
import '../features/files/files_providers.dart';
import '../theme/app_theme.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

/// Shows a bottom sheet for selecting tags to attach to an uploaded file.
///
/// Returns the list of selected [TagDetails], or null if the user dismissed.
/// [conversationId] filters tags to the current conversation.
Future<List<TagDetails>?> showTagSelectionSheet(
  BuildContext context, {
  String? conversationId,
  List<TagDetails> preSelected = const [],
}) {
  return showModalBottomSheet<List<TagDetails>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => TagSelectionSheet(
      conversationId: conversationId,
      preSelected: preSelected,
    ),
  );
}

// ── Sheet widget ──────────────────────────────────────────────────────────────

class TagSelectionSheet extends ConsumerStatefulWidget {
  const TagSelectionSheet({
    super.key,
    this.conversationId,
    this.preSelected = const [],
  });

  final String? conversationId;
  final List<TagDetails> preSelected;

  @override
  ConsumerState<TagSelectionSheet> createState() => _TagSelectionSheetState();
}

class _TagSelectionSheetState extends ConsumerState<TagSelectionSheet> {
  final _searchCtrl = TextEditingController();
  String _query = '';
  final Set<String> _selected = {}; // tag_id set

  @override
  void initState() {
    super.initState();
    _selected.addAll(widget.preSelected.map((t) => t.tagId));
    // Load tags on open.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref
          .read(tagsNotifierProvider.notifier)
          .load(conversationId: widget.conversationId);
    });
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _toggleTag(String tagId) {
    setState(() {
      if (_selected.contains(tagId)) {
        _selected.remove(tagId);
      } else {
        _selected.add(tagId);
      }
    });
  }

  void _confirm(List<TagDetails> allTags) {
    final result = allTags.where((t) => _selected.contains(t.tagId)).toList();
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) {
    final tagsState = ref.watch(tagsNotifierProvider);
    final allTags = tagsState.tags;

    final filtered = _query.isEmpty
        ? allTags
        : allTags
            .where((t) =>
                t.title.toLowerCase().contains(_query.toLowerCase()))
            .toList();

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      builder: (context, scrollCtrl) {
        return Container(
          decoration: const BoxDecoration(
            color: AppTheme.bgCard,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              _buildHandle(),
              _buildHeader(allTags),
              _buildSearchBar(),
              if (tagsState.isLoading)
                const Expanded(
                  child: Center(
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.primary),
                  ),
                )
              else if (tagsState.error != null)
                Expanded(child: _buildError(tagsState.error!))
              else if (filtered.isEmpty)
                Expanded(child: _buildEmpty(_query))
              else
                Expanded(
                  child: ListView.builder(
                    controller: scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    itemCount: filtered.length,
                    itemBuilder: (_, i) => _TagRow(
                      tag: filtered[i],
                      selected: _selected.contains(filtered[i].tagId),
                      onToggle: () => _toggleTag(filtered[i].tagId),
                    ),
                  ),
                ),
              _buildFooter(allTags),
            ],
          ),
        );
      },
    );
  }

  Widget _buildHandle() => Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppTheme.border,
          borderRadius: BorderRadius.circular(2),
        ),
      );

  Widget _buildHeader(List<TagDetails> allTags) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Select Tags', style: AppTheme.headingSmall),
                const SizedBox(height: 2),
                Text(
                  '${_selected.length} selected',
                  style:
                      AppTheme.caption.copyWith(color: AppTheme.accent),
                ),
              ],
            ),
          ),
          if (_selected.isNotEmpty)
            TextButton(
              onPressed: () => setState(() => _selected.clear()),
              child: Text(
                'Clear all',
                style: AppTheme.bodySmall
                    .copyWith(color: AppTheme.danger),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: AppTheme.bgElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: TextField(
          controller: _searchCtrl,
          style: AppTheme.bodyMedium,
          onChanged: (v) => setState(() => _query = v),
          decoration: InputDecoration(
            hintText: 'Search tags…',
            hintStyle:
                AppTheme.bodyMedium.copyWith(color: AppTheme.textDim),
            prefixIcon: const Icon(Icons.search_rounded,
                color: AppTheme.textDim, size: 18),
            suffixIcon: _query.isNotEmpty
                ? GestureDetector(
                    onTap: () {
                      _searchCtrl.clear();
                      setState(() => _query = '');
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

  Widget _buildFooter(List<TagDetails> allTags) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(<TagDetails>[]),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.textMuted,
                side: const BorderSide(color: AppTheme.border),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Skip'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton(
              onPressed: () => _confirm(allTags),
              style: FilledButton.styleFrom(
                backgroundColor: AppTheme.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: Text(
                _selected.isEmpty
                    ? 'Send without tags'
                    : 'Apply ${_selected.length} tag${_selected.length == 1 ? '' : 's'}',
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError(String message) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.label_off_rounded,
                  size: 40, color: AppTheme.textDim),
              const SizedBox(height: 12),
              Text(message,
                  style: AppTheme.caption, textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  Widget _buildEmpty(String query) => Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.label_off_rounded,
                  size: 40, color: AppTheme.textDim),
              const SizedBox(height: 12),
              Text(
                query.isNotEmpty
                    ? 'No tags matching "$query"'
                    : 'No tags available',
                style: AppTheme.caption,
              ),
            ],
          ),
        ),
      );
}

// ── Single tag row ────────────────────────────────────────────────────────────

class _TagRow extends StatelessWidget {
  const _TagRow({
    required this.tag,
    required this.selected,
    required this.onToggle,
  });

  final TagDetails tag;
  final bool selected;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(tag.tagColor) ?? AppTheme.primary;
    final isPrivate = tag.tagType == 'private';

    return GestureDetector(
      onTap: onToggle,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: selected
              ? color.withValues(alpha: 0.12)
              : AppTheme.bgElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? color.withValues(alpha: 0.5)
                : AppTheme.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            // Color dot
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
            // Title + type badge
            Expanded(
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      tag.title,
                      style: AppTheme.bodyMedium.copyWith(
                        fontWeight: selected
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                  ),
                  if (isPrivate) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppTheme.textDim.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Private',
                        style: AppTheme.caption.copyWith(
                            color: AppTheme.textDim, fontSize: 10),
                      ),
                    ),
                  ],
                  if (tag.useCount != null && tag.useCount! > 0) ...[
                    const SizedBox(width: 8),
                    Text(
                      '×${tag.useCount}',
                      style: AppTheme.caption,
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Checkbox
            AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: selected ? color : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: selected ? color : AppTheme.border,
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

  static Color? _parseColor(String? hex) {
    if (hex == null || hex.isEmpty) return null;
    final sanitized = hex.replaceFirst('#', '').trim();
    if (sanitized.length == 6) {
      return Color(int.tryParse('FF$sanitized', radix: 16) ?? 0);
    }
    if (sanitized.length == 8) {
      return Color(int.tryParse(sanitized, radix: 16) ?? 0);
    }
    return null;
  }
}
