import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';

/// Bottom sheet modal for file/image long-press actions.
///
/// Displays file preview, metadata, and actions
/// (View, Add to Starred, Add a tag, Download, Forward, Share, Delete).
class ChatFileActionModal extends ConsumerWidget {
  /// The file name (e.g., "eid-offer-text-in-bangla-free-vector.jpg")
  final String fileName;

  /// The file size (e.g., "31 KB")
  final String fileSize;

  /// The upload time (e.g., "Today", "Yesterday", "2 hours ago")
  final String uploadTime;

  /// Whether this is an image file (for preview thumbnail)
  final bool isImage;

  /// The file URL (for image preview)
  final String? fileUrl;

  const ChatFileActionModal({
    super.key,
    required this.fileName,
    required this.fileSize,
    required this.uploadTime,
    this.isImage = false,
    this.fileUrl,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar indicator
              Container(
                margin: const EdgeInsets.only(bottom: 20, top: 16),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // File header section
              _buildFileHeader(context),

              const SizedBox(height: 20),

              // Divider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Divider(
                  color: AppTheme.border,
                  height: 1,
                ),
              ),

              const SizedBox(height: 8),

              // Action menu items
              _buildActionList(context, ref),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFileHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Preview thumbnail (for images) or file icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: isImage ? Colors.transparent : AppTheme.bgElevated,
              borderRadius: BorderRadius.circular(12),
              border: isImage ? null : Border.all(color: AppTheme.border),
            ),
            child: isImage
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: fileUrl != null && fileUrl!.isNotEmpty
                        ? Image.network(
                            fileUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => _defaultFileIcon(),
                          )
                        : _defaultFileIcon(),
                  )
                : _defaultFileIcon(),
          ),
          const SizedBox(height: 12),

          // File name
          Text(
            fileName,
            style: AppTheme.bodyMedium.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 6),

          // Metadata (file size + upload time)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.insert_drive_file_rounded,
                size: 12,
                color: AppTheme.textDim,
              ),
              const SizedBox(width: 4),
              Text(
                fileSize,
                style: AppTheme.caption.copyWith(
                  color: AppTheme.textDim,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Text(
                  '•',
                  style: AppTheme.caption.copyWith(color: AppTheme.textDim),
                ),
              ),
              Text(
                'Uploaded: $uploadTime',
                style: AppTheme.caption.copyWith(
                  color: AppTheme.textDim,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _defaultFileIcon() {
    return Center(
      child: Icon(
        Icons.insert_drive_file_rounded,
        size: 36,
        color: AppTheme.primary,
      ),
    );
  }

  Widget _buildActionList(BuildContext context, WidgetRef ref) {
    final actions = <_FileActionItem>[
      _FileActionItem(
        icon: Icons.visibility_rounded,
        label: 'View',
        isDestructive: false,
      ),
      _FileActionItem(
        icon: Icons.star_border_rounded,
        label: 'Add to Starred',
        isDestructive: false,
      ),
      _FileActionItem(
        icon: Icons.label_outline_rounded,
        label: 'Add a tag',
        isDestructive: false,
      ),
      _FileActionItem(
        icon: Icons.download_rounded,
        label: 'Download',
        isDestructive: false,
      ),
      _FileActionItem(
        icon: Icons.send_rounded,
        label: 'Forward',
        isDestructive: false,
      ),
      _FileActionItem(
        icon: Icons.share_rounded,
        label: 'Share',
        isDestructive: false,
      ),
      _FileActionItem(
        icon: Icons.delete_rounded,
        label: 'Delete',
        isDestructive: true,
      ),
    ];

    return Column(
      children: [
        for (int i = 0; i < actions.length; i++) ...[
          _FileActionTile(
            icon: actions[i].icon,
            label: actions[i].label,
            isDestructive: actions[i].isDestructive,
            onTap: () => _handleAction(context, ref, i, actions[i]),
          ),
          if (i < actions.length - 1) const SizedBox(height: 4),
        ],
      ],
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    WidgetRef ref,
    int index,
    _FileActionItem action,
  ) async {
    Navigator.of(context).pop();

    switch (action.label) {
      case 'View':
        // TODO: Implement view logic
        break;
      case 'Add to Starred':
        // TODO: Implement starred logic
        break;
      case 'Add a tag':
        // TODO: Implement tag logic
        break;
      case 'Download':
        // TODO: Implement download logic
        break;
      case 'Forward':
        // TODO: Implement forward logic
        break;
      case 'Share':
        // TODO: Implement share logic
        break;
      case 'Delete':
        // TODO: Implement delete logic
        break;
    }
  }
}

// ── File action item model ───────────────────────────────────────────────────

class _FileActionItem {
  final IconData icon;
  final String label;
  final bool isDestructive;
  const _FileActionItem({
    required this.icon,
    required this.label,
    required this.isDestructive,
  });
}

// ── File action tile widget ──────────────────────────────────────────────────

class _FileActionTile extends StatelessWidget {
  const _FileActionTile({
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
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
            Expanded(
              child: Text(
                label,
                style: AppTheme.bodyLarge.copyWith(
                  color: color,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
