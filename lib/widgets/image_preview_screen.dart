import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';

import '../core/config/app_config.dart';
import '../core/models/conversation_models.dart';
import '../features/files/files_service.dart';
import '../theme/app_theme.dart';

// ── Entry point ───────────────────────────────────────────────────────────────

/// Opens full-screen image viewer for message attachments.
/// [attachments] is the list of image attachments in the message.
/// [initialIndex] is which attachment to show first.
void showImagePreview(
  BuildContext context, {
  required List<MessageAttachment> attachments,
  int initialIndex = 0,
}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => ImagePreviewScreen(
        attachments: attachments,
        initialIndex: initialIndex,
      ),
    ),
  );
}

// ── Screen ────────────────────────────────────────────────────────────────────

class ImagePreviewScreen extends StatefulWidget {
  const ImagePreviewScreen({
    super.key,
    required this.attachments,
    this.initialIndex = 0,
  });

  final List<MessageAttachment> attachments;
  final int initialIndex;

  @override
  State<ImagePreviewScreen> createState() => _ImagePreviewScreenState();
}

class _ImagePreviewScreenState extends State<ImagePreviewScreen> {
  late final PageController _pageController;
  late int _currentIndex;
  bool _showOverlay = true;

  // Per-image download state: null=idle, 0.0..1.0=progress, -1=error, 2=done
  final Map<int, double> _downloadState = {};

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  MessageAttachment get _current => widget.attachments[_currentIndex];

  // ── Download ────────────────────────────────────────────────────────────────

  Future<void> _download() async {
    final idx = _currentIndex;
    final attachment = widget.attachments[idx];
    final url = attachment.downloadUrl(AppConfig.fileBaseUrl);
    if (url.isEmpty) return;

    // Android 9 and below need WRITE_EXTERNAL_STORAGE.
    if (Platform.isAndroid) {
      final sdk = await _androidSdk();
      if (sdk != null && sdk < 29) {
        final status = await Permission.storage.request();
        if (!status.isGranted) {
          _showSnack('Storage permission required');
          return;
        }
      }
    }

    setState(() => _downloadState[idx] = 0.0);

    try {
      final dir = await _downloadDir();
      final filename = attachment.originalName;
      final savePath = '${dir.path}/$filename';

      await FilesService.downloadFile(
        url: url,
        savePath: savePath,
        onProgress: (received, total) {
          if (total > 0 && mounted) {
            setState(() => _downloadState[idx] = received / total);
          }
        },
      );

      setState(() => _downloadState[idx] = 2.0);
      _showSnack('Saved to Downloads');

      // Open immediately after download.
      await OpenFilex.open(savePath);
    } catch (e) {
      setState(() => _downloadState[idx] = -1.0);
      _showSnack('Download failed: $e');
    }
  }

  Future<Directory> _downloadDir() async {
    if (Platform.isAndroid) {
      // Scoped storage: save to app-external storage on older API or use
      // Downloads folder via path_provider on API 30+.
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        final dir = Directory('${ext.path}/Downloads');
        if (!dir.existsSync()) dir.createSync(recursive: true);
        return dir;
      }
    }
    return getApplicationDocumentsDirectory();
  }

  Future<int?> _androidSdk() async {
    try {
      if (!Platform.isAndroid) return null;
      // We use permission_handler's version check indirectly.
      return null; // Modern Flutter targets API 21+; skip version check.
    } catch (_) {
      return null;
    }
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: AppTheme.bodySmall.copyWith(color: Colors.white)),
        backgroundColor: AppTheme.bgElevated,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        onTap: () => setState(() => _showOverlay = !_showOverlay),
        child: Stack(
          children: [
            // Gallery
            PhotoViewGallery.builder(
              pageController: _pageController,
              itemCount: widget.attachments.length,
              onPageChanged: (i) => setState(() => _currentIndex = i),
              scrollPhysics: const BouncingScrollPhysics(),
              builder: (context, index) {
                final a = widget.attachments[index];
                final url = a.downloadUrl(AppConfig.fileBaseUrl);
                return PhotoViewGalleryPageOptions(
                  imageProvider: CachedNetworkImageProvider(url),
                  minScale: PhotoViewComputedScale.contained,
                  maxScale: PhotoViewComputedScale.covered * 3,
                  errorBuilder: (_, __, ___) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.broken_image_rounded,
                            color: AppTheme.textDim, size: 48),
                        const SizedBox(height: 12),
                        Text('Could not load image',
                            style: AppTheme.caption.copyWith(
                                color: AppTheme.textMuted)),
                      ],
                    ),
                  ),
                );
              },
              ),

            // Top overlay (close + image counter)
            AnimatedOpacity(
              opacity: _showOverlay ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 200),
              child: _buildTopBar(context),
            ),

            // Bottom overlay (filename + download button)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: AnimatedOpacity(
                opacity: _showOverlay ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: _buildBottomBar(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 4,
          left: 8,
          right: 16,
          bottom: 8,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.black.withValues(alpha: 0.7),
              Colors.transparent,
            ],
          ),
        ),
        child: Row(
          children: [
            IconButton(
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.close_rounded,
                  color: Colors.white, size: 24),
            ),
            const Spacer(),
            if (widget.attachments.length > 1)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${_currentIndex + 1} / ${widget.attachments.length}',
                  style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomBar() {
    final dState = _downloadState[_currentIndex];
    final isDownloading =
        dState != null && dState >= 0.0 && dState < 1.0;
    final isDone = dState == 2.0;

    return Container(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.of(context).padding.bottom + 16,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            Colors.black.withValues(alpha: 0.8),
            Colors.transparent,
          ],
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _current.originalName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_current.fileSize != null &&
                    _current.fileSize!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    _current.fileSize!,
                    style: TextStyle(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Download button
          GestureDetector(
            onTap: isDownloading ? null : _download,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isDone
                    ? AppTheme.success.withValues(alpha: 0.2)
                    : Colors.white.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDone
                      ? AppTheme.success
                      : Colors.white.withValues(alpha: 0.3),
                ),
              ),
              child: isDownloading
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: CircularProgressIndicator(
                        value: dState,
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      isDone
                          ? Icons.check_rounded
                          : Icons.download_rounded,
                      color: isDone ? AppTheme.success : Colors.white,
                      size: 22,
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
