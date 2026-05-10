import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/config/app_config.dart';
import '../core/models/conversation_models.dart';
import '../features/conversations/conversations_providers.dart';
import '../features/files/files_service.dart';
import '../features/xmpp/xmpp_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/image_preview_screen.dart';
import '../widgets/tag_selection_sheet.dart';

class MessageScreen extends ConsumerStatefulWidget {
  const MessageScreen({super.key, required this.room, required this.selfId});

  final Room room;
  final String selfId;

  @override
  ConsumerState<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends ConsumerState<MessageScreen> {
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  final _focusNode = FocusNode();

  MsgArgs get _args => (
        roomId: widget.room.id,
        selfId: widget.selfId,
        companyId: widget.room.companyId ?? '',
        participantsJoined: widget.room.participants.join(','),
      );

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    // Mark this conversation as active so unread stops incrementing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(activeRoomIdProvider.notifier).state = widget.room.id;
      ref.read(unreadCountsProvider.notifier).reset(widget.room.id);
      // Tell the backend the user has read all messages — keeps server unread
      // count in sync so the next login shows the correct badge.
      ConversationsService.readAll(widget.room.id).catchError((_) {});
    });
  }

  @override
  void dispose() {
    // Clear active room so unread resumes on future messages.
    ref.read(activeRoomIdProvider.notifier).state = null;

    _msgController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      ref.read(messagesProvider(_args).notifier).loadMore();
    }
  }

  // ── XMPP real-time injection ──────────────────────────────────────────────

  /// Called by ref.listen every time a new XMPP event arrives.
  /// Mirrors React client: only process messages from OTHER users — own
  /// messages are already added by the GraphQL mutation response.
  void _handleXmppEvent(XmppEvent event) {
    if (event.type != 'new_message' && event.type != 'new_reply_message') return;

    // Skip XMPP echo of own messages — GraphQL sendMessage() already prepends
    // them. Processing the echo would cause a duplicate (race condition when
    // XMPP broadcast arrives before mutation response completes).
    final senderId = event.data['sender']?.toString() ??
        event.data['user_id']?.toString() ?? '';
    if (senderId == widget.selfId) return;

    final msg = MessagesNotifier.parseXmppMessage(
        event.data, widget.selfId, widget.room.id);
    if (msg == null) return;
    ref.read(messagesProvider(_args).notifier).addRealTimeMessage(msg);
    _scrollToTop();
  }

  // ── File picker ─────────────────────────────────────────────────────────────

  Future<void> _pickFiles() async {
    final result = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.any,
    );
    if (result == null || result.files.isEmpty) return;

    final notifier = ref.read(messagesProvider(_args).notifier);
    for (final f in result.files) {
      if (f.path != null) notifier.addPendingFile(File(f.path!));
    }
  }

  // ── Send (with optional tag selection) ─────────────────────────────────────

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    final hasPendingFiles =
        ref.read(messagesProvider(_args)).pendingFiles.isNotEmpty;
    if (text.isEmpty && !hasPendingFiles) return;

    // If there are files, offer tag selection before sending.
    if (hasPendingFiles) {
      final tags = await showTagSelectionSheet(
        context,
        conversationId: widget.room.id,
      );
      // null means user dismissed the sheet → abort send.
      if (tags == null) return;
      // tags == [] means "skip tags" → proceed with send.
    }

    _msgController.clear();
    ref.read(messagesProvider(_args).notifier).sendMessage(text);
    _scrollToTop();
  }

  void _scrollToTop() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── File download helper (used by _AttachmentCard) ──────────────────────

  Future<void> _downloadAndOpen(MessageAttachment attachment) async {
    final url = attachment.downloadUrl(AppConfig.fileBaseUrl);
    if (url.isEmpty) return;

    // Android < API 29 needs storage permission.
    if (Platform.isAndroid) {
      final status = await Permission.storage.status;
      if (!status.isGranted) await Permission.storage.request();
    }

    try {
      final dir = await _downloadDir();
      final savePath = '${dir.path}/${attachment.originalName}';

      _showSnack('Downloading…');
      await FilesService.downloadFile(url: url, savePath: savePath);
      if (!mounted) return;
      _showSnack('Saved. Opening…');
      await OpenFilex.open(savePath);
    } catch (e) {
      _showSnack('Download failed');
    }
  }

  Future<Directory> _downloadDir() async {
    if (Platform.isAndroid) {
      final ext = await getExternalStorageDirectory();
      if (ext != null) {
        final dir = Directory('${ext.path}/Downloads');
        if (!dir.existsSync()) dir.createSync(recursive: true);
        return dir;
      }
    }
    return getApplicationDocumentsDirectory();
  }

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content:
            Text(msg, style: AppTheme.bodySmall.copyWith(color: Colors.white)),
        backgroundColor: AppTheme.bgElevated,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(messagesProvider(_args));

    // Listen for real-time XMPP events while this screen is open.
    ref.listen(xmppEventStreamProvider, (_, next) {
      if (next.hasValue && next.value != null) {
        _handleXmppEvent(next.value!);
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Column(
        children: [
          _buildHeader(context),
          if (state.error != null) _buildErrorBanner(state.error!),
          Expanded(child: _buildMessageList(state)),
          if (state.pendingFiles.isNotEmpty)
            _buildPendingFilesBar(state.pendingFiles),
          _buildInputArea(state),
        ],
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final colors = _avatarColors(widget.room.id);
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + 6,
        left: 4,
        right: 12,
        bottom: 10,
      ),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.arrow_back_ios_new_rounded,
                color: AppTheme.textMuted, size: 20),
          ),
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius:
                  BorderRadius.circular(widget.room.isGroup ? 11 : 19),
            ),
            child: Center(
              child: Text(
                widget.room.initials,
                style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.room.title,
                  style: AppTheme.headingSmall,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      widget.room.isGroup
                          ? Icons.group_rounded
                          : Icons.person_rounded,
                      size: 12,
                      color: AppTheme.textDim,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      widget.room.isGroup ? 'Channel' : 'Direct message',
                      style: AppTheme.caption,
                    ),
                    if (widget.room.isMuted) ...[
                      const SizedBox(width: 8),
                      Icon(Icons.volume_off_rounded,
                          size: 12, color: AppTheme.textDim),
                    ],
                    // Show XMPP connection indicator
                    _XmppStatusDot(),
                  ],
                ),
              ],
            ),
          ),
          _iconBtn(Icons.search_rounded),
          const SizedBox(width: 6),
          _iconBtn(Icons.more_vert_rounded),
        ],
      ),
    );
  }

  // ─── Error banner ──────────────────────────────────────────────────────────

  Widget _buildErrorBanner(String error) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: AppTheme.danger.withValues(alpha: 0.12),
      child: Row(
        children: [
          const Icon(Icons.error_outline_rounded,
              color: AppTheme.danger, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(error,
                style: AppTheme.caption.copyWith(color: AppTheme.danger)),
          ),
          GestureDetector(
            onTap: () =>
                ref.read(messagesProvider(_args).notifier).clearError(),
            child: const Icon(Icons.close_rounded,
                color: AppTheme.danger, size: 16),
          ),
        ],
      ),
    );
  }

  // ─── Pending files bar ─────────────────────────────────────────────────────

  Widget _buildPendingFilesBar(List<File> files) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          12, 10, 12, MediaQuery.of(context).padding.bottom + 10),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border:
            Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.attach_file_rounded,
                  size: 14, color: AppTheme.primary),
              const SizedBox(width: 6),
              Text(
                '${files.length} file${files.length > 1 ? 's' : ''} ready to send',
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              TextButton(
                onPressed: () => ref
                    .read(messagesProvider(_args).notifier)
                    .clearPendingFiles(),
                child: Text('Clear all',
                    style: AppTheme.caption.copyWith(
                        color: AppTheme.danger,
                        fontWeight: FontWeight.w600)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 80,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: files.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final f = files[i];
                final name = f.uri.pathSegments.last;
                final ext = name.contains('.')
                    ? name.split('.').last.toUpperCase()
                    : 'FILE';
                return Stack(
                  children: [
                    Container(
                      width: 100,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.bgElevated,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: AppTheme.primary.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(
                                ext.length > 3 ? ext.substring(0, 3) : ext,
                                style: TextStyle(
                                  color: AppTheme.primary,
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            name,
                            style: AppTheme.caption.copyWith(fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                    Positioned(
                      top: 4,
                      right: 4,
                      child: GestureDetector(
                        onTap: () => ref
                            .read(messagesProvider(_args).notifier)
                            .removePendingFile(i),
                        child: Container(
                          width: 20,
                          height: 20,
                          decoration: BoxDecoration(
                            color: AppTheme.danger,
                            shape: BoxShape.circle,
                            border:
                                Border.all(color: Colors.white, width: 1.5),
                          ),
                          child: const Icon(Icons.close_rounded,
                              color: Colors.white, size: 10),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ─── Message list ──────────────────────────────────────────────────────────

  Widget _buildMessageList(MessagesState state) {
    if (state.isLoading && state.messages.isEmpty) {
      return ListView.builder(
        reverse: true,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        itemCount: 7,
        itemBuilder: (_, __) => const _SkeletonBubble(),
      );
    }

    if (!state.isLoading && state.messages.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: AppTheme.bgElevated,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(Icons.chat_bubble_outline_rounded,
                  size: 30, color: AppTheme.textDim),
            ),
            const SizedBox(height: 16),
            Text('No messages yet',
                style: AppTheme.bodyMedium
                    .copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Be the first to say something!',
                style: AppTheme.caption),
          ],
        ),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      itemCount: state.messages.length + (state.hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.messages.length) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: state.isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppTheme.primary),
                    )
                  : const SizedBox.shrink(),
            ),
          );
        }

        final msg = state.messages[index];
        final next = index + 1 < state.messages.length
            ? state.messages[index + 1]
            : null;
        final prev = index > 0 ? state.messages[index - 1] : null;
        final showHeader = next == null || next.senderId != msg.senderId;
        final showTime = prev == null || prev.senderId != msg.senderId;

        return _MessageBubble(
          message: msg,
          showHeader: showHeader,
          showTime: showTime,
          onOpenAttachment: _onOpenAttachment,
        );
      },
    );
  }

  // ── Attachment tap handler ─────────────────────────────────────────────────

  void _onOpenAttachment(ChatMessage msg, MessageAttachment attachment) {
    if (attachment.isImage) {
      // Collect all image attachments in the message for gallery swipe.
      final images =
          msg.attachments.where((a) => a.isImage).toList();
      final idx = images.indexOf(attachment);
      showImagePreview(context, attachments: images, initialIndex: idx);
    } else {
      // Non-image: download + open with system app.
      _downloadAndOpen(attachment);
    }
  }

  // ─── Input area ────────────────────────────────────────────────────────────

  Widget _buildInputArea(MessagesState state) {
    final isDisabled = widget.room.isClosedFor;

    return Container(
      padding: EdgeInsets.only(
        left: 12,
        right: 12,
        top: 10,
        bottom: MediaQuery.of(context).padding.bottom + 10,
      ),
      decoration: BoxDecoration(
        color: AppTheme.bgCard,
        border: Border(top: BorderSide(color: AppTheme.border)),
      ),
      child: isDisabled
          ? Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.lock_rounded,
                      size: 14, color: AppTheme.textDim),
                  const SizedBox(width: 6),
                  Text('This conversation is closed',
                      style: AppTheme.caption),
                ],
              ),
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Attach button
                GestureDetector(
                  onTap: state.isSending ? null : _pickFiles,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: state.pendingFiles.isNotEmpty
                          ? AppTheme.primary.withValues(alpha: 0.12)
                          : AppTheme.bgElevated,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: state.pendingFiles.isNotEmpty
                            ? AppTheme.primary
                            : AppTheme.border.withValues(alpha: 0.6),
                        width: state.pendingFiles.isNotEmpty ? 1.5 : 1,
                      ),
                    ),
                    child: Icon(
                      Icons.attach_file_rounded,
                      color: state.pendingFiles.isNotEmpty
                          ? AppTheme.primary
                          : AppTheme.textDim,
                      size: 22,
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Text input
                Expanded(
                  child: Container(
                    constraints: const BoxConstraints(maxHeight: 120),
                    decoration: BoxDecoration(
                      color: AppTheme.bgElevated,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppTheme.border),
                    ),
                    child: TextField(
                      controller: _msgController,
                      focusNode: _focusNode,
                      style: AppTheme.bodyMedium,
                      maxLines: null,
                      minLines: 1,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: 'Type a message…',
                        hintStyle: AppTheme.bodyMedium
                            .copyWith(color: AppTheme.textDim),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        border: InputBorder.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Send button
                GestureDetector(
                  onTap: state.isSending ? null : _sendMessage,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      gradient: state.isSending
                          ? null
                          : const LinearGradient(
                              colors: [
                                Color(0xFF6366F1),
                                Color(0xFF8B5CF6)
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                      color:
                          state.isSending ? AppTheme.bgElevated : null,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: state.isSending
                        ? const Center(
                            child: SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: AppTheme.primary),
                            ),
                          )
                        : const Icon(Icons.send_rounded,
                            color: Colors.white, size: 20),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _iconBtn(IconData icon) {
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: AppTheme.border),
      ),
      child: Icon(icon, color: AppTheme.textMuted, size: 17),
    );
  }

  static List<Color> _avatarColors(String id) {
    const palettes = [
      [Color(0xFF6366F1), Color(0xFF8B5CF6)],
      [Color(0xFFEC4899), Color(0xFFF43F5E)],
      [Color(0xFF3B82F6), Color(0xFF06B6D4)],
      [Color(0xFF10B981), Color(0xFF059669)],
      [Color(0xFFF59E0B), Color(0xFFEF4444)],
    ];
    return palettes[id.hashCode.abs() % palettes.length];
  }
}

// ─── XMPP status dot ──────────────────────────────────────────────────────────

class _XmppStatusDot extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final svc = ref.watch(xmppServiceProvider);
    final connected = svc.state == XmppState.connected;
    return Padding(
      padding: const EdgeInsets.only(left: 6),
      child: Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: connected ? AppTheme.success : AppTheme.textDim,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

// ─── Message Bubble ──────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.showHeader,
    required this.showTime,
    required this.onOpenAttachment,
  });

  final ChatMessage message;
  final bool showHeader;
  final bool showTime;
  final void Function(ChatMessage, MessageAttachment) onOpenAttachment;

  static const List<List<Color>> _senderColors = [
    [Color(0xFFEC4899), Color(0xFFF43F5E)],
    [Color(0xFF3B82F6), Color(0xFF06B6D4)],
    [Color(0xFF8B5CF6), Color(0xFF6366F1)],
    [Color(0xFF10B981), Color(0xFF059669)],
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: showHeader ? 10 : 3),
      child: message.isSelf ? _selfBubble(context) : _otherBubble(context),
    );
  }

  Widget _selfBubble(BuildContext context) {
    final maxW = MediaQuery.of(context).size.width * 0.78;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (message.hasAttachments)
                ...message.attachments.map(
                  (a) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: _AttachmentCard(
                        attachment: a,
                        isSelf: true,
                        onTap: () => onOpenAttachment(message, a)),
                  ),
                ),
              if (message.msg.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: const BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      topRight: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                      bottomRight: Radius.circular(4),
                    ),
                  ),
                  child: Text(
                    message.msg,
                    style: AppTheme.bodyMedium
                        .copyWith(color: Colors.white, height: 1.45),
                  ),
                ),
            ],
          ),
        ),
        if (showTime) ...[
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text(message.formattedTime, style: AppTheme.caption),
          ),
        ],
      ],
    );
  }

  Widget _otherBubble(BuildContext context) {
    final colors =
        _senderColors[message.senderId.hashCode.abs() % _senderColors.length];
    final maxW = MediaQuery.of(context).size.width * 0.78;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        SizedBox(
          width: 34,
          child: showHeader
              ? Container(
                  width: 30,
                  height: 30,
                  margin: const EdgeInsets.only(right: 4),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                        colors: colors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Center(
                    child: Text(
                      message.senderInitials,
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 4),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (showHeader) ...[
                Row(
                  children: [
                    Text(
                      message.senderName,
                      style: AppTheme.bodySmall
                          .copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 6),
                    Text(message.formattedTime, style: AppTheme.caption),
                  ],
                ),
                const SizedBox(height: 4),
              ],
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxW),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (message.hasAttachments)
                      ...message.attachments.map(
                        (a) => Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: _AttachmentCard(
                              attachment: a,
                              isSelf: false,
                              onTap: () => onOpenAttachment(message, a)),
                        ),
                      ),
                    if (message.msg.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: AppTheme.bgElevated,
                          border: Border.all(color: AppTheme.border),
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(16),
                            bottomLeft: Radius.circular(16),
                            bottomRight: Radius.circular(16),
                          ),
                        ),
                        child: Text(
                          message.msg,
                          style: AppTheme.bodyMedium.copyWith(height: 1.45),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Attachment Card ──────────────────────────────────────────────────────────

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({
    required this.attachment,
    required this.isSelf,
    required this.onTap,
  });

  final MessageAttachment attachment;
  final bool isSelf;
  final VoidCallback onTap;

  static const Map<String, List<Color>> _typeColors = {
    'PDF': [Color(0xFFEF4444), Color(0x26EF4444), Color(0x4CEF4444)],
    'DOC': [Color(0xFF3B82F6), Color(0x263B82F6), Color(0x4C3B82F6)],
    'DOCX': [Color(0xFF3B82F6), Color(0x263B82F6), Color(0x4C3B82F6)],
    'XLS': [Color(0xFF10B981), Color(0x2610B981), Color(0x4C10B981)],
    'XLSX': [Color(0xFF10B981), Color(0x2610B981), Color(0x4C10B981)],
    'PNG': [Color(0xFFA78BFA), Color(0x26A78BFA), Color(0x4CA78BFA)],
    'JPG': [Color(0xFFA78BFA), Color(0x26A78BFA), Color(0x4CA78BFA)],
    'JPEG': [Color(0xFFA78BFA), Color(0x26A78BFA), Color(0x4CA78BFA)],
    'WEBP': [Color(0xFFA78BFA), Color(0x26A78BFA), Color(0x4CA78BFA)],
    'GIF': [Color(0xFFA78BFA), Color(0x26A78BFA), Color(0x4CA78BFA)],
    'ZIP': [Color(0xFF60A5FA), Color(0x2660A5FA), Color(0x4C60A5FA)],
    'MP4': [Color(0xFFF59E0B), Color(0x26F59E0B), Color(0x4CF59E0B)],
    'MP3': [Color(0xFF06D6A0), Color(0x2606D6A0), Color(0x4C06D6A0)],
  };

  @override
  Widget build(BuildContext context) {
    final type = attachment.displayType;
    final colors = _typeColors[type] ??
        [AppTheme.primary, AppTheme.bgElevated, AppTheme.textDim];
    final (iconColor, iconBg) = (colors[0], colors[1]);

    const cardBg = AppTheme.bgCard;
    final borderColor = isSelf
        ? AppTheme.primary.withValues(alpha: 0.3)
        : AppTheme.border.withValues(alpha: 0.6);

    // For images, show a thumbnail hint via the type label.
    final isImage = attachment.isImage;
    final actionIcon = isImage
        ? Icons.zoom_in_rounded
        : Icons.download_rounded;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // File type icon
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: iconBg,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                    color: iconColor.withValues(alpha: 0.3), width: 1),
              ),
              child: Center(
                child: Text(
                  type,
                  style: TextStyle(
                    color: iconColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            // File name & size
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    attachment.originalName,
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (attachment.fileSize != null &&
                      attachment.fileSize!.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(Icons.insert_drive_file_rounded,
                            size: 12, color: AppTheme.textDim),
                        const SizedBox(width: 4),
                        Text(
                          attachment.fileSize!,
                          style: AppTheme.caption.copyWith(
                              color: AppTheme.textDim,
                              fontWeight: FontWeight.w500,
                              fontSize: 12),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            // Action icon (zoom for images, download for docs)
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isSelf
                    ? AppTheme.primary.withValues(alpha: 0.08)
                    : AppTheme.bgElevated.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelf
                      ? AppTheme.primary.withValues(alpha: 0.2)
                      : AppTheme.border.withValues(alpha: 0.4),
                  width: 1,
                ),
              ),
              child: Icon(
                actionIcon,
                size: 18,
                color: isSelf ? AppTheme.primary : AppTheme.textDim,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Skeleton ────────────────────────────────────────────────────────────────

class _SkeletonBubble extends StatelessWidget {
  const _SkeletonBubble();

  @override
  Widget build(BuildContext context) {
    final isSelf = DateTime.now().millisecond % 3 == 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        mainAxisAlignment:
            isSelf ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: [
          if (!isSelf)
            Container(
              width: 30,
              height: 30,
              margin: const EdgeInsets.only(right: 8),
              decoration: BoxDecoration(
                  color: AppTheme.bgElevated,
                  borderRadius: BorderRadius.circular(15)),
            ),
          Container(
            height: 40,
            width: 160 + (DateTime.now().second % 80).toDouble(),
            decoration: BoxDecoration(
              color: AppTheme.bgElevated,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ],
      ),
    );
  }
}
