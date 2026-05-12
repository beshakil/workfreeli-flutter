import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/conversation_models.dart';
import '../files/file_models.dart' show TagDetails;
import '../files/files_service.dart';
import '../user/user_providers.dart';
import 'conversations_service.dart';

export 'conversations_service.dart' show ConversationsService;

// ── Active room tracker ───────────────────────────────────────────────────────

/// Holds the conversation_id of the chat screen currently on-screen.
/// Set to the room ID when MessageScreen opens; cleared on dispose.
/// Used by the unread-counter logic to skip incrementing the open room.
final activeRoomIdProvider = StateProvider<String?>((ref) => null);

// ── Unread counters ───────────────────────────────────────────────────────────

class UnreadCountsNotifier extends StateNotifier<Map<String, int>> {
  UnreadCountsNotifier() : super({});

  void increment(String conversationId) {
    state = {...state, conversationId: (state[conversationId] ?? 0) + 1};
  }

  void reset(String conversationId) {
    if (!state.containsKey(conversationId)) return;
    final updated = Map<String, int>.from(state)..remove(conversationId);
    state = updated;
  }

  void resetAll() => state = {};

  /// Seed the counter map from the backend's total_unread response.
  /// Backend values are authoritative — they override any locally-incremented counts.
  void initFromBackend(Map<String, int> counts) {
    state = {...state, ...counts};
  }

  /// Decrement a conversation's unread count (e.g. from read_status_msg XMPP event).
  void decrement(String conversationId, int by) {
    final current = state[conversationId] ?? 0;
    final updated = (current - by).clamp(0, 99999);
    if (updated <= 0) {
      final next = Map<String, int>.from(state)..remove(conversationId);
      state = next;
    } else {
      state = {...state, conversationId: updated};
    }
  }

  int countFor(String conversationId) => state[conversationId] ?? 0;

  int get totalUnread => state.values.fold(0, (a, b) => a + b);
}

/// Per-conversation unread message counts, driven by XMPP new_message events.
final unreadCountsProvider =
    StateNotifierProvider<UnreadCountsNotifier, Map<String, int>>(
        (_) => UnreadCountsNotifier());

/// Derived: total unread across all conversations.
final totalUnreadProvider = Provider<int>((ref) {
  return ref.watch(unreadCountsProvider.notifier).totalUnread;
});

// ── Backend unread count initialiser ─────────────────────────────────────────

/// Fetches the server's total_unread on login and seeds UnreadCountsNotifier.
/// Not autoDispose — cached for the session. Invalidated by logout.
final unreadInitProvider = FutureProvider<void>((ref) async {
  try {
    final counts = await ConversationsService.getTotalUnread();
    ref.read(unreadCountsProvider.notifier).initFromBackend(counts);
  } catch (_) {
    // Non-fatal — local XMPP-driven counts still work.
  }
});

// ── Rooms ─────────────────────────────────────────────────────────────────────

// Not autoDispose — stays alive across tab switches so the list is not
// re-fetched every time the user leaves and returns to the Messages tab.
// Invalidated explicitly by logout and by invalidate(roomsProvider) on
// new_room / update_room XMPP events.
final roomsProvider = FutureProvider<List<Room>>((ref) async {
  final user = await ref.watch(meProvider.future);
  return ConversationsService.getRooms(user.id);
});

// ── Per-room XMPP-driven last-message preview ─────────────────────────────────

class RoomPreviewNotifier
    extends StateNotifier<Map<String, ({String preview, String time})>> {
  RoomPreviewNotifier() : super({});

  void update({
    required String convId,
    required String senderName,
    required String preview,
    required String time,
  }) {
    final full = senderName.isNotEmpty ? '$senderName: $preview' : preview;
    final truncated = full.length > 80 ? '${full.substring(0, 80)}…' : full;
    state = {
      ...state,
      convId: (preview: truncated, time: time),
    };
  }

  void clear() => state = {};
}

final roomPreviewNotifierProvider = StateNotifierProvider<RoomPreviewNotifier,
    Map<String, ({String preview, String time})>>(
  (_) => RoomPreviewNotifier(),
);

/// Merges server rooms with XMPP-driven previews and re-sorts.
/// Pinned rooms stay first; others are ordered by most-recent message time.
/// Not autoDispose — mirrors roomsProvider lifetime.
final sortedRoomsProvider = Provider<AsyncValue<List<Room>>>((ref) {
  final roomsAsync = ref.watch(roomsProvider);
  final previews = ref.watch(roomPreviewNotifierProvider);
  if (previews.isEmpty) return roomsAsync;

  return roomsAsync.whenData((rooms) {
    final merged = rooms.map((r) {
      final p = previews[r.id];
      if (p == null) return r;
      return r.copyWith(lastMsgPreview: p.preview, lastMsgTime: p.time);
    }).toList();

    merged.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return (b.lastMsgTime ?? '').compareTo(a.lastMsgTime ?? '');
    });
    return merged;
  });
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
      final fetched = page.messages.reversed.toList();
      // Preserve any real-time XMPP messages that arrived while the GraphQL
      // fetch was in-flight. Those messages are at the front of state.messages
      // (newest-first) and may not yet be in the server's page-1 response if
      // the DB write races with this read. Deduplicate by msg_id so we never
      // show a message twice.
      final fetchedIds = fetched.map((m) => m.id).toSet();
      final realtimeOnly =
          state.messages.where((m) => !fetchedIds.contains(m.id)).toList();
      state = state.copyWith(
        messages: [...realtimeOnly, ...fetched],
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

  // ── Real-time XMPP injection ──────────────────────────────────────────────

  /// Injects a message received via XMPP without an API round-trip.
  /// Deduplicates by msg_id so a rapid refresh + XMPP event don't duplicate.
  void addRealTimeMessage(ChatMessage msg) {
    if (state.messages.any((m) => m.id == msg.id)) {
      debugPrint(
          '[MessagesNotifier] addRealTimeMessage: duplicate id="${msg.id}" — skipped');
      return;
    }
    debugPrint(
        '[MessagesNotifier] addRealTimeMessage: prepending id="${msg.id}" sender="${msg.senderId}"');
    state = state.copyWith(messages: [msg, ...state.messages]);
  }

  /// Tries to build a [ChatMessage] from a raw XMPP new_message payload.
  /// Returns null if the payload is malformed or belongs to a different room.
  static ChatMessage? parseXmppMessage(
    Map<String, dynamic> data,
    String selfId,
    String roomId,
  ) {
    try {
      final convId = data['conversation_id']?.toString() ??
          data['conv_id']?.toString() ??
          '';
      debugPrint(
          '[parseXmppMessage] convId="$convId" roomId="$roomId" selfId="$selfId"');

      if (convId.isNotEmpty && convId != roomId) {
        debugPrint('[parseXmppMessage] filtered: wrong room');
        return null;
      }

      final rawBody = data['msg_body']?.toString() ?? '';
      final msgId = (data['msg_id'] ?? data['_id'] ?? '').toString();
      final sender = (data['sender'] ?? data['user_id'] ?? '').toString();
      debugPrint(
          '[parseXmppMessage] msg_id="$msgId" sender="$sender" bodyLen=${rawBody.length}');

      if (msgId.isEmpty) {
        debugPrint('[parseXmppMessage] empty msg_id — dropping');
        return null;
      }

      final msgMap = <String, dynamic>{
        'msg_id': msgId,
        'msg_body': rawBody,
        'msg_type': data['msg_type'] ?? 'text',
        'sender': sender,
        'sendername': data['sendername'] ?? data['sender_name'] ?? '',
        'senderimg': data['senderimg'] ?? data['sender_img'],
        'created_at': data['created_at'] ?? DateTime.now().toIso8601String(),
        'all_attachment': data['all_attachment'] ?? [],
      };

      final msg = ChatMessage.fromJson(msgMap, selfId: selfId);
      debugPrint(
          '[parseXmppMessage] built ChatMessage id="${msg.id}" isSelf=${msg.isSelf}');
      return msg;
    } catch (e) {
      debugPrint('[parseXmppMessage] error: $e');
      return null;
    }
  }

  // ── Pending file management ───────────────────────────────────────────────

  void addPendingFile(File file) =>
      state = state.copyWith(pendingFiles: [...state.pendingFiles, file]);

  void removePendingFile(int index) {
    final updated = [...state.pendingFiles]..removeAt(index);
    state = state.copyWith(pendingFiles: updated);
  }

  void clearPendingFiles() => state = state.copyWith(pendingFiles: []);

  // ── Send message ──────────────────────────────────────────────────────────

  /// Sends [text] with any [pendingFiles] attached.
  ///
  /// Flow:
  ///   1. Upload each pending file via REST → get raw file-info maps.
  ///   2. Send GraphQL mutation with text + attach_files payload.
  ///   3. Prepend returned message to the local list.
  ///
  /// On error, pending files are restored so the user can retry.
  Future<void> sendMessage(String text,
      {List<TagDetails>? selectedTags}) async {
    final trimmed = text.trim();
    final filesToSend = List<File>.from(state.pendingFiles);
    if (trimmed.isEmpty && filesToSend.isEmpty) return;

    state = state.copyWith(
      isSending: true,
      clearError: true,
      pendingFiles: [],
    );

    try {
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

      final msg = await ConversationsService.sendMessage(
        _roomId,
        trimmed,
        _selfId,
        _companyId,
        _participants,
        attachFiles: uploadedFiles,
        selectedTags: selectedTags,
      );

      // Guard: XMPP echo may have already prepended this message while the
      // mutation was in-flight. Deduplicate so the message never appears twice.
      final alreadyPresent = state.messages.any((m) => m.id == msg.id);
      state = state.copyWith(
        messages: alreadyPresent ? state.messages : [msg, ...state.messages],
        isSending: false,
      );
    } catch (e) {
      state = state.copyWith(
        isSending: false,
        error: e.toString().replaceFirst('Exception: ', ''),
        pendingFiles: filesToSend,
      );
    }
  }
}

// ── Provider ──────────────────────────────────────────────────────────────────

final messagesProvider = StateNotifierProvider.autoDispose
    .family<MessagesNotifier, MessagesState, MsgArgs>(
  (ref, args) {
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
