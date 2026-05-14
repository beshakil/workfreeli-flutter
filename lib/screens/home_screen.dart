import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/encryption/encryption_service.dart';
import '../core/models/conversation_models.dart' show Room;
import '../features/calls/calls_providers.dart';
import '../features/conversations/conversations_providers.dart';
import '../features/user/user_providers.dart';
import '../features/xmpp/xmpp_provider.dart';
import '../services/call_notification_service.dart';
import '../services/fcm_service.dart';
import '../shared/home_screen_header.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'calls_screen.dart';
import 'files_screen.dart';
import 'home/home_sidebar.dart';
import 'home/home_chat_filter_dropdown.dart';
import 'create_room_sheet.dart';
import 'direct_message_sheet.dart';
import 'incoming_call_screen.dart';
import 'message_screen.dart';
import 'profile_screen.dart';
import 'tasks_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  int _currentIndex = 0;
  late AnimationController _fadeController;
  bool _isSidebarOpen = false;
  bool _isFilterDropdownOpen = false;
  String _selectedFilter = 'All';
  OverlayEntry? _filterDropdownOverlay;

  // FCM / notification subscriptions — cancelled in dispose().
  StreamSubscription<RemoteMessage>? _fcmCallSub;
  StreamSubscription<NotificationResponse>? _notifResponseSub;

  final List<Widget> _screens = const [
    ChatScreen(),
    CallsScreen(),
    TasksScreen(),
    FilesScreen(),
    ProfileScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeController.forward();

    // Route foreground FCM call events. Deduplication against XMPP is handled
    // inside _onForegroundFcmCall (checks incomingCallProvider.hasActiveCall).
    _fcmCallSub =
        FcmService.foregroundCallStream.listen(_onForegroundFcmCall);

    // Route local notification action responses (e.g. "Accept" tapped on a
    // heads-up or lock-screen notification while the app is in the background).
    _notifResponseSub =
        CallNotificationService.responseStream.listen(_onNotificationResponse);

    // Detect if the app was cold-started from a terminated-state call
    // notification (either body tap or Accept action).
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _checkPendingCall());
  }

  @override
  void dispose() {
    _hideFilterDropdown();
    WidgetsBinding.instance.removeObserver(this);
    _fadeController.dispose();
    _fcmCallSub?.cancel();
    _notifResponseSub?.cancel();
    super.dispose();
  }

  // Refresh data whenever the app returns to foreground so users never need
  // to restart the app to see new rooms, updated metadata, or fresh counts.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(roomsProvider);
      ref.invalidate(unreadInitProvider);
      // Re-check for a call that was delivered while the app was backgrounded
      // and whose notification was tapped by the user.
      _checkPendingCall();
    }
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    _fadeController.reset();
    setState(() => _currentIndex = index);
    _fadeController.forward();
  }

  void _toggleSidebar() {
    setState(() {
      _isSidebarOpen = !_isSidebarOpen;
    });
  }

  void _toggleFilterDropdown() {
    if (_isFilterDropdownOpen) {
      _hideFilterDropdown();
    } else {
      _showFilterDropdown();
    }
  }

  void _showFilterDropdown() {
    setState(() {
      _isFilterDropdownOpen = true;
    });

    _filterDropdownOverlay = OverlayEntry(
      builder: (context) => GestureDetector(
        onTap: () => _hideFilterDropdown(),
        child: Container(
          color: Colors.transparent,
          child: Stack(
            children: [
              Positioned(
                top: HomeScreenHeader.headerHeight + 8,
                right: 60,
                child: HomeChatFilterDropdown(
                  selectedFilter: _selectedFilter,
                  onFilterSelected: (filter) {
                    setState(() {
                      _selectedFilter = filter;
                    });
                    _hideFilterDropdown();
                    // TODO: Apply filter to chat list
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_filterDropdownOverlay!);
  }

  void _hideFilterDropdown() {
    _filterDropdownOverlay?.remove();
    _filterDropdownOverlay = null;
    setState(() {
      _isFilterDropdownOpen = false;
    });
  }

  // ── FCM / notification integration ─────────────────────────────────────────

  /// Called on first build and every time the app resumes from background.
  /// Reads any call stored in SharedPreferences by the background FCM handler
  /// and opens [IncomingCallScreen] if one is found.
  Future<void> _checkPendingCall() async {
    // 1. App was cold-started by tapping this plugin's notification.
    final launchResponse = CallNotificationService.launchResponse;
    if (launchResponse != null) {
      CallNotificationService.clearLaunchResponse();
      final pending = await CallNotificationService.consumePendingCall();
      if (pending.data != null) {
        _openIncomingCallScreen(
          pending.data!,
          autoAccept: launchResponse.actionId == 'accept_call',
        );
        return;
      }
    }

    // 2. App resumed from background with a pending call stored in prefs.
    final pending = await CallNotificationService.consumePendingCall();
    if (pending.data != null && pending.action != 'decline') {
      _openIncomingCallScreen(
        pending.data!,
        autoAccept: pending.action == 'accept',
      );
    }
  }

  /// Handles notification action taps that arrive while the app is already
  /// running (foreground or background→foreground transition).
  Future<void> _onNotificationResponse(NotificationResponse response) async {
    if (response.actionId == 'decline_call') return; // handled in background isolate
    final pending = await CallNotificationService.consumePendingCall();
    if (pending.data == null) return;
    _openIncomingCallScreen(
      pending.data!,
      autoAccept: response.actionId == 'accept_call',
    );
  }

  /// Handles foreground FCM call events (app is visible when the push arrives).
  ///
  /// Deduplicates against the XMPP overlay — if XMPP already showed the
  /// incoming-call overlay, [incomingCallProvider.hasActiveCall] is true and
  /// we skip the FCM event to avoid showing a duplicate UI.
  void _onForegroundFcmCall(RemoteMessage message) {
    final fcmType = message.data['fcm_type'] ?? '';
    switch (fcmType) {
      case 'jitsi_ring_send':
        final incoming = IncomingCallState.fromXmppData(message.data);
        final current = ref.read(incomingCallProvider);
        // Deduplicate: skip only if this exact conversation is already ringing.
        // A cleared provider (hasActiveCall == false) always lets the call through.
        if (current.conversationId == incoming.conversationId &&
            current.hasActiveCall) {
          return;
        }
        ref.read(incomingCallProvider.notifier).show(incoming);
      case 'jitsi_send_hangup':
      case 'jitsi_send_accept':
        ref.read(incomingCallProvider.notifier).dismiss();
        CallNotificationService.dismissCallNotification();
    }
  }

  void _openIncomingCallScreen(
    Map<String, dynamic> data, {
    required bool autoAccept,
  }) {
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => IncomingCallScreen(
          callData: data,
          autoAccept: autoAccept,
        ),
      ),
    );
  }

  /// Converts [IncomingCallState] (from XMPP or foreground FCM) to the
  /// normalised data map that [IncomingCallScreen] expects, then pushes it.
  void _openIncomingCallScreenFromState(IncomingCallState state) {
    _openIncomingCallScreen(
      {
        'user_fullname': state.callerName ?? 'Unknown',
        'user_img': state.callerImg ?? '',
        'conversation_id': state.conversationId ?? '',
        'set_calltype': state.isVideo ? 'video' : 'audio',
        'convname': state.convTitle ?? '',
        'caller_id': state.callerId ?? '',
      },
      autoAccept: false,
    );
  }

  String _buildPreview(Map<String, dynamic> data) {
    final msgType = data['msg_type']?.toString() ?? '';
    if (msgType == 'media_attachment') return '📎 Attachment';
    try {
      final raw = EncryptionService.decrypt(data['msg_body']?.toString() ?? '');
      final stripped = raw.replaceAll(RegExp(r'<[^>]+>'), '').trim();
      return stripped.isEmpty ? 'New message' : stripped;
    } catch (_) {
      return 'New message';
    }
  }

  Future<void> _showActionSheet() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.person_add_rounded,
                      color: AppTheme.primary, size: 20),
                ),
                title: Text('Direct Message',
                    style: AppTheme.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600)),
                subtitle: Text('Start a private conversation',
                    style: AppTheme.caption),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.textDim),
                onTap: () => Navigator.of(ctx).pop('dm'),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              const SizedBox(height: 4),
              ListTile(
                leading: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppTheme.accentSoft,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.group_add_rounded,
                      color: AppTheme.primary, size: 20),
                ),
                title: Text('Create Room',
                    style: AppTheme.bodyMedium
                        .copyWith(fontWeight: FontWeight.w600)),
                subtitle:
                    Text('Create a group channel', style: AppTheme.caption),
                trailing: const Icon(Icons.chevron_right_rounded,
                    color: AppTheme.textDim),
                onTap: () => Navigator.of(ctx).pop('room'),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );

    if (!mounted) return;
    if (choice == 'dm') {
      await _showDirectMessageSheet();
    } else if (choice == 'room') {
      await _showCreateRoomSheet();
    }
  }

  Future<void> _showDirectMessageSheet() async {
    final result = await showModalBottomSheet<({Room room, String selfId})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const DirectMessageSheet(),
    );

    if (!mounted || result == null) return;
    ref.invalidate(roomsProvider);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessageScreen(room: result.room, selfId: result.selfId),
      ),
    );
  }

  Future<void> _showCreateRoomSheet() async {
    final result = await showModalBottomSheet<({Room room, String selfId})>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppTheme.bgCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => const CreateRoomSheet(),
    );

    if (!mounted || result == null) return;
    ref.invalidate(roomsProvider);
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MessageScreen(room: result.room, selfId: result.selfId),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Auto-connect XMPP after login — runs once, silently.
    ref.watch(xmppAutoConnectProvider);

    // Fetch initial unread counts from backend on login — seeds the counter map
    // so existing unread messages show badges immediately without waiting for
    // new XMPP events.
    ref.watch(unreadInitProvider);

    // Register the FCM token once per login session so the backend can send
    // call push notifications when the device is not reachable via XMPP.
    ref.listen(meProvider, (prev, next) {
      if (next.value == null) return;
      if (prev?.value?.id == next.value?.id) return;
      FcmService.requestPermissions();
      FcmService.registerToken(next.value!.id);
    });

    // Open the full-screen ringing UI whenever a new call arrives via XMPP
    // (jitsi_busy_status) or foreground FCM (jitsi_ring_send).
    ref.listen(incomingCallProvider, (prev, next) {
      if (next.hasActiveCall && !(prev?.hasActiveCall ?? false)) {
        _openIncomingCallScreenFromState(next);
      }
    });

    // Global XMPP event handler — lives in HomeScreen so it fires regardless
    // of which tab is currently active.
    ref.listen(xmppEventStreamProvider, (_, next) {
      if (!next.hasValue || next.value == null) return;
      final event = next.value!;
      final data = event.data;

      switch (event.type) {
        case 'new_message':
        case 'new_reply_message':
          final convId = data['conversation_id']?.toString() ??
              data['conv_id']?.toString() ??
              '';
          if (convId.isEmpty) return;

          final activeRoom = ref.read(activeRoomIdProvider);
          final selfId = ref.read(meProvider).value?.id ?? '';
          final senderId =
              data['sender']?.toString() ?? data['user_id']?.toString() ?? '';
          final senderName = data['sendername']?.toString() ??
              data['sender_name']?.toString() ??
              '';
          final msgTime = data['created_at']?.toString() ??
              DateTime.now().toIso8601String();

          ref.read(roomPreviewNotifierProvider.notifier).update(
                convId: convId,
                senderName: senderName,
                preview: _buildPreview(data),
                time: msgTime,
              );

          if (senderId != selfId && convId != activeRoom) {
            ref.read(unreadCountsProvider.notifier).increment(convId);
          }

        case 'read_status_msg':
          // A user (possibly on another device or the web) marked messages as
          // read — decrement the local counter to stay in sync.
          final convId = data['conversation_id']?.toString() ?? '';
          final read = (data['read'] as num?)?.toInt() ?? 0;
          final isReply = data['is_reply_msg']?.toString() == 'yes';
          if (convId.isNotEmpty && !isReply && read > 0) {
            ref.read(unreadCountsProvider.notifier).decrement(convId, read);
          }

        case 'new_room':
          // A new conversation was created (e.g. from the web client).
          ref.invalidate(roomsProvider);

        case 'update_room':
          // Conversation metadata changed (participants, title, etc.).
          ref.invalidate(roomsProvider);

        case 'mute_conversation':
          ref.invalidate(roomsProvider);

        case 'room_archive':
          ref.invalidate(roomsProvider);

        case 'kick_out':
          // User was removed from a conversation.
          ref.invalidate(roomsProvider);

        case 'pin_unpin':
          ref.invalidate(roomsProvider);

        case 'xmpp_connected':
          // XMPP (re)connected after a drop — refresh rooms and unread counts
          // to catch up on any changes that arrived while offline.
          ref.invalidate(roomsProvider);
          ref.invalidate(unreadInitProvider);

        case 'jitsi_ring_send':
          // Incoming call — show full-screen ringing UI for the callee.
          // The backend sends this to receiver_id; data['user_id'] is the caller.
          final selfId = ref.read(meProvider).value?.id ?? '';
          final callerId =
              (data['caller_id'] ?? data['user_id'])?.toString() ?? '';
          if (callerId.isNotEmpty && callerId != selfId) {
            ref.read(incomingCallProvider.notifier).show(
                  IncomingCallState.fromXmppData(data),
                );
          }

        case 'jitsi_send_hangup':
          // Caller cancelled or call ended — dismiss any pending overlay.
          ref.read(incomingCallProvider.notifier).dismiss();
          ref.invalidate(callHistoryProvider);

        case 'jitsi_ring_status':
        case 'jitsi_send_accept':
        case 'jitsi_user_accept':
          // Dismiss the incoming overlay once someone accepted on any device.
          final selfId2 = ref.read(meProvider).value?.id ?? '';
          final acceptId =
              (data['user_id'] ?? data['accept_id'])?.toString() ?? '';
          if (acceptId == selfId2) {
            ref.read(incomingCallProvider.notifier).dismiss();
          }
      }
    });

    // Total unread for the Messages tab badge.
    final totalUnread = ref.watch(
        unreadCountsProvider.select((m) => m.values.fold(0, (a, b) => a + b)));

    return Stack(
      children: [
        Scaffold(
          backgroundColor: AppTheme.bg,
          body: Column(
            children: [
              HomeScreenHeader(
                onFilterTap: _toggleFilterDropdown,
                onMenuTap: _toggleSidebar,
                selectedFilter: _selectedFilter,
                showFilterDropdown: _isFilterDropdownOpen,
              ),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeController,
                  child: _screens[_currentIndex],
                ),
              ),
            ],
          ),
          floatingActionButton: !_isSidebarOpen && _currentIndex == 0
              ? FloatingActionButton(
                  onPressed: _showActionSheet,
                  backgroundColor: const Color(0xFF0F2750),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const Icon(
                    Icons.add_rounded,
                    color: Colors.white,
                    size: 28,
                  ),
                )
              : null,
          bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: AppTheme.bgCard,
              border: Border(top: BorderSide(color: AppTheme.border, width: 1)),
            ),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildNavItem(
                      icon: Icons.chat_bubble_rounded,
                      label: 'Messages',
                      index: 0,
                      badge: totalUnread,
                    ),
                    _buildNavItem(
                      icon: Icons.phone_rounded,
                      label: 'Calls',
                      index: 1,
                    ),
                    _buildNavItem(
                      icon: Icons.view_kanban_rounded,
                      label: 'Tasks',
                      index: 2,
                    ),
                    _buildNavItem(
                      icon: Icons.folder_rounded,
                      label: 'Files',
                      index: 3,
                    ),
                    _buildNavItem(
                      icon: Icons.person_rounded,
                      label: 'Profile',
                      index: 4,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (_isSidebarOpen) HomeSidebar(onClose: _toggleSidebar),
      ],
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    int badge = 0,
  }) {
    final isActive = _currentIndex == index;
    return GestureDetector(
      onTap: () => _onTabTapped(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primary.withValues(alpha: 0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  icon,
                  color: isActive ? AppTheme.primary : AppTheme.textDim,
                  size: 24,
                ),
                if (badge > 0)
                  Positioned(
                    right: -8,
                    top: -4,
                    child: Container(
                      constraints: const BoxConstraints(minWidth: 18),
                      height: 18,
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.danger,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(color: AppTheme.bgCard, width: 1.5),
                      ),
                      child: Center(
                        child: Text(
                          badge > 99 ? '99+' : '$badge',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: isActive ? AppTheme.primary : AppTheme.textDim,
                fontSize: 11,
                fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
