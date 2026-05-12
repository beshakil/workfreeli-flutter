import 'package:flutter/material.dart';

import '../../features/files/file_models.dart';
import '../../theme/app_theme.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

/// Shows a centered modal dialog displaying all tags for a file.
Future<void> showFileTagsModal(
  BuildContext context, {
  required List<TagDetails> tags,
}) {
  return showDialog(
    context: context,
    builder: (ctx) => FileTagsModal(tags: tags),
  );
}

// ── Modal widget ──────────────────────────────────────────────────────────────

class FileTagsModal extends StatelessWidget {
  const FileTagsModal({super.key, required this.tags});

  final List<TagDetails> tags;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 400),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: Row(
                children: [
                  Icon(Icons.label_rounded, size: 20, color: AppTheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'File Tags',
                      style: AppTheme.headingSmall,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded,
                        color: AppTheme.textMuted, size: 20),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTheme.border),
            // Tags list
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.all(16),
                itemCount: tags.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final tag = tags[index];
                  return _TagChip(tag: tag);
                },
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

// ── Tag chip widget ───────────────────────────────────────────────────────────

class _TagChip extends StatelessWidget {
  const _TagChip({required this.tag});

  final TagDetails tag;

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(tag.tagColor) ?? AppTheme.primary;
    final bgColor = color.withValues(alpha: 0.12);
    final borderColor = color.withValues(alpha: 0.4);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: borderColor, width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Color indicator
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          // Tag title
          Text(
            tag.title,
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          if (tag.tagType == 'private') ...[
            const SizedBox(width: 6),
            Icon(Icons.lock_rounded, size: 12, color: color),
          ],
        ],
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

// ── Tag pills row (for attachment cards) ──────────────────────────────────────

/// Displays tags as pills with a maximum visible count.
/// Shows "+N" when there are more tags than the max.
class TagPillsRow extends StatelessWidget {
  const TagPillsRow({
    super.key,
    required this.tags,
    this.maxVisible = 3,
  });

  final List<TagDetails> tags;
  final int maxVisible;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) return const SizedBox.shrink();

    final visibleTags = tags.take(maxVisible).toList();
    final remainingCount = tags.length - maxVisible;
    final hasMore = remainingCount > 0;

    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        ...visibleTags.map((tag) => _TagPill(tag: tag)),
        if (hasMore)
          GestureDetector(
            onTap: () => showFileTagsModal(context, tags: tags),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.bgElevated,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppTheme.border),
              ),
              child: Text(
                '+$remainingCount',
                style: AppTheme.caption.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Single tag pill ───────────────────────────────────────────────────────────

class _TagPill extends StatelessWidget {
  const _TagPill({required this.tag});

  final TagDetails tag;

  @override
  Widget build(BuildContext context) {
    final color = _parseColor(tag.tagColor) ?? AppTheme.primary;
    final bgColor = color.withValues(alpha: 0.12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Color dot
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 6),
          // Tag title (truncated if too long)
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 100),
            child: Text(
              tag.title,
              style: AppTheme.caption.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
                fontSize: 11,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
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
