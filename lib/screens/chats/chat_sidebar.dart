import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';

import '../../core/config/app_config.dart';
import '../../core/models/conversation_models.dart';

class ChatSidebar extends StatefulWidget {
  final VoidCallback onClose;
  final Room room;

  const ChatSidebar({
    super.key,
    required this.onClose,
    required this.room,
  });

  @override
  State<ChatSidebar> createState() => _ChatSidebarState();
}

class _ChatSidebarState extends State<ChatSidebar> {
  bool _showFilters = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onClose,
      child: Stack(
        children: [
          // Blur overlay
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
              child: Container(
                color: Colors.black.withValues(alpha: 0.1),
              ),
            ),
          ),
          // Sidebar content
          GestureDetector(
            onTap: () {}, // Prevent closing when tapping on sidebar
            child: Align(
              alignment: Alignment.centerRight,
              child: Container(
                width: 320,
                decoration: const BoxDecoration(
                  color: Color(0xFF0F2750),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 10,
                      offset: Offset(-2, 0),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    // Header with room info
                    _buildHeader(),
                    const SizedBox(height: 20),
                    // Main menu items
                    Expanded(
                      child: _buildMenuList(),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          // Room avatar (image or initials)
          _buildRoomAvatar(),
          const SizedBox(width: 12),
          // Room name and description
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.room.title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.room.isGroup ? 'Group Chat' : 'Direct Message',
                  style: const TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // Close button
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onClose,
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.close_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomAvatar() {
    final colors = _avatarColors(widget.room.id);
    final isGroup = widget.room.isGroup;

    // If room has an image, display it with error handling
    if (widget.room.convImg != null && widget.room.convImg!.isNotEmpty) {
      return Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          shape: isGroup ? BoxShape.rectangle : BoxShape.circle,
          borderRadius: isGroup ? BorderRadius.circular(11) : null,
        ),
        child: ClipRRect(
          borderRadius:
              isGroup ? BorderRadius.circular(11) : BorderRadius.circular(24),
          child: CachedNetworkImage(
            imageUrl: '${AppConfig.fileBaseUrl}${widget.room.convImg}',
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: colors[0],
              child: Center(
                child: Text(
                  widget.room.initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            errorWidget: (context, url, error) =>
                _buildInitialsAvatar(colors, isGroup),
          ),
        ),
      );
    }

    // Fallback to gradient with initials
    return _buildInitialsAvatar(colors, isGroup);
  }

  Widget _buildInitialsAvatar(List<Color> colors, bool isGroup) {
    return Container(
      width: 48,
      height: 48,
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
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  List<Color> _avatarColors(String id) {
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

  Widget _buildMenuList() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildMenuItem(
          icon: Icons.content_paste_rounded,
          label: 'Tasks',
        ),
        const SizedBox(height: 2),
        _buildMenuItem(
          icon: Icons.add_rounded,
          label: 'Create task',
        ),
        const SizedBox(height: 2),
        _buildMenuItem(
          icon: Icons.settings_rounded,
          label: 'Room settings',
        ),
        const SizedBox(height: 2),
        _buildMenuItem(
          icon: Icons.search_rounded,
          label: 'Search messages',
        ),
        const SizedBox(height: 2),
        _buildMenuItem(
          icon: Icons.location_on_rounded,
          label: 'Share location',
        ),
        const SizedBox(height: 2),
        _buildMenuItem(
          icon: Icons.done_all_rounded,
          label: 'Mark all read',
        ),
        const SizedBox(height: 2),
        _buildMenuItem(
          icon: Icons.notifications_off_rounded,
          label: 'Mute notifications',
        ),
        const SizedBox(height: 2),
        _buildMenuItem(
          icon: Icons.filter_list_rounded,
          label: 'Filters',
          trailing: Icon(
            _showFilters
                ? Icons.keyboard_arrow_up_rounded
                : Icons.keyboard_arrow_right_rounded,
            color: const Color(0xFF94A3B8),
            size: 18,
          ),
          onTap: () {
            setState(() {
              _showFilters = !_showFilters;
            });
          },
        ),
        if (_showFilters) ...[
          const SizedBox(height: 6),
          _buildFilterSubMenu(),
        ],
      ],
    );
  }

  Widget _buildFilterSubMenu() {
    return Container(
      margin: const EdgeInsets.only(left: 12),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          _buildFilterItem(
            icon: Icons.chat_rounded,
            label: 'Threaded messages',
          ),
          const SizedBox(height: 2),
          _buildFilterItem(
            icon: Icons.link_rounded,
            label: 'Messages with links',
          ),
          const SizedBox(height: 2),
          _buildFilterItem(
            icon: Icons.chat_bubble_outline_rounded,
            label: 'Messages with titles',
          ),
          const SizedBox(height: 2),
          _buildFilterItem(
            icon: Icons.folder_rounded,
            label: 'Messages with files',
          ),
          const SizedBox(height: 2),
          _buildFilterItem(
            icon: Icons.star_rounded,
            label: 'Messages with starred files',
          ),
          const SizedBox(height: 2),
          _buildFilterItem(
            icon: Icons.mark_chat_unread_rounded,
            label: 'New/Unread messages',
          ),
          const SizedBox(height: 2),
          _buildFilterItem(
            icon: Icons.flag_rounded,
            label: 'Flagged messages',
          ),
          const SizedBox(height: 2),
          _buildFilterItem(
            icon: Icons.lock_rounded,
            label: 'Private messages',
          ),
        ],
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // Icon with background
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  icon,
                  color: Colors.white,
                  size: 18,
                ),
              ),
              const SizedBox(width: 10),
              // Label
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              // Trailing widget
              if (trailing != null) trailing,
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterItem({
    required IconData icon,
    required String label,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          // TODO: Implement filter logic
        },
        borderRadius: BorderRadius.circular(6),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              Icon(
                icon,
                color: const Color(0xFF94A3B8),
                size: 16,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    color: Color(0xFFCBD5E1),
                    fontSize: 13,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
