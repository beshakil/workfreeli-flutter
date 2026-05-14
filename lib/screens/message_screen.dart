import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/config/app_config.dart';
import '../core/models/conversation_models.dart';
import '../features/calls/call_signaling_service.dart';
import '../features/calls/calls_providers.dart';
import '../features/calls/jitsi_service.dart';
import '../features/conversations/conversations_providers.dart';
import '../features/files/files_service.dart';
import '../features/user/user_providers.dart';
import '../features/xmpp/xmpp_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/image_preview_screen.dart';
import '../widgets/file_tags_display.dart';
import 'chats/chat_action.dart';
import 'chats/chat_file_action.dart';
import 'chats/chat_input_widget.dart';
import 'chats/user_profile_view.dart';
import 'chats/chat_sidebar.dart';

class MessageScreen extends ConsumerStatefulWidget {
  const MessageScreen({super.key, required this.room, required this.selfId});

  final Room room;
  final String selfId;

  @override
  ConsumerState<MessageScreen> createState() => _MessageScreenState();
}

class _MessageScreenState extends ConsumerState<MessageScreen> {
  final _msgController = TextEditingController();
  final _headerSearchController = TextEditingController();
  final _scrollController = ScrollController();
  final _headerSearchFocus = FocusNode();
  final _focusNode = FocusNode();

  bool _hasText = false;
  bool _showChatSidebar = false;
  bool _showDateChip = false;
  String _currentDateChip = '';
  Timer? _dateChipHideTimer;
  bool _showScrollButton = false;

  StreamSubscription<XmppEvent>? _xmppSub;

  // Cached notifier references so callbacks and dispose() never touch `ref`
  // directly. Riverpod invalidates `ref` in _ConsumerElement.unmount() which
  // runs *before* Flutter calls our dispose(), making any ref.read() there
  // throw "Cannot use ref after the widget was disposed".
  StateController<String?>? _activeRoomIdCtrl;
  MessagesNotifier? _messagesNotifier;

  MsgArgs get _args => (
        roomId: widget.room.id,
        selfId: widget.selfId,
        companyId: widget.room.companyId ?? '',
        participantsJoined: widget.room.participants.join(','),
      );

  @override
  void initState() {
    super.initState();
    _msgController.addListener(_onTextChanged);
    // header search text will update provider via TextField onChanged
    _scrollController.addListener(_onScroll);

    // Cache notifiers during initState when ref is guaranteed valid.
    _activeRoomIdCtrl = ref.read(activeRoomIdProvider.notifier);
    _messagesNotifier = ref.read(messagesProvider(_args).notifier);

    // Subscribe directly to the XMPP broadcast stream.
    // Using a StreamSubscription in initState() is more reliable than
    // ref.listen in build(): it fires for every event regardless of rebuild
    // scheduling and cannot miss rapid successive events.
    _xmppSub = XmppService.instance.events.listen((event) {
      if (!mounted) return;
      _handleXmppEvent(event);
    });
    debugPrint(
        '[MessageScreen] XMPP subscription started for room ${widget.room.id}');

    // Mark this conversation as active so unread stops incrementing.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _activeRoomIdCtrl?.state = widget.room.id;
      ref.read(unreadCountsProvider.notifier).reset(widget.room.id);
      // Tell the backend the user has read all messages.
      ConversationsService.readAll(widget.room.id).catchError((_) {});

      // Compute initial date chip so it's ready when user scrolls.
      _updateDateChip();
    });

    // Keep header search controller in sync with provider and focus when activated
    // Listener moved to build() because ref.listen must be used within build.
  }

  @override
  void dispose() {
    _msgController.removeListener(_onTextChanged);
    // no explicit listener to remove; TextField handles updates
    _xmppSub?.cancel();
    _dateChipHideTimer?.cancel();
    debugPrint(
        '[MessageScreen] XMPP subscription cancelled for room ${widget.room.id}');

    // Use cached controller — ref is already invalid here because Riverpod's
    // _ConsumerElement.unmount() runs before Flutter calls dispose().
    _activeRoomIdCtrl?.state = null;

    _msgController.dispose();
    _headerSearchController.dispose();
    _scrollController
      ..removeListener(_onScroll)
      ..dispose();
    _headerSearchFocus.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onTextChanged() {
    final hasText = _msgController.text.isNotEmpty;
    if (hasText != _hasText) {
      setState(() => _hasText = hasText);
    }
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final position = _scrollController.position;
      // With reverse=true:
      // - pixels = 0 → bottom of list (newest messages)
      // - pixels = maxScrollExtent → top of list (oldest messages)
      // When user scrolls UP to see old messages, pixels INCREASE
      final isAtBottom = position.pixels <= 50; // At newest messages
      final showButton = position.pixels > 200 && !isAtBottom; // Show when viewing old messages
      
      if (showButton != _showScrollButton) {
        setState(() {
          _showScrollButton = showButton;
        });
      }
    }

    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 300) {
      _messagesNotifier?.loadMore();
    }
  }

  void _updateDateChip() {
    if (!mounted || !_scrollController.hasClients) return;

    final state = ref.read(messagesProvider(_args));
    final activeFilter = ref.read(activeFilterProvider(widget.room.id));
    final searchQuery = ref.read(activeSearchQueryProvider(widget.room.id));
    final visible = _applyFilterToList(state.messages, activeFilter, searchQuery);
    if (visible.isEmpty) return;

    final scrollOffset = _scrollController.offset;
    final viewportHeight = _scrollController.position.viewportDimension;
    final maxScroll = _scrollController.position.maxScrollExtent;

    // With reverse=true, item 0 (newest) is at the BOTTOM.
    // scrollOffset increases as we scroll toward older messages.
    //
    // totalContentExtent = maxScroll + viewportHeight
    // progress through content = (scrollOffset + viewportOffset) / totalContentExtent
    // message index ≈ progress * (messageCount - 1)
    int targetIndex;
    if (maxScroll <= 0) {
      // All messages fit — oldest is the last one.
      targetIndex = visible.length - 1;
    } else {
      final totalContentExtent = maxScroll + viewportHeight;
      // Look near the top of the viewport (oldest visible messages)
      final viewportOffset = viewportHeight * 0.8;
      final targetPosition = scrollOffset + viewportOffset;
      final progress = (targetPosition / totalContentExtent).clamp(0.0, 1.0);
      targetIndex = (progress * (visible.length - 1)).round();
    }

    targetIndex = targetIndex.clamp(0, visible.length - 1);

    final msg = visible[targetIndex];
    final dateLabel = _formatDateChip(msg.createdAt);

    if (dateLabel != _currentDateChip || !_showDateChip) {
      setState(() {
        _currentDateChip = dateLabel;
        _showDateChip = true;
      });
    }
  }

  List<ChatMessage> _applyFilterToList(List<ChatMessage> msgs, MessageFilter? f, [String? query]) {
    List<ChatMessage> filtered = msgs;
    if (f != null) {
      final key = f.key;
      bool matches(ChatMessage m) {
        final body = m.msg.toLowerCase();
        switch (key) {
          case 'messages_with_links':
            return RegExp(r'https?://').hasMatch(m.msg);
          case 'messages_with_files':
            return m.hasAttachments;
          case 'messages_with_starred_files':
            return m.attachments.any((a) => a.tags.any((t) => t.title.toLowerCase().contains('star')));
          case 'private_messages':
            return m.msgType.toLowerCase() == 'private';
          case 'messages_with_titles':
            return m.msg.contains('\n');
          case 'threaded_messages':
          case 'new_unread_messages':
          case 'flagged_messages':
          default:
            return false;
        }
      }

      filtered = msgs.where(matches).toList();
    }

    if (query != null && query.trim().isNotEmpty) {
      final q = query.toLowerCase();
      filtered = filtered.where((m) {
        return m.msg.toLowerCase().contains(q) || m.senderName.toLowerCase().contains(q);
      }).toList();
    }

    return filtered;
  }

  String _formatDateChip(String createdAt) {
    try {
      final dt = DateTime.tryParse(createdAt) ??
          DateTime.fromMillisecondsSinceEpoch(int.tryParse(createdAt) ?? 0);
      final localDt = dt.toLocal();
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final messageDay = DateTime(localDt.year, localDt.month, localDt.day);
      final diff = today.difference(messageDay).inDays;

      if (diff == 0) return 'Today';
      if (diff == 1) return 'Yesterday';
      if (diff < 7) {
        // Show day name (Monday, Tuesday, etc.)
        return DateFormat('EEEE').format(localDt);
      }
      // Show full date
      return DateFormat('dd MMM yyyy').format(localDt);
    } catch (_) {
      return 'Today';
    }
  }

  // ── Call initiation ───────────────────────────────────────────────────────

  Future<void> _startCall({required bool isVideo}) async {
    final me = ref.read(meProvider).valueOrNull;
    if (me == null) return;

    final granted = await JitsiService.requestCallPermissions();
    if (!granted) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Camera and microphone permissions are required.')),
        );
      }
      return;
    }

    try {
      final jwt = await CallSignalingService.startCall(
        userId: widget.selfId,
        conversationId: widget.room.id,
        convTitle: widget.room.title,
        participants: widget.room.participants,
        companyId: widget.room.companyId ?? me.companyId,
        isGroup: widget.room.isGroup,
      );

      if (jwt == null || jwt.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to start call.')),
          );
        }
        return;
      }

      final convId = widget.room.id;
      final fullName = '${me.firstname} ${me.lastname}'.trim();

      await JitsiService.join(
        conversationId: convId,
        jwtToken: jwt,
        isVideo: isVideo,
        userName: fullName,
        userEmail: me.email,
        userAvatar: me.img,
        onReadyToClose: () async {
          try {
            await CallSignalingService.hangupCall(
              userId: widget.selfId,
              userFullName: fullName,
              conversationId: convId,
            );
          } catch (_) {}
          if (mounted) ref.invalidate(callHistoryProvider);
        },
      );
    } catch (e) {
      debugPrint('[MessageScreen] Call failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Call failed: $e')),
        );
      }
    }
  }

  // ── XMPP online check ─────────────────────────────────────────────────────

  bool get _xmppOnline =>
      ref.read(xmppServiceProvider).state == XmppState.connected;

  // ── XMPP real-time injection ──────────────────────────────────────────────

  void _handleXmppEvent(XmppEvent event) {
    debugPrint(
        '[MessageScreen] ← XMPP event type="${event.type}" room="${widget.room.id}"');

    if (event.type != 'new_message' && event.type != 'new_reply_message') {
      debugPrint('[MessageScreen]   ignored (not a message event)');
      return;
    }

    final convId = event.data['conversation_id']?.toString() ??
        event.data['conv_id']?.toString() ??
        '';
    final senderId = event.data['sender']?.toString() ??
        event.data['user_id']?.toString() ??
        '';
    final msgId = event.data['msg_id']?.toString() ?? '';

    debugPrint(
        '[MessageScreen]   conv_id="$convId" sender="$senderId" msg_id="$msgId"');
    debugPrint(
        '[MessageScreen]   selfId="${widget.selfId}" activeRoom="${widget.room.id}"');

    if (convId.isNotEmpty && convId != widget.room.id) {
      debugPrint('[MessageScreen]   ignored (different room: $convId)');
      return;
    }

    // Skip XMPP echo of own messages — the GraphQL mutation already prepended
    // the message to state. addRealTimeMessage() also deduplicates by msg_id
    // as a safety net in case the echo arrives before the mutation response.
    if (senderId == widget.selfId) {
      debugPrint('[MessageScreen]   ignored (own message echo)');
      return;
    }

    final msg = MessagesNotifier.parseXmppMessage(
        event.data, widget.selfId, widget.room.id);
    if (msg == null) {
      debugPrint(
          '[MessageScreen]   parseXmppMessage returned null — dropping event');
      return;
    }

    debugPrint('[MessageScreen]   injecting real-time message id="${msg.id}"');
    _messagesNotifier?.addRealTimeMessage(msg);
    _scrollToTop();
  }

  // ── Send message callback (used by ChatInputWidget) ────────────────────────

  void _handleSendMessage() {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    // Log XMPP state but NEVER block the send — messages are stored in the
    // backend via GraphQL regardless of XMPP state. XMPP is only the real-time
    // delivery channel; blocking here would prevent sends whenever XMPP is
    // still establishing its connection.
    if (!_xmppOnline) {
      debugPrint(
          '[MessageScreen] XMPP not connected — message will be sent via GraphQL but real-time push may be delayed');
    }

    _msgController.clear();
    _messagesNotifier?.sendMessage(text);
    _scrollToTop();
  }

  void _scrollToTop() {
    // With reverse=true, pixel 0 is the BOTTOM (newest messages)
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
    final activeFilter = ref.watch(activeFilterProvider(widget.room.id));
    final searchQuery = ref.watch(activeSearchQueryProvider(widget.room.id));

    // Sync header search controller with provider and manage focus when activated
    ref.listen<String?>(activeSearchQueryProvider(widget.room.id), (prev, next) {
      if (!mounted) return;
      if (next == null) {
        _headerSearchController.clear();
        _headerSearchFocus.unfocus();
      } else {
        if (_headerSearchController.text != next) {
          _headerSearchController.text = next;
        }
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _headerSearchFocus.requestFocus();
        });
      }
    });

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Stack(
        children: [
          Column(
            children: [
              _buildHeader(context),
              if (state.error != null) _buildErrorBanner(state.error!),
              Expanded(child: _buildMessageList(state)),
              if (state.pendingFiles.isNotEmpty)
                _buildPendingFilesBar(state.pendingFiles),
              ChatInputWidget(
                room: widget.room,
                selfId: widget.selfId,
                msgController: _msgController,
                focusNode: _focusNode,
                hasText: _hasText,
                onSendMessage: _handleSendMessage,
                onTextChanged: _onTextChanged,
              ),
            ],
          ),
          // Floating filter chip (above date chip)
          if (activeFilter != null) _buildFilterChip(activeFilter),
          // Floating date chip
          if (_showDateChip && _currentDateChip.isNotEmpty) _buildDateChip(),
          // Floating scroll button
          if (_showScrollButton) _buildScrollButton(),
          // Chat Sidebar
          if (_showChatSidebar)
            ChatSidebar(
              onClose: () {
                setState(() {
                  _showChatSidebar = false;
                });
              },
              room: widget.room,
            ),
        ],
      ),
    );
  }

  Widget _buildDateChip() {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 100,
      left: 0,
      right: 0,
      child: Center(
        child: AnimatedOpacity(
          opacity: _showDateChip ? 1.0 : 0.0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Text(
              _currentDateChip,
              style: AppTheme.bodySmall.copyWith(
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(MessageFilter filter) {
    return Positioned(
      top: MediaQuery.of(context).padding.top + 60,
      left: 16,
      right: 16,
      child: Center(
        child: AnimatedOpacity(
          opacity: 1.0,
          duration: const Duration(milliseconds: 200),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(filter.icon, size: 16, color: AppTheme.textPrimary),
                const SizedBox(width: 8),
                Text(filter.label, style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w600, color: AppTheme.textPrimary)),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    ref.read(activeFilterProvider(widget.room.id).notifier).state = null;
                  },
                  child: const Icon(Icons.close_rounded, size: 16, color: AppTheme.textPrimary),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildScrollButton() {
    return Positioned(
      bottom: 100,
      right: 16,
      child: AnimatedOpacity(
        opacity: _showScrollButton ? 1.0 : 0.0,
        duration: const Duration(milliseconds: 200),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _scrollToTop, // Scrolls to newest messages (bottom with reverse=true)
            borderRadius: BorderRadius.circular(24),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: const Icon(
                Icons.arrow_downward_rounded,
                color: AppTheme.primary,
                size: 22,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ─── Header ────────────────────────────────────────────────────────────────

  Widget _buildHeader(BuildContext context) {
    final searchQuery = ref.watch(activeSearchQueryProvider(widget.room.id));
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
      child: searchQuery != null
          ? Row(
              children: [
                IconButton(
                  onPressed: () {
                    // Close search and clear query
                    ref.read(activeSearchQueryProvider(widget.room.id).notifier).state = null;
                    _headerSearchController.clear();
                  },
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppTheme.textMuted, size: 20),
                ),
                _buildHeaderAvatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: SizedBox(
                    height: 40,
                    child: TextField(
                      controller: _headerSearchController,
                      focusNode: _headerSearchFocus,
                      style: AppTheme.bodyMedium,
                      decoration: InputDecoration(
                        hintText: 'Search messages…',
                        hintStyle: AppTheme.bodyMedium.copyWith(color: AppTheme.textDim),
                        prefixIcon: const Icon(Icons.search_rounded, size: 18, color: AppTheme.textDim),
                        suffixIcon: (searchQuery != null && searchQuery.isNotEmpty)
                            ? GestureDetector(
                                onTap: () {
                                  _headerSearchController.clear();
                                  ref.read(activeSearchQueryProvider(widget.room.id).notifier).state = '';
                                },
                                child: const Icon(Icons.close_rounded, color: AppTheme.textDim, size: 18),
                              )
                            : null,
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 10),
                        filled: true,
                        fillColor: AppTheme.bgElevated,
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: AppTheme.primary),
                        ),
                      ),
                      onChanged: (v) => ref.read(activeSearchQueryProvider(widget.room.id).notifier).state = v,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() => _showChatSidebar = true);
                  },
                  child: _iconBtn(Icons.more_vert_rounded),
                ),
              ],
            )
          : Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: AppTheme.textMuted, size: 20),
                ),
                // Room avatar (image or initials) - matching chat_sidebar.dart
                _buildHeaderAvatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => showUserProfileModal(context, room: widget.room),
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
                ),
                GestureDetector(
                  onTap: () => _startCall(isVideo: false),
                  child: _iconBtn(Icons.phone_rounded),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _startCall(isVideo: true),
                  child: _iconBtn(Icons.videocam_rounded),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _showChatSidebar = true;
                    });
                  },
                  child: _iconBtn(Icons.more_vert_rounded),
                ),
              ],
            ),
    );
  }

  Widget _buildHeaderAvatar() {
    final colors = _avatarColors(widget.room.id);
    final isGroup = widget.room.isGroup;
    final img = widget.room.convImg;
    final hasValidUrl = img != null &&
        img.isNotEmpty &&
        (img.startsWith('http://') || img.startsWith('https://'));

    // If room has a valid image URL, display it
    if (hasValidUrl) {
      return Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          shape: isGroup ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: isGroup ? BorderRadius.circular(11) : null,
        ),
        child: ClipRRect(
          borderRadius:
              isGroup ? BorderRadius.circular(11) : BorderRadius.circular(19),
          child: CachedNetworkImage(
            imageUrl: img,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: colors,
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: isGroup ? BoxShape.rectangle : BoxShape.circle,
                borderRadius: isGroup ? BorderRadius.circular(11) : null,
              ),
              child: Center(
                child: Text(
                  widget.room.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            errorWidget: (context, url, error) =>
                _buildHeaderInitialsAvatar(colors, isGroup),
          ),
        ),
      );
    }

    // Fallback to gradient with initials
    return _buildHeaderInitialsAvatar(colors, isGroup);
  }

  Widget _buildHeaderInitialsAvatar(List<Color> colors, bool isGroup) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: isGroup ? BoxShape.rectangle : BoxShape.circle,
        borderRadius: isGroup ? BorderRadius.circular(11) : null,
      ),
      child: Center(
        child: Text(
          widget.room.initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
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
        border: Border(top: BorderSide(color: AppTheme.border, width: 0.5)),
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
                        color: AppTheme.danger, fontWeight: FontWeight.w600)),
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
                            border: Border.all(color: Colors.white, width: 1.5),
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
                style:
                    AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 4),
            Text('Be the first to say something!', style: AppTheme.caption),
          ],
        ),
      );
    }

    final activeFilter = ref.watch(activeFilterProvider(widget.room.id));
    final searchQuery = ref.watch(activeSearchQueryProvider(widget.room.id));
    final visibleMessages = _applyFilterToList(state.messages, activeFilter, searchQuery);

    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        // Update date chip on any scroll movement
        if (notification is ScrollUpdateNotification ||
            notification is OverscrollNotification ||
            notification is UserScrollNotification ||
            notification is ScrollEndNotification) {
          _updateDateChip();

          // Reset hide timer on scroll
          _dateChipHideTimer?.cancel();
          _dateChipHideTimer = Timer(const Duration(seconds: 2), () {
            if (mounted) {
              setState(() => _showDateChip = false);
            }
          });
        }
        return false;
      },
      child: ListView.builder(
        controller: _scrollController,
        reverse: true,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        itemCount: visibleMessages.length + (state.hasMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index == visibleMessages.length) {
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

          final msg = visibleMessages[index];
          final next = index + 1 < visibleMessages.length
              ? visibleMessages[index + 1]
              : null;
          final showHeader = next == null || next.senderId != msg.senderId;

          return _MessageBubble(
            message: msg,
            showHeader: showHeader,
            onOpenAttachment: _onOpenAttachment,
            onShowUserProfile: _showUserProfile,
          );
        },
      ),
    );
  }

  // ── Attachment tap handler ─────────────────────────────────────────────────

  void _onOpenAttachment(ChatMessage msg, MessageAttachment attachment) {
    if (attachment.isImage) {
      // Collect all image attachments in the message for gallery swipe.
      final images = msg.attachments.where((a) => a.isImage).toList();
      final idx = images.indexOf(attachment);
      showImagePreview(context, attachments: images, initialIndex: idx);
    } else {
      // Non-image: download + open with system app.
      _downloadAndOpen(attachment);
    }
  }

  void _showUserProfile(ChatMessage msg) {
    // For group chats, show the sender's profile
    // For direct messages, show the room profile (which is the other person)
    if (widget.room.isGroup) {
      // Create a temporary Room object for the sender
      final senderRoom = Room(
        id: msg.senderId,
        title: msg.senderName,
        isGroup: false,
        participants: [msg.senderId],
        convImg: msg.senderImg,
      );
      showUserProfileModal(context, room: senderRoom);
    } else {
      // For DM, show the current room profile
      showUserProfileModal(context, room: widget.room);
    }
  }

  Widget _iconBtn(IconData icon) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: AppTheme.bgElevated,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border),
      ),
      child: Icon(icon, color: AppTheme.textMuted, size: 20),
    );
  }

  static List<Color> _avatarColors(String id) {
    const palettes = [
      [Color(0xFF6366F1), Color(0xFF8B5CF6)],
      [Color(0xFFEC4899), Color(0xFFF43F5E)],
      [Color(0xFF3B82F6), Color(0xFF06B6D4)],
      [Color(0xFF10B981), Color(0xFF059669)],
      [Color(0xFFF59E0B), Color(0xFFD97706)],
      [Color(0xFFEF4444), Color(0xFFDC2626)],
    ];
    final index = id.hashCode % palettes.length;
    final palette = palettes[index];
    return [palette[0], palette[1]];
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
    required this.onOpenAttachment,
    this.onShowUserProfile,
  });

  final ChatMessage message;
  final bool showHeader;
  final void Function(ChatMessage, MessageAttachment) onOpenAttachment;
  final void Function(ChatMessage)? onShowUserProfile;

  static const List<List<Color>> _senderColors = [
    [Color(0xFFEC4899), Color(0xFFF43F5E)],
    [Color(0xFF3B82F6), Color(0xFF06B6D4)],
    [Color(0xFF8B5CF6), Color(0xFF6366F1)],
    [Color(0xFF10B981), Color(0xFF059669)],
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: showHeader ? 12 : 10),
      child: message.isSelf ? _selfBubble(context) : _otherBubble(context),
    );
  }

  void _showMessageActions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ChatActionModal(
        messageText: message.msg,
        isOwnMessage: message.isSelf,
      ),
    );
  }

  // Renders one attachment: image → inline thumbnail, other → file card.
  Widget _buildAttachment(
      MessageAttachment a, bool isSelf, BuildContext context) {
    if (a.isImage) {
      return _ImageThumbnail(
        attachment: a,
        isSelf: isSelf,
        onTap: () => onOpenAttachment(message, a),
        onLongPress: () => _showFileActions(context, a),
        message: message,
      );
    }
    return _AttachmentCard(
      attachment: a,
      isSelf: isSelf,
      onTap: () => onOpenAttachment(message, a),
      onLongPress: () => _showFileActions(context, a),
      message: message,
    );
  }

  void _showFileActions(BuildContext context, MessageAttachment attachment) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => ChatFileActionModal(
        fileName: attachment.originalName,
        fileSize: attachment.fileSize ?? 'Unknown',
        uploadTime: message.formattedTime.split(' ')[0], // Extract date part
        isImage: attachment.isImage,
        fileUrl: attachment.downloadUrl(AppConfig.fileBaseUrl),
      ),
    );
  }

  Widget _selfBubble(BuildContext context) {
    return GestureDetector(
      onLongPress: () => _showMessageActions(context),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: MediaQuery.of(context).size.width * 0.78,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (message.hasAttachments)
                  ...message.attachments.map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: _buildAttachment(a, true, context),
                    ),
                  ),
                if (message.hasAttachments && message.msg.isNotEmpty)
                  const SizedBox(height: 8),
                if (message.msg.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.only(
                        topLeft: Radius.circular(16),
                        topRight: Radius.circular(16),
                        bottomLeft: Radius.circular(16),
                        bottomRight: Radius.circular(4),
                      ),
                    ),
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final textStyle = AppTheme.bodyMedium.copyWith(
                            color: AppTheme.textPrimary,
                            height: 1.45,
                            fontSize: 15);
                        final tsStyle = AppTheme.caption.copyWith(
                          color: AppTheme.textDim,
                          fontSize: 10,
                        );

                        final textPainter = TextPainter(
                          text: TextSpan(text: message.msg, style: textStyle),
                          maxLines: 1,
                          textDirection: Directionality.of(context),
                        )..layout();
                        final tsPainter = TextPainter(
                          text: TextSpan(
                              text: message.formattedTime, style: tsStyle),
                          maxLines: 1,
                          textDirection: Directionality.of(context),
                        )..layout();

                        final fitsInline = !textPainter.didExceedMaxLines &&
                            textPainter.width + 4 + tsPainter.width <=
                                constraints.maxWidth;
                        final tsHeight = tsPainter.height;

                        textPainter.dispose();
                        tsPainter.dispose();

                        if (fitsInline) {
                          return Wrap(
                            crossAxisAlignment: WrapCrossAlignment.end,
                            children: [
                              Text(message.msg, style: textStyle),
                              const SizedBox(width: 4),
                              Text(message.formattedTime, style: tsStyle),
                            ],
                          );
                        }

                        return Stack(
                          children: [
                            Padding(
                              padding: EdgeInsets.only(bottom: tsHeight + 4),
                              child: Text(message.msg, style: textStyle),
                            ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child:
                                  Text(message.formattedTime, style: tsStyle),
                            ),
                          ],
                        );
                      },
                    ),
                  ),
                if (message.msg.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, right: 4),
                    child: Text(message.formattedTime, style: AppTheme.caption),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _otherBubble(BuildContext context) {
    final colors =
        _senderColors[message.senderId.hashCode.abs() % _senderColors.length];

    return GestureDetector(
      onLongPress: () => _showMessageActions(context),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: onShowUserProfile != null && showHeader
                ? () => onShowUserProfile!(message)
                : null,
            child: SizedBox(
              width: 42,
              child: showHeader
                  ? Container(
                      width: 38,
                      height: 38,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        gradient: message.senderImg == null ||
                                message.senderImg!.isEmpty
                            ? LinearGradient(
                                colors: colors,
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight)
                            : null,
                        borderRadius: BorderRadius.circular(19),
                      ),
                      child: message.senderImg != null &&
                              message.senderImg!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(19),
                              child: CachedNetworkImage(
                                imageUrl: message.senderImg!,
                                width: 38,
                                height: 38,
                                fit: BoxFit.cover,
                                placeholder: (_, __) => Container(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: colors,
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(19),
                                  ),
                                  child: Center(
                                    child: SizedBox(
                                      width: 16,
                                      height: 16,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color:
                                            Colors.white.withValues(alpha: 0.8),
                                      ),
                                    ),
                                  ),
                                ),
                                errorWidget: (_, __, ___) => Container(
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
                                      message.senderInitials,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ),
                                ),
                              ),
                            )
                          : Center(
                              child: Text(
                                message.senderInitials,
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w600),
                              ),
                            ),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 4),
          // Use Flexible (loose) so bubble widths auto-size to content length
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (showHeader) ...[
                  GestureDetector(
                    onTap: onShowUserProfile != null
                        ? () => onShowUserProfile!(message)
                        : null,
                    child: Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: Text(
                        message.senderName,
                        style: AppTheme.bodyLarge
                            .copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ),
                  const SizedBox(height: 4),
                ],
                ConstrainedBox(
                  constraints: BoxConstraints(
                    maxWidth: MediaQuery.of(context).size.width * 0.78,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.hasAttachments)
                        ...message.attachments.map(
                          (a) => Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _buildAttachment(a, false, context),
                          ),
                        ),
                      if (message.hasAttachments && message.msg.isNotEmpty)
                        const SizedBox(height: 8),
                      if (message.msg.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: AppTheme.border),
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(4),
                              topRight: Radius.circular(16),
                              bottomLeft: Radius.circular(16),
                              bottomRight: Radius.circular(16),
                            ),
                          ),
                          child: LayoutBuilder(
                            builder: (context, constraints) {
                              final textStyle = AppTheme.bodyMedium
                                  .copyWith(height: 1.45, fontSize: 15);
                              final tsStyle =
                                  AppTheme.caption.copyWith(fontSize: 10);

                              final textPainter = TextPainter(
                                text: TextSpan(
                                    text: message.msg, style: textStyle),
                                maxLines: 1,
                                textDirection: Directionality.of(context),
                              )..layout();
                              final tsPainter = TextPainter(
                                text: TextSpan(
                                    text: message.formattedTime,
                                    style: tsStyle),
                                maxLines: 1,
                                textDirection: Directionality.of(context),
                              )..layout();

                              final fitsInline =
                                  !textPainter.didExceedMaxLines &&
                                      textPainter.width + 4 + tsPainter.width <=
                                          constraints.maxWidth;
                              final tsHeight = tsPainter.height;

                              textPainter.dispose();
                              tsPainter.dispose();

                              if (fitsInline) {
                                return Wrap(
                                  crossAxisAlignment: WrapCrossAlignment.end,
                                  children: [
                                    Text(message.msg, style: textStyle),
                                    const SizedBox(width: 4),
                                    Text(message.formattedTime, style: tsStyle),
                                  ],
                                );
                              }

                              return Stack(
                                children: [
                                  Padding(
                                    padding:
                                        EdgeInsets.only(bottom: tsHeight + 4),
                                    child: Text(message.msg, style: textStyle),
                                  ),
                                  Positioned(
                                    bottom: 0,
                                    right: 0,
                                    child: Text(message.formattedTime,
                                        style: tsStyle),
                                  ),
                                ],
                              );
                            },
                          ),
                        ),
                      if (message.msg.isEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4, right: 4),
                          child: Align(
                            alignment: Alignment.bottomRight,
                            widthFactor: message.hasAttachments ? null : 1.0,
                            child: Text(
                              message.formattedTime,
                              style: AppTheme.caption,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Attachment Card ──────────────────────────────────────────────────────────

class _AttachmentCard extends StatelessWidget {
  const _AttachmentCard({
    required this.attachment,
    required this.isSelf,
    required this.onTap,
    required this.message,
    this.onLongPress,
  });

  final MessageAttachment attachment;
  final bool isSelf;
  final VoidCallback onTap;
  final ChatMessage message;
  final VoidCallback? onLongPress;

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

    const cardBg = Colors.white;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main card content - File info with star icon
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // File Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: iconColor.withValues(alpha: 0.3), width: 1),
                  ),
                  child: attachment.isImage
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: CachedNetworkImage(
                            imageUrl:
                                attachment.downloadUrl(AppConfig.fileBaseUrl),
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Center(
                              child: SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 1.5,
                                  color: iconColor.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                            errorWidget: (_, __, ___) => Center(
                              child: Icon(
                                _getFileIcon(type),
                                color: iconColor,
                                size: 24,
                              ),
                            ),
                          ),
                        )
                      : Center(
                          child: Icon(
                            _getFileIcon(type),
                            color: iconColor,
                            size: 24,
                          ),
                        ),
                ),
                const SizedBox(width: 12),

                // Text Information (file name & size)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              attachment.originalName,
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Star/Favorite icon (top-right)
                          GestureDetector(
                            onTap: () {
                              // TODO: Implement star/favorite action
                            },
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppTheme.bgElevated,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Icon(
                                Icons.star_border_rounded,
                                size: 16,
                                color: AppTheme.textDim,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (attachment.fileSize != null &&
                          attachment.fileSize!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          attachment.fileSize!,
                          style: AppTheme.caption.copyWith(
                            color: AppTheme.textDim,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Tag display section
            if (attachment.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              TagPillsRow(tags: attachment.tags, maxVisible: 2),
            ],

            // Status Message (below the card)
            // const SizedBox(height: 10),
            // Text(
            //   'File(s) uploaded without any comment or message.',
            //   style: AppTheme.caption.copyWith(
            //     color: AppTheme.textDim,
            //     fontStyle: FontStyle.italic,
            //     fontSize: 11,
            //   ),
            // ),

            // Timestamp (bottom-right)
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  message.formattedTime,
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.textDim,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  IconData _getFileIcon(String type) {
    switch (type.toUpperCase()) {
      case 'PDF':
        return Icons.picture_as_pdf_rounded;
      case 'DOC':
      case 'DOCX':
        return Icons.description_rounded;
      case 'XLS':
      case 'XLSX':
        return Icons.table_chart_rounded;
      case 'PNG':
      case 'JPG':
      case 'JPEG':
      case 'WEBP':
      case 'GIF':
        return Icons.image_rounded;
      case 'ZIP':
        return Icons.folder_zip_rounded;
      case 'MP4':
        return Icons.video_library_rounded;
      case 'MP3':
        return Icons.audio_file_rounded;
      default:
        return Icons.insert_drive_file_rounded;
    }
  }
}

// ─── Image Thumbnail ─────────────────────────────────────────────────────────

/// Renders an image attachment as an inline thumbnail inside the chat bubble.
/// Tapping opens the fullscreen gallery via [onTap].
class _ImageThumbnail extends StatelessWidget {
  const _ImageThumbnail({
    required this.attachment,
    required this.isSelf,
    required this.onTap,
    required this.message,
    this.onLongPress,
  });

  final MessageAttachment attachment;
  final bool isSelf;
  final VoidCallback onTap;
  final ChatMessage message;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final url = attachment.downloadUrl(AppConfig.fileBaseUrl);
    final maxW = MediaQuery.of(context).size.width * 0.65;
    final type = attachment.displayType;
    final colors = _AttachmentCard._typeColors[type] ??
        [AppTheme.primary, AppTheme.bgElevated, AppTheme.textDim];
    final (iconColor, iconBg) = (colors[0], colors[1]);

    const cardBg = Colors.white;

    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 4,
              offset: const Offset(0, 1),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Main card content
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // File Icon
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: iconBg,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                        color: iconColor.withValues(alpha: 0.3), width: 1),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: CachedNetworkImage(
                      imageUrl: attachment.downloadUrl(AppConfig.fileBaseUrl),
                      width: 48,
                      height: 48,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Center(
                        child: SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            color: iconColor.withValues(alpha: 0.5),
                          ),
                        ),
                      ),
                      errorWidget: (_, __, ___) => Center(
                        child: Icon(
                          Icons.image_rounded,
                          color: iconColor,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Text Information (file name & size)
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              attachment.originalName,
                              style: AppTheme.bodyMedium.copyWith(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Star/Favorite icon (top-right)
                          GestureDetector(
                            onTap: () {
                              // TODO: Implement star/favorite action
                            },
                            child: Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: AppTheme.bgElevated,
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: AppTheme.border),
                              ),
                              child: Icon(
                                Icons.star_border_rounded,
                                size: 16,
                                color: AppTheme.textDim,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (attachment.fileSize != null &&
                          attachment.fileSize!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          attachment.fileSize!,
                          style: AppTheme.caption.copyWith(
                            color: AppTheme.textDim,
                            fontWeight: FontWeight.w500,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),

            // Tag display section
            if (attachment.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              TagPillsRow(tags: attachment.tags, maxVisible: 2),
            ],

            // Top accent border - separator between file info and actions
            // const SizedBox(height: 12),
            // Container(
            //   width: double.infinity,
            //   height: 1,
            //   decoration: BoxDecoration(
            //     color: AppTheme.border,
            //   ),
            // ),
            // const SizedBox(height: 12),

            // Bottom action icons (share and expand)
            // Row(
            //   mainAxisAlignment: MainAxisAlignment.end,
            //   children: [
            //     // Share icon
            //     GestureDetector(
            //       onTap: () {
            //         // TODO: Implement share action
            //       },
            //       child: Container(
            //         width: 28,
            //         height: 28,
            //         decoration: BoxDecoration(
            //           color: AppTheme.bgElevated,
            //           borderRadius: BorderRadius.circular(6),
            //           border: Border.all(color: AppTheme.border),
            //         ),
            //         child: Icon(
            //           Icons.share_rounded,
            //           size: 16,
            //           color: AppTheme.textDim,
            //         ),
            //       ),
            //     ),
            //     const SizedBox(width: 8),
            //     // Expand/Full Screen icon
            //     GestureDetector(
            //       onTap: onTap,
            //       child: Container(
            //         width: 28,
            //         height: 28,
            //         decoration: BoxDecoration(
            //           color: isSelf
            //               ? AppTheme.primary.withValues(alpha: 0.1)
            //               : AppTheme.bgElevated,
            //           borderRadius: BorderRadius.circular(6),
            //           border: Border.all(
            //             color: isSelf
            //                 ? AppTheme.primary.withValues(alpha: 0.3)
            //                 : AppTheme.border,
            //           ),
            //         ),
            //         child: Icon(
            //           Icons.open_in_full_rounded,
            //           size: 16,
            //           color: isSelf ? AppTheme.primary : AppTheme.textDim,
            //         ),
            //       ),
            //     ),
            //   ],
            // ),

            // Status Message (below the card)
            // const SizedBox(height: 10),
            // Text(
            //   'File(s) uploaded without any comment or message.',
            //   style: AppTheme.caption.copyWith(
            //     color: AppTheme.textDim,
            //     fontStyle: FontStyle.italic,
            //     fontSize: 12,
            //   ),
            // ),

            // Timestamp (bottom-right)
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  message.formattedTime,
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.textDim,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _placeholder(double maxW) => Container(
        width: maxW,
        height: 160,
        decoration: BoxDecoration(
          color: AppTheme.bgElevated,
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
                strokeWidth: 2, color: AppTheme.primary),
          ),
        ),
      );

  Widget _errorWidget(double maxW) => Container(
        width: maxW,
        height: 120,
        decoration: BoxDecoration(
          color: AppTheme.bgElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.broken_image_rounded,
                color: AppTheme.textDim, size: 28),
            const SizedBox(height: 6),
            Text(
              attachment.originalName,
              style: AppTheme.caption,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
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
