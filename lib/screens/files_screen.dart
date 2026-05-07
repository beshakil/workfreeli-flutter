import 'dart:io';

import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../core/config/app_config.dart';
import '../features/conversations/conversations_providers.dart';
import '../features/files/file_models.dart';
import '../features/files/files_providers.dart';
import '../features/files/files_service.dart';
import '../features/user/user_providers.dart';
import '../theme/app_theme.dart';

// ── Filter chip definitions ───────────────────────────────────────────────────

class _Filter {
  final String
      key; // backend value ('all', 'image', 'video', 'audio', 'voice', 'docs')
  final String label; // display label
  final IconData icon;
  const _Filter(this.key, this.label, this.icon);
}

const _filters = [
  _Filter('all', 'Total', Icons.folder_rounded),
  _Filter('docs', 'Docs', Icons.description_rounded),
  _Filter('image', 'Images', Icons.image_rounded),
  _Filter('voice', 'Voice', Icons.mic_rounded),
  _Filter('audio', 'Audio', Icons.headphones_rounded),
  _Filter('video', 'Video', Icons.videocam_rounded),
];

// ── Main screen ───────────────────────────────────────────────────────────────

class FilesScreen extends ConsumerStatefulWidget {
  const FilesScreen({super.key});

  @override
  ConsumerState<FilesScreen> createState() => _FilesScreenState();
}

class _FilesScreenState extends ConsumerState<FilesScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChange);
  }

  void _onTabChange() {
    if (_tabController.indexIsChanging) return;

    switch (_tabController.index) {
      case 0:
        // Files tab
        ref.read(filesNotifierProvider.notifier).setTab('files');
        break;
      case 1:
        // Links tab - trigger reload of links
        ref.read(linksNotifierProvider.notifier).load();
        break;
      case 2:
        // Tags tab - already loads in initState of _TagsTab
        break;
    }
  }

  @override
  void dispose() {
    _tabController
      ..removeListener(_onTabChange)
      ..dispose();
    _searchController.dispose();
    super.dispose();
  }

  // ── Upload ──────────────────────────────────────────────────────────────────

  Future<void> _pickAndUpload() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;

    final path = result.files.single.path;
    if (path == null) return;

    final user = ref.read(meProvider).value;
    if (user == null) {
      _snack('User not loaded — please wait.', isError: true);
      return;
    }

    final ok = await ref
        .read(uploadNotifierProvider.notifier)
        .upload(file: File(path), userEmail: user.email);

    if (!mounted) return;
    ok
        ? _snack('Uploaded successfully.')
        : _snack(ref.read(uploadNotifierProvider).error ?? 'Upload failed.',
            isError: true);
  }

  // ── Download ────────────────────────────────────────────────────────────────

  Future<void> _openFile(SharedFile file) async {
    final url = file.downloadUrl(AppConfig.fileBaseUrl);
    if (url.isEmpty) {
      _snack('No URL available.', isError: true);
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri != null && await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
      return;
    }

    try {
      _snack('Downloading ${file.originalName}…');
      final dir = await getTemporaryDirectory();
      final savePath = '${dir.path}/${file.originalName}';
      await FilesService.downloadFile(url: url, savePath: savePath);
      if (!mounted) return;
      _snack('Saved to device.');
      final fileUri = Uri.file(savePath);
      if (await canLaunchUrl(fileUri)) await launchUrl(fileUri);
    } on DioException catch (e) {
      if (mounted) _snack(e.message ?? 'Download failed.', isError: true);
    }
  }

  void _snack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content:
          Text(msg, style: AppTheme.bodySmall.copyWith(color: Colors.white)),
      backgroundColor: isError ? AppTheme.danger : AppTheme.success,
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 3),
    ));
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final uploadState = ref.watch(uploadNotifierProvider);

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          _buildHeader(context),
          _buildTabBar(),
          if (uploadState.isUploading) _buildUploadBar(uploadState.progress),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _FilesTab(
                  searchQuery: _searchQuery,
                  onOpen: _openFile,
                ),
                const _LinksTab(),
                const _TagsTab(),
              ],
            ),
          ),
        ],
      ),
      floatingActionButton: _UploadFab(
        onTap: uploadState.isUploading ? null : _pickAndUpload,
      ),
    );
  }

  // ── Header ──────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final listState = ref.watch(filesNotifierProvider);

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 8,
        left: 20,
        right: 12,
        bottom: 12,
      ),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.folder_rounded, color: AppTheme.primary, size: 20),
              const SizedBox(width: 8),
              Text('FileHub', style: AppTheme.headingMedium),
              const SizedBox(width: 6),
              Text('| Files',
                  style:
                      AppTheme.bodyMedium.copyWith(color: AppTheme.textMuted)),
              const Spacer(),
              // Refresh
              GestureDetector(
                onTap: listState.isLoading
                    ? null
                    : () => ref.read(filesNotifierProvider.notifier).load(),
                child: Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: AppTheme.bgElevated,
                    borderRadius: BorderRadius.circular(9),
                    border: Border.all(color: AppTheme.border),
                  ),
                  child: listState.isLoading
                      ? const Padding(
                          padding: EdgeInsets.all(7),
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: AppTheme.primary),
                        )
                      : const Icon(Icons.refresh_rounded,
                          color: AppTheme.textMuted, size: 17),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Search bar
          Container(
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.bgElevated,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppTheme.border),
            ),
            child: Row(
              children: [
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: Icon(Icons.search_rounded,
                      color: AppTheme.textDim, size: 18),
                ),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    style: AppTheme.bodySmall,
                    onChanged: (v) =>
                        setState(() => _searchQuery = v.toLowerCase()),
                    decoration: InputDecoration(
                      hintText: 'Search files…',
                      hintStyle:
                          AppTheme.bodySmall.copyWith(color: AppTheme.textDim),
                      border: InputBorder.none,
                      isDense: true,
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  GestureDetector(
                    onTap: () {
                      _searchController.clear();
                      setState(() => _searchQuery = '');
                    },
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(Icons.close_rounded,
                          color: AppTheme.textDim, size: 16),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Tab bar ─────────────────────────────────────────────────────────────────

  Widget _buildTabBar() {
    return Container(
      color: AppTheme.bgCard,
      child: TabBar(
        controller: _tabController,
        labelColor: AppTheme.primary,
        unselectedLabelColor: AppTheme.textMuted,
        labelStyle: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600),
        unselectedLabelStyle: AppTheme.bodySmall,
        indicatorColor: AppTheme.primary,
        indicatorWeight: 2,
        tabs: const [
          Tab(text: 'Files'),
          Tab(text: 'Links'),
          Tab(text: 'Tags'),
        ],
      ),
    );
  }

  // ── Upload progress bar ─────────────────────────────────────────────────────

  Widget _buildUploadBar(double progress) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.primary.withValues(alpha: 0.08),
      child: Row(
        children: [
          const Icon(Icons.upload_rounded, color: AppTheme.primary, size: 15),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Uploading…',
                    style: AppTheme.caption.copyWith(color: AppTheme.primary)),
                const SizedBox(height: 3),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    backgroundColor: AppTheme.bgElevated,
                    valueColor: const AlwaysStoppedAnimation(AppTheme.primary),
                    minHeight: 3,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text('${(progress * 100).toInt()}%',
              style: AppTheme.caption.copyWith(color: AppTheme.primary)),
        ],
      ),
    );
  }
}

// ── Files / Links tab content ─────────────────────────────────────────────────

class _FilesTab extends ConsumerStatefulWidget {
  const _FilesTab({required this.searchQuery, required this.onOpen});

  final String searchQuery;
  final void Function(SharedFile) onOpen;

  @override
  ConsumerState<_FilesTab> createState() => _FilesTabState();
}

class _FilesTabState extends ConsumerState<_FilesTab> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !ref.read(filesNotifierProvider).isLoadingMore) {
      ref.read(filesNotifierProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final listState = ref.watch(filesNotifierProvider);
    final summary = listState.summary;
    final activeFilter = listState.activeFilter;

    return Column(
      children: [
        // ── Filter chips ──────────────────────────────────────────────────
        SizedBox(
          height: 44,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            itemCount: _filters.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final f = _filters[i];
              final count = _countFor(f.key, summary);
              final isActive = activeFilter == f.key;
              return _FilterChip(
                label: '${f.label} $count',
                icon: f.icon,
                isActive: isActive,
                onTap: () =>
                    ref.read(filesNotifierProvider.notifier).setFilter(f.key),
              );
            },
          ),
        ),

        // ── File list ─────────────────────────────────────────────────────
        Expanded(
          child: listState.isLoading && listState.files.isEmpty
              ? _buildSkeleton()
              : listState.error != null && listState.files.isEmpty
                  ? _buildError(listState.error!, ref)
                  : _buildList(listState, ref),
        ),
      ],
    );
  }

  int _countFor(String key, FilesSummary s) {
    switch (key) {
      case 'all':
        return s.total;
      case 'image':
        return s.image;
      case 'audio':
        return s.audio;
      case 'video':
        return s.video;
      case 'voice':
        return s.voice;
      case 'docs':
        return s.docs;
      default:
        return 0;
    }
  }

  Widget _buildList(FilesListState listState, WidgetRef ref) {
    final filtered = widget.searchQuery.isEmpty
        ? listState.files
        : listState.files.where((f) {
            return f.originalName.toLowerCase().contains(widget.searchQuery) ||
                (f.uploadedBy?.toLowerCase().contains(widget.searchQuery) ??
                    false);
          }).toList();

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_open_rounded,
                size: 52, color: AppTheme.textDim),
            const SizedBox(height: 14),
            Text(
                widget.searchQuery.isEmpty
                    ? 'No files yet'
                    : 'No results for "${widget.searchQuery}"',
                style:
                    AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
                widget.searchQuery.isEmpty
                    ? 'Upload a file or share one in chat'
                    : 'Try a different search term',
                style: AppTheme.caption),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async => ref.read(filesNotifierProvider.notifier).load(),
      color: AppTheme.primary,
      backgroundColor: AppTheme.bgCard,
      child: ListView.separated(
        controller: _scrollController,
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
        itemCount: filtered.length + (listState.hasMore ? 1 : 0),
        separatorBuilder: (_, __) => Divider(height: 1, color: AppTheme.border),
        itemBuilder: (ctx, i) {
          if (i == filtered.length) {
            // Load more indicator at bottom
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Center(
                child: listState.isLoadingMore
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primary,
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            );
          }
          return _FileRow(
            file: filtered[i],
            onTap: () => widget.onOpen(filtered[i]),
            onStar: () => ref
                .read(filesNotifierProvider.notifier)
                .toggleStar(filtered[i].id),
          );
        },
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 8,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppTheme.bgElevated,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 13,
                    width: double.infinity,
                    color: AppTheme.bgElevated,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 11,
                    width: 120,
                    color: AppTheme.bgElevated,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.folder_off_rounded,
                size: 48, color: AppTheme.textDim),
            const SizedBox(height: 14),
            Text('Could not load files',
                style:
                    AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(message, style: AppTheme.caption, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () => ref.read(filesNotifierProvider.notifier).load(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
            ),
          ],
        ),
      ),
    );
  }
}

// ── File row ──────────────────────────────────────────────────────────────────

class _FileRow extends StatelessWidget {
  const _FileRow({
    required this.file,
    required this.onTap,
    required this.onStar,
  });

  final SharedFile file;
  final VoidCallback onTap;
  final VoidCallback onStar;

  static const _typeColors = {
    'PDF': (Color(0xFFEF4444), Color(0x1AEF4444)),
    'DOC': (Color(0xFF3B82F6), Color(0x1A3B82F6)),
    'DOCX': (Color(0xFF3B82F6), Color(0x1A3B82F6)),
    'XLS': (Color(0xFF10B981), Color(0x1A10B981)),
    'XLSX': (Color(0xFF10B981), Color(0x1A10B981)),
    'PNG': (Color(0xFFA78BFA), Color(0x1AA78BFA)),
    'JPG': (Color(0xFFA78BFA), Color(0x1AA78BFA)),
    'JPEG': (Color(0xFFA78BFA), Color(0x1AA78BFA)),
    'GIF': (Color(0xFFA78BFA), Color(0x1AA78BFA)),
    'ZIP': (Color(0xFF60A5FA), Color(0x1A60A5FA)),
    'MP4': (Color(0xFFF59E0B), Color(0x1AF59E0B)),
    'WEBM': (Color(0xFFF59E0B), Color(0x1AF59E0B)),
    'MP3': (Color(0xFF06D6A0), Color(0x1A06D6A0)),
    'OGG': (Color(0xFF06D6A0), Color(0x1A06D6A0)),
  };

  @override
  Widget build(BuildContext context) {
    final type = file.displayType;
    final colors =
        _typeColors[type] ?? (AppTheme.textMuted, AppTheme.bgElevated);
    final (iconColor, iconBg) = colors;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // File icon
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Center(
                    child: file.isImage
                        ? Icon(Icons.image_rounded, color: iconColor, size: 20)
                        : file.isVideo
                            ? Icon(Icons.videocam_rounded,
                                color: iconColor, size: 20)
                            : file.isAudio
                                ? Icon(Icons.headphones_rounded,
                                    color: iconColor, size: 20)
                                : Text(
                                    type,
                                    style: TextStyle(
                                      color: iconColor,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                  ),
                ),
                const SizedBox(width: 12),

                // Name + meta
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        file.originalName,
                        style: AppTheme.bodySmall.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (file.fileSize != null &&
                              file.fileSize!.isNotEmpty) ...[
                            Text(file.fileSize!, style: AppTheme.caption),
                            const SizedBox(width: 6),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                color: AppTheme.textDim,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 6),
                          ],
                          if (file.formattedDate.isNotEmpty)
                            Text(
                              file.formattedTimePart.isNotEmpty
                                  ? '${file.formattedDate} ${file.formattedTimePart}'
                                  : file.formattedDate,
                              style: AppTheme.caption,
                            ),
                          // Show link indicator if it's a shared link
                          if (file.referenceId != null &&
                              file.referenceId!.isNotEmpty) ...[
                            const SizedBox(width: 6),
                            Container(
                              width: 3,
                              height: 3,
                              decoration: BoxDecoration(
                                color: AppTheme.textDim,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 6),
                            const Icon(Icons.link_rounded,
                                size: 12, color: AppTheme.textDim),
                          ],
                        ],
                      ),
                      if (file.uploadedBy != null &&
                          file.uploadedBy!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          file.uploadedBy!,
                          style: AppTheme.caption
                              .copyWith(color: AppTheme.textDim),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      // Tags
                      if (file.tags.isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: file.tags
                              .take(3) // Show max 3 tags to avoid clutter
                              .map((tag) => Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: tag.tagColor != null
                                          ? Color(int.parse(
                                                  '0xFF${tag.tagColor!.substring(1)}'))
                                              .withValues(alpha: 0.15)
                                          : AppTheme.bgElevated,
                                      borderRadius: BorderRadius.circular(4),
                                      border: Border.all(
                                        color: tag.tagColor != null
                                            ? Color(int.parse(
                                                '0xFF${tag.tagColor!.substring(1)}'))
                                            : AppTheme.border,
                                        width: 0.5,
                                      ),
                                    ),
                                    child: Text(
                                      tag.title,
                                      style: AppTheme.caption.copyWith(
                                        fontSize: 10,
                                        fontWeight: FontWeight.w500,
                                        color: tag.tagColor != null
                                            ? Color(int.parse(
                                                '0xFF${tag.tagColor!.substring(1)}'))
                                            : AppTheme.textDim,
                                      ),
                                    ),
                                  ))
                              .toList(),
                        ),
                        if (file.tags.length > 3)
                          Padding(
                            padding: const EdgeInsets.only(left: 4),
                            child: Text(
                              '+${file.tags.length - 3} more',
                              style: AppTheme.caption.copyWith(
                                fontSize: 10,
                                color: AppTheme.textDim,
                              ),
                            ),
                          ),
                      ],
                    ],
                  ),
                ),

                const SizedBox(width: 8),

                // Star
                GestureDetector(
                  onTap: onStar,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Icon(
                      file.star
                          ? Icons.star_rounded
                          : Icons.star_border_rounded,
                      color: file.star
                          ? const Color(0xFFF59E0B)
                          : AppTheme.textDim,
                      size: 20,
                    ),
                  ),
                ),

                // Download icon / Link indicator
                Padding(
                  padding: const EdgeInsets.only(left: 2),
                  child:
                      file.referenceId != null && file.referenceId!.isNotEmpty
                          ? Icon(Icons.link_rounded,
                              size: 18, color: AppTheme.textDim)
                          : Icon(Icons.download_rounded,
                              size: 18, color: AppTheme.textDim),
                ),
              ],
            ),
            // Link info for links tab
            if (file.referenceId != null && file.referenceId!.isNotEmpty) ...[
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.only(left: 52),
                child: Row(
                  children: [
                    Text(
                      'Ref: ${file.referenceType ?? 'link'}',
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.textDim,
                        fontSize: 11,
                      ),
                    ),
                    if (file.viewCount > 0) ...[
                      const SizedBox(width: 8),
                      Container(
                        width: 1,
                        height: 10,
                        color: AppTheme.border,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${file.viewCount} views',
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.textDim,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Filter chip ───────────────────────────────────────────────────────────────

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.icon,
    required this.isActive,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primary.withValues(alpha: 0.15)
              : AppTheme.bgElevated,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isActive ? AppTheme.primary : AppTheme.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                size: 13,
                color: isActive ? AppTheme.primary : AppTheme.textDim),
            const SizedBox(width: 5),
            Text(
              label,
              style: AppTheme.caption.copyWith(
                color: isActive ? AppTheme.primary : AppTheme.textMuted,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Tags tab ────────────────────────────────────────────────────────────────────

class _TagsTab extends ConsumerStatefulWidget {
  const _TagsTab();

  @override
  ConsumerState<_TagsTab> createState() => _TagsTabState();
}

class _TagsTabState extends ConsumerState<_TagsTab> {
  @override
  void initState() {
    super.initState();
    // Load tags when tab is first shown
    Future.microtask(() {
      ref.read(tagsNotifierProvider.notifier).load();
    });
  }

  @override
  Widget build(BuildContext context) {
    final tagsState = ref.watch(tagsNotifierProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.read(tagsNotifierProvider.notifier).load(),
      color: AppTheme.primary,
      backgroundColor: AppTheme.bgCard,
      child: tagsState.isLoading && tagsState.tags.isEmpty
          ? _buildSkeleton()
          : tagsState.error != null && tagsState.tags.isEmpty
              ? _buildError(tagsState.error!)
              : _buildTagList(tagsState.tags),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 10,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.bgElevated,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 14,
                    width: double.infinity,
                    color: AppTheme.bgElevated,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 11,
                    width: 80,
                    color: AppTheme.bgElevated,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.label_off_rounded,
                size: 48, color: AppTheme.textDim),
            const SizedBox(height: 14),
            Text('Could not load tags',
                style:
                    AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(message, style: AppTheme.caption, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () => ref.read(tagsNotifierProvider.notifier).load(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTagList(List<TagDetails> tags) {
    if (tags.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.label_rounded, size: 52, color: AppTheme.textDim),
            const SizedBox(height: 14),
            Text('No tags yet',
                style:
                    AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Create tags to organize your files', style: AppTheme.caption),
          ],
        ),
      );
    }

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: tags.length,
      separatorBuilder: (_, __) => Divider(height: 1, color: AppTheme.border),
      itemBuilder: (ctx, i) {
        final tag = tags[i];
        final color = tag.tagColor != null
            ? Color(int.parse('0xFF${tag.tagColor!.substring(1)}'))
            : AppTheme.primary;

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              // Tag color indicator
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: color,
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(Icons.label_rounded, color: color, size: 20),
                ),
              ),
              const SizedBox(width: 12),

              // Tag info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tag.title,
                      style: AppTheme.bodySmall.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    if (tag.useCount != null)
                      Text(
                        '${tag.useCount} files',
                        style: AppTheme.caption,
                      ),
                  ],
                ),
              ),

              // Tag type badge (if private/public)
              if (tag.tagType != null) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppTheme.bgElevated,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    tag.tagType == 'public' ? 'Public' : 'Private',
                    style: AppTheme.caption.copyWith(
                      fontSize: 10,
                      color: AppTheme.textDim,
                    ),
                  ),
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ── Upload FAB ────────────────────────────────────────────────────────────────

class _UploadFab extends StatelessWidget {
  const _UploadFab({this.onTap});
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          gradient: onTap != null ? AppTheme.primaryGradient : null,
          color: onTap == null ? AppTheme.bgElevated : null,
          borderRadius: BorderRadius.circular(16),
          boxShadow: onTap != null
              ? [
                  BoxShadow(
                    color: AppTheme.primary.withValues(alpha: 0.35),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Icon(
          Icons.upload_file_rounded,
          color: onTap != null ? Colors.white : AppTheme.textDim,
          size: 24,
        ),
      ),
    );
  }
}

// ── Links tab ───────────────────────────────────────────────────────────────────

class _LinksTab extends ConsumerStatefulWidget {
  const _LinksTab();

  @override
  ConsumerState<_LinksTab> createState() => _LinksTabState();
}

class _LinksTabState extends ConsumerState<_LinksTab> {
  final ScrollController _scrollController = ScrollController();
  bool _conversationsLoaded = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    Future.microtask(_setupConversationIds);
  }

  @override
  void dispose() {
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    super.dispose();
  }

  Future<void> _setupConversationIds() async {
    if (_conversationsLoaded) return;
    try {
      final rooms = await ref.read(roomsProvider.future);
      final convIds =
          rooms.map((r) => r.id).where((id) => id.isNotEmpty).toList();
      ref.read(linksNotifierProvider.notifier).setConversationIds(convIds);
      ref.read(linksNotifierProvider.notifier).load();
      _conversationsLoaded = true;
    } catch (e) {
      // Could not load rooms - will show error
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
            _scrollController.position.maxScrollExtent * 0.8 &&
        !ref.read(linksNotifierProvider).isLoadingMore) {
      ref.read(linksNotifierProvider.notifier).loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    final linksState = ref.watch(linksNotifierProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.read(linksNotifierProvider.notifier).load(),
      color: AppTheme.primary,
      backgroundColor: AppTheme.bgCard,
      child: linksState.isLoading && linksState.links.isEmpty
          ? _buildSkeleton()
          : linksState.error != null && linksState.links.isEmpty
              ? _buildError(linksState.error!)
              : _buildLinkList(linksState),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: 8,
      itemBuilder: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.bgElevated,
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 13,
                    width: double.infinity,
                    color: AppTheme.bgElevated,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 11,
                    width: 120,
                    color: AppTheme.bgElevated,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildError(String message) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_off_rounded,
                size: 48, color: AppTheme.textDim),
            const SizedBox(height: 14),
            Text('Could not load links',
                style:
                    AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(message, style: AppTheme.caption, textAlign: TextAlign.center),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () => ref.read(linksNotifierProvider.notifier).load(),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLinkList(LinksListState state) {
    final links = state.links;

    if (links.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.link_rounded, size: 52, color: AppTheme.textDim),
            const SizedBox(height: 14),
            Text('No links yet',
                style:
                    AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Shared links will appear here', style: AppTheme.caption),
          ],
        ),
      );
    }

    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
      itemCount: links.length + (state.hasMore ? 1 : 0),
      separatorBuilder: (_, __) => Divider(height: 1, color: AppTheme.border),
      itemBuilder: (ctx, i) {
        if (i == links.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Center(
              child: state.isLoadingMore
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.primary,
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          );
        }
        return _LinkRow(link: links[i]);
      },
    );
  }
}

// ── Link row ────────────────────────────────────────────────────────────────────

class _LinkRow extends StatelessWidget {
  const _LinkRow({required this.link});

  final Link link;

  @override
  Widget build(BuildContext context) {
    final displayUrl = link.url;
    final displayTitle =
        link.title?.isNotEmpty == true ? link.title! : displayUrl;

    return GestureDetector(
      onTap: () async {
        final uri = Uri.tryParse(link.url);
        if (uri != null && await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            // Link icon - no background, just icon
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              child: const Icon(Icons.link_rounded,
                  color: AppTheme.textDim, size: 20),
            ),
            const SizedBox(width: 12),

            // Link info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    displayTitle,
                    style: AppTheme.bodySmall.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 3),
                  Text(
                    displayUrl,
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.textDim,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    link.uploadedBy ?? 'Unknown',
                    style: AppTheme.caption.copyWith(color: AppTheme.textDim),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // External link icon
            const Padding(
              padding: EdgeInsets.only(left: 2),
              child: Icon(Icons.open_in_new_rounded,
                  size: 18, color: AppTheme.textDim),
            ),
          ],
        ),
      ),
    );
  }
}
