import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'file_models.dart';
import 'files_service.dart';
import 'links_service.dart';

// ── Files list state ──────────────────────────────────────────────────────────

class FilesListState {
  final List<SharedFile> files;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int currentPage;
  final bool hasMore;

  /// Active file-type filter chip. Mirrors the React web values:
  /// `'all'`, `'image'`, `'video'`, `'audio'`, `'voice'`, `'docs'`.
  final String activeFilter;

  /// Active tab: `'files'` or `'links'`.
  final String activeTab;

  /// File sub-type filter: `'ref'` for shared links, `'star'` for starred,
  /// `'tag'` for tagged files, `'share'` for shared files.
  final String? fileSubType;

  /// Per-type counts returned by the backend summary field.
  final FilesSummary summary;

  const FilesListState({
    this.files = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.currentPage = 1,
    this.hasMore = true,
    this.activeFilter = 'all',
    this.activeTab = 'files',
    this.fileSubType,
    this.summary = const FilesSummary(),
  });

  FilesListState copyWith({
    List<SharedFile>? files,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    String? activeFilter,
    String? activeTab,
    String? fileSubType,
    FilesSummary? summary,
    int? currentPage,
    bool? hasMore,
  }) =>
      FilesListState(
        files: files ?? this.files,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
        activeFilter: activeFilter ?? this.activeFilter,
        activeTab: activeTab ?? this.activeTab,
        fileSubType: fileSubType ?? this.fileSubType,
        summary: summary ?? this.summary,
        currentPage: currentPage ?? this.currentPage,
        hasMore: hasMore ?? this.hasMore,
      );
}

// ── Notifier ──────────────────────────────────────────────────────────────────

class FilesNotifier extends StateNotifier<FilesListState> {
  FilesNotifier() : super(const FilesListState()) {
    _load(page: 1, reset: true);
  }

  /// Public reload — resets to page 1.
  Future<void> load() => _load(page: 1, reset: true);

  /// Load next page — called when user scrolls to bottom.
  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore) return;
    await _load(page: state.currentPage + 1, reset: false);
  }

  /// Switch filter chip without changing the tab/sub-type.
  Future<void> setFilter(String filter) async {
    if (state.activeFilter == filter) return;
    state = state.copyWith(activeFilter: filter);
    await _load(page: 1, reset: true);
  }

  /// Switch tab (files ↔ links); optionally set a file_sub_type.
  /// For main Files tab: setTab('files')
  /// For Links tab: setTab('files', 'ref')
  Future<void> setTab(String tab, {String? fileSubType}) async {
    if (state.activeTab == tab && state.fileSubType == fileSubType) return;
    state = state.copyWith(
      activeTab: tab,
      activeFilter: 'all',
      fileSubType: fileSubType,
    );
    await _load(page: 1, reset: true);
  }

  /// Toggle star on a file locally (optimistic — no backend mutation yet).
  void toggleStar(String fileId) {
    state = state.copyWith(
      files: state.files.map((f) {
        return f.id == fileId ? f.copyWith(star: !f.star) : f;
      }).toList(),
    );
  }

  /// Prepend a freshly uploaded file to the top of the list.
  void prependFile(SharedFile file) =>
      state = state.copyWith(files: [file, ...state.files]);

  void clearError() => state = state.copyWith(clearError: true);

  Future<void> _load({required int page, required bool reset}) async {
    if (page == 1) {
      state = state.copyWith(isLoading: true, clearError: true);
    } else {
      state = state.copyWith(isLoadingMore: true);
    }

    try {
      final result = await FilesService.getFiles(
        page: page,
        tab: 'file', // always 'file' for files/links; tags handled separately
        fileType: state.activeFilter == 'all' ? null : state.activeFilter,
        fileSubType: state.fileSubType,
      );

      final newFiles = result.files;
      final hasMore = result.pagination.hasMore;

      state = state.copyWith(
        files: reset ? newFiles : [...state.files, ...newFiles],
        summary: result.summary,
        isLoading: false,
        isLoadingMore: false,
        currentPage: page,
        hasMore: hasMore,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

final filesNotifierProvider =
    StateNotifierProvider.autoDispose<FilesNotifier, FilesListState>(
        (_) => FilesNotifier());

/// Convenience alias — keeps existing `ref.watch(filesProvider)` call-sites working.
final filesProvider = Provider.autoDispose<AsyncValue<List<SharedFile>>>((ref) {
  final s = ref.watch(filesNotifierProvider);
  if (s.isLoading) return const AsyncValue.loading();
  if (s.error != null && s.files.isEmpty) {
    return AsyncValue.error(s.error!, StackTrace.empty);
  }
  return AsyncValue.data(s.files);
});

// ── Tags state ────────────────────────────────────────────────────────────────

class TagsListState {
  final List<TagDetails> tags;
  final bool isLoading;
  final String? error;

  const TagsListState({
    this.tags = const [],
    this.isLoading = false,
    this.error,
  });

  TagsListState copyWith({
    List<TagDetails>? tags,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) =>
      TagsListState(
        tags: tags ?? this.tags,
        isLoading: isLoading ?? this.isLoading,
        error: clearError ? null : (error ?? this.error),
      );
}

class TagsNotifier extends StateNotifier<TagsListState> {
  TagsNotifier() : super(const TagsListState());

  Future<void> load({String? conversationId}) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final tags = await FilesService.getTags(conversationId: conversationId);
      state = state.copyWith(tags: tags, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final tagsNotifierProvider =
    StateNotifierProvider.autoDispose<TagsNotifier, TagsListState>(
        (_) => TagsNotifier());

// ── Upload state ──────────────────────────────────────────────────────────────

class UploadState {
  final bool isUploading;
  final double progress; // 0.0 – 1.0
  final String? error;

  const UploadState({
    this.isUploading = false,
    this.progress = 0,
    this.error,
  });

  UploadState copyWith({
    bool? isUploading,
    double? progress,
    String? error,
    bool clearError = false,
  }) =>
      UploadState(
        isUploading: isUploading ?? this.isUploading,
        progress: progress ?? this.progress,
        error: clearError ? null : (error ?? this.error),
      );
}

class UploadNotifier extends StateNotifier<UploadState> {
  UploadNotifier(this._ref) : super(const UploadState());

  final Ref _ref;

  Future<bool> upload({
    required File file,
    required String userEmail,
  }) async {
    state = state.copyWith(isUploading: true, progress: 0, clearError: true);
    try {
      final uploaded = await FilesService.uploadFile(
        file: file,
        userEmail: userEmail,
        onProgress: (sent, total) {
          if (total > 0) state = state.copyWith(progress: sent / total);
        },
      );
      _ref.read(filesNotifierProvider.notifier).prependFile(uploaded);
      state = state.copyWith(isUploading: false, progress: 1);
      return true;
    } catch (e) {
      state = state.copyWith(
        isUploading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
      return false;
    }
  }

  void clearError() => state = state.copyWith(clearError: true);
}

final uploadNotifierProvider =
    StateNotifierProvider.autoDispose<UploadNotifier, UploadState>(
        (ref) => UploadNotifier(ref));

// ── Links state ────────────────────────────────────────────────────────────────

class LinksListState {
  final List<Link> links;
  final bool isLoading;
  final bool isLoadingMore;
  final String? error;
  final int currentPage;
  final bool hasMore;

  const LinksListState({
    this.links = const [],
    this.isLoading = false,
    this.isLoadingMore = false,
    this.error,
    this.currentPage = 1,
    this.hasMore = true,
  });

  LinksListState copyWith({
    List<Link>? links,
    bool? isLoading,
    bool? isLoadingMore,
    String? error,
    bool clearError = false,
    int? currentPage,
    bool? hasMore,
  }) =>
      LinksListState(
        links: links ?? this.links,
        isLoading: isLoading ?? this.isLoading,
        isLoadingMore: isLoadingMore ?? this.isLoadingMore,
        error: clearError ? null : (error ?? this.error),
        currentPage: currentPage ?? this.currentPage,
        hasMore: hasMore ?? this.hasMore,
      );
}

class LinksNotifier extends StateNotifier<LinksListState> {
  LinksNotifier() : super(const LinksListState());

  /// List of conversation IDs to query links for.
  /// In the FileHub, this should be all conversations the user belongs to.
  List<String>? _conversationIds;

  void setConversationIds(List<String> conversationIds) {
    _conversationIds = conversationIds;
  }

  Future<void> load() async {
    if (_conversationIds == null || _conversationIds!.isEmpty) return;
    await _load(page: 1, reset: true);
  }

  Future<void> loadMore() async {
    if (state.isLoadingMore || !state.hasMore || _conversationIds == null) {
      return;
    }
    await _load(page: state.currentPage + 1, reset: false);
  }

  Future<void> _load({required int page, required bool reset}) async {
    if (page == 1) {
      state = state.copyWith(isLoading: true, clearError: true);
    } else {
      state = state.copyWith(isLoadingMore: true);
    }

    try {
      final result = await LinksService.getLinks(
        conversationIds: _conversationIds!,
        page: page,
      );

      state = state.copyWith(
        links: reset ? result.links : [...state.links, ...result.links],
        isLoading: false,
        isLoadingMore: false,
        currentPage: page,
        hasMore: result.pagination.hasMore,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        isLoadingMore: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }
}

final linksNotifierProvider =
    StateNotifierProvider.autoDispose<LinksNotifier, LinksListState>(
        (_) => LinksNotifier());
