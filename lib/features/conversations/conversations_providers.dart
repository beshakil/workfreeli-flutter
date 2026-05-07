import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/conversation_models.dart';
import '../files/files_service.dart';
import '../user/user_providers.dart';
import 'conversations_service.dart';

final roomsProvider = FutureProvider.autoDispose<List<Room>>((ref) async {
  final user = await ref.watch(meProvider.future);
  return ConversationsService.getRooms(user.id);
});

// ── Messages state ────────────────────────────────────────────────────────────

class MessagesState {
  final List<ChatMessage> messages;
  final bool isLoading;
  final bool isSending;
  final bool hasMore;
  final int currentPage;
  final String? error;
  /// Files selected by the user waiting to be sent with the next message.
  final List<File> pendingFiles;

  const MessagesState({
    this.messages = const [],
    this.isLoading = false,
    this.isSending = false,
    this.hasMore = true,
    this.currentPage = 1,
    this.error,
    this.pendingFiles = const [],
  });

  MessagesState copyWith({
    List<ChatMessage>? messages,
    bool? isLoading,
    bool? isSending,
    bool? hasMore,
    int? currentPage,
    String? error,
    bool clearError = false,
    List<File>? pendingFiles,
  }) =>
      MessagesState(
        messages: messages ?? this.messages,
        isLoading: isLoading ?? this.isLoading,
        isSending: isSending ?? this.isSending,
        hasMore: hasMore ?? this.hasMore,
        currentPage: currentPage ?? this.currentPage,
        error: clearError ? null : (error ?? this.error),
        pendingFiles: pendingFiles ?? this.pendingFiles,
      );
}

// ── Notifier args ─────────────────────────────────────────────────────────────
// participantsJoined is a comma-separated string so it is value-comparable
// and avoids runtime equality issues that Lists would cause on the record key.

typedef MsgArgs = ({
  String roomId,
  String selfId,
  String companyId,
  String participantsJoined,
});

class MessagesNotifier extends StateNotifier<MessagesState> {
  MessagesNotifier({
    required String roomId,
    required String selfId,
    required String companyId,
    required List<String> participants,
    required String userEmail,
  })  : _roomId = roomId,
        _selfId = selfId,
        _companyId = companyId,
        _participants = participants,
        _userEmail = userEmail,
        super(const MessagesState()) {
    loadInitial();
  }

  final String _roomId;
  final String _selfId;
  final String _companyId;
  final List<String> _participants;
  final String _userEmail;

  Future<void> loadInitial() async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final page = await ConversationsService.getMessages(
        _roomId,
        page: 1,
        selfId: _selfId,
      );
      state = state.copyWith(
        messages: page.messages.reversed.toList(),
        isLoading: false,
        hasMore: page.hasMore,
        currentPage: page.page,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString().replaceFirst('Exception: ', ''),
      );
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoading) return;
    final nextPage = state.currentPage + 1;
    try {
      final page = await ConversationsService.getMessages(
        _roomId,
        page: nextPage,
        selfId: _selfId,
      );
      state = state.copyWith(
        messages: [...state.messages, ...page.messages.reversed],
        hasMore: page.hasMore,
        currentPage: page.page,
      );
    } catch (_) {}
  }

  void clearError() => state = state.copyWith(clearError: true);

  // ── Pending file management ─────────────────────────────────────────────────

  void addPendingFile(File file) =>
      state = state.copyWith(pendingFiles: [...state.pendingFiles, file]);

  void removePendingFile(int index) {
    final updated = [...state.pendingFiles]..removeAt(index);
    state = state.copyWith(pendingFiles: updated);
  }

  void clearPendingFiles() => state = state.copyWith(pendingFiles: []);

  // ── Send message ────────────────────────────────────────────────────────────

  /// Sends [text] with any [pendingFiles] attached.
  ///
  /// Flow:
  ///   1. Upload each pending file via REST → get raw file-info maps.
  ///   2. Send GraphQL mutation with text + attach_files payload.
  ///   3. Prepend returned message to the local list (optimistic-style).
  ///
  /// On error the pending files are restored so the user can retry.
  Future<void> sendMessage(String text) async {
    final trimmed = text.trim();
    final filesToSend = List<File>.from(state.pendingFiles);
    if (trimmed.isEmpty && filesToSend.isEmpty) return;

    // Clear pending files immediately so the UI reflects the "sending" state
    state = state.copyWith(
      isSending: true,
      clearError: true,
      pendingFiles: [],
    );

    try {
      // 1. Upload each file and collect the raw info maps for attach_files
      final uploadedFiles = <Map<String, dynamic>>[];
      for (final file in filesToSend) {
        if (_userEmail.isNotEmpty) {
          final raw = await FilesService.uploadFileRaw(
            file: file,
            userEmail: _userEmail,
          );
          uploadedFiles.add(raw);
        }
      }

      // 2. Send the message (with or without attachments)
      final msg = await ConversationsService.sendMessage(
        _roomId,
        trimmed,
        _selfId,
        _companyId,
        _participants,
        attachFiles: uploadedFiles,
      );

      state = state.copyWith(
        messages: [msg, ...state.messages],
        isSending: false,
      );
    } catch (e) {
      // Restore pending files so the user can retry without re-selecting
      state = state.copyWith(
        isSending: false,
        error: e.toString().replaceFirst('Exception: ', ''),
        pendingFiles: filesToSend,
      );
    }
  }
}

final messagesProvider = StateNotifierProvider.autoDispose
    .family<MessagesNotifier, MessagesState, MsgArgs>(
  (ref, args) {
    // Split the pre-joined participants string — avoids a roomsProvider read
    // which can be null (async) and would silently produce an empty list.
    final participants = args.participantsJoined.isEmpty
        ? const <String>[]
        : args.participantsJoined.split(',');

    final userEmail = ref.read(meProvider).value?.email ?? '';

    return MessagesNotifier(
      roomId: args.roomId,
      selfId: args.selfId,
      companyId: args.companyId,
      participants: participants,
      userEmail: userEmail,
    );
  },
);
