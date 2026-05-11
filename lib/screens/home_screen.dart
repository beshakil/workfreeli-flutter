import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/encryption/encryption_service.dart';
import '../features/conversations/conversations_providers.dart';
import '../features/user/user_providers.dart';
import '../features/xmpp/xmpp_provider.dart';
import '../shared/home_screen_header.dart';
import '../theme/app_theme.dart';
import 'chat_screen.dart';
import 'calls_screen.dart';
import 'files_screen.dart';
import 'home_sidebar.dart';
import 'profile_screen.dart';
import 'tasks_screen.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  late AnimationController _fadeController;
  bool _isSidebarOpen = false;

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
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    // Auto-connect XMPP after login — runs once, silently.
    ref.watch(xmppAutoConnectProvider);

    // Fetch initial unread counts from backend on login — seeds the counter map
    // so existing unread messages show badges immediately without waiting for
    // new XMPP events.
    ref.watch(unreadInitProvider);

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
                onMenuTap: _toggleSidebar,
              ),
              Expanded(
                child: FadeTransition(
                  opacity: _fadeController,
                  child: _screens[_currentIndex],
                ),
              ),
            ],
          ),
          floatingActionButton: !_isSidebarOpen
              ? FloatingActionButton(
                  onPressed: () {},
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
