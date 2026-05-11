import 'package:flutter/material.dart';
import 'dart:ui';

class HomeSidebar extends StatefulWidget {
  final VoidCallback onClose;

  const HomeSidebar({super.key, required this.onClose});

  @override
  State<HomeSidebar> createState() => _HomeSidebarState();
}

class _HomeSidebarState extends State<HomeSidebar> {
  bool _isLightMode = true;

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
                child: DefaultTextStyle(
                  style: const TextStyle(decoration: TextDecoration.none),
                  child: Column(
                    children: [
                      // Header & Profile Section
                      _buildHeaderSection(),
                      const SizedBox(height: 20),
                      // Quick Access Apps
                      _buildQuickAccessApps(),
                      const SizedBox(height: 24),
                      // Menu List
                      Expanded(
                        child: _buildMenuList(),
                      ),
                      // Footer Action
                      _buildFooterAction(),
                      const SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderSection() {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Column(
        children: [
          // Logo & Actions
          Row(
            children: [
              // Logo
              _buildLogo(),
              const Spacer(),
              // Settings icon
              _buildIconActionButton(
                icon: Icons.settings_rounded,
                onTap: () {},
              ),
              const SizedBox(width: 8),
              // Close icon
              _buildIconActionButton(
                icon: Icons.close_rounded,
                onTap: widget.onClose,
              ),
            ],
          ),
          const SizedBox(height: 20),
          // User Avatar
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF3B82F6), Color(0xFF06B6D4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Center(
              child: Text(
                'M',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // User Name
          const Text(
            'MD Ahmed Shakil',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          // User Role
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'ITL Dev',
              style: TextStyle(
                color: Colors.white70,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Switch Account
          _buildSwitchAccount(),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/images/workfreeli-logo.png',
      height: 24,
      fit: BoxFit.contain,
    );
  }

  Widget _buildIconActionButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(6),
          child: Icon(
            icon,
            color: Colors.white,
            size: 22,
          ),
        ),
      ),
    );
  }

  Widget _buildSwitchAccount() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.1),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          // Three small avatars
          _buildSmallAvatar('M', const Color(0xFF3B82F6)),
          const SizedBox(width: 6),
          _buildSmallAvatar('S', const Color(0xFFEC4899)),
          const SizedBox(width: 6),
          _buildSmallAvatar('M', const Color(0xFF10B981)),
          const Spacer(),
          const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white70,
            size: 20,
          ),
        ],
      ),
    );
  }

  Widget _buildSmallAvatar(String letter, Color color) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          letter,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildQuickAccessApps() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.1),
            width: 1,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 20),
        child: Row(
          children: [
            _buildQuickAppIcon(
              icon: Icons.book_rounded,
              label: 'Task',
            ),
            const SizedBox(width: 12),
            _buildQuickAppIcon(
              icon: Icons.folder_rounded,
              label: 'FileHub',
            ),
            const SizedBox(width: 12),
            _buildQuickAppIcon(
              icon: Icons.tablet_mac_rounded,
              label: 'Sales',
            ),
            const SizedBox(width: 12),
            _buildQuickAppIcon(
              icon: Icons.more_horiz_rounded,
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAppIcon({
    required IconData icon,
    required String label,
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuList() {
    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        _buildMenuItem(
          icon: Icons.archive_rounded,
          label: 'Archived rooms',
          trailing: const Text(
            '(1)',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
          iconBgColor: Colors.white.withValues(alpha: 0.1),
          iconColor: Colors.white,
        ),
        const SizedBox(height: 4),
        _buildMenuItem(
          icon: Icons.flag_rounded,
          label: 'Flagged messages',
          trailing: const Text(
            '(2)',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 13,
            ),
          ),
          iconBgColor: const Color(0xFFEF4444).withValues(alpha: 0.2),
          iconColor: const Color(0xFFEF4444),
          badge: '2',
        ),
        const SizedBox(height: 4),
        _buildMenuItem(
          icon: Icons.notifications_rounded,
          label: 'All notifications',
          iconBgColor: Colors.transparent,
          iconColor: Colors.white,
        ),
        const SizedBox(height: 4),
        _buildMenuItem(
          icon: Icons.lock_rounded,
          label: 'Change password',
          iconBgColor: Colors.transparent,
          iconColor: Colors.white,
        ),
        const SizedBox(height: 4),
        _buildMenuItem(
          icon: Icons.shield_rounded,
          label: 'Admin settings',
          iconBgColor: Colors.transparent,
          iconColor: Colors.white,
        ),
        const SizedBox(height: 4),
        _buildThemeToggle(),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String label,
    Widget? trailing,
    required Color iconBgColor,
    required Color iconColor,
    String? badge,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          // Icon with background
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: iconBgColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: iconColor,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
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
          // Badge or trailing widget
          if (badge != null) ...[
            const SizedBox(width: 8),
            Container(
              constraints: const BoxConstraints(minWidth: 20),
              height: 20,
              padding: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                color: const Color(0xFFEF4444),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Center(
                child: Text(
                  badge,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          ],
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing,
          ],
        ],
      ),
    );
  }

  Widget _buildThemeToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.white.withValues(alpha: 0.03),
      ),
      child: Row(
        children: [
          // Sun icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Icon(
              Icons.wb_sunny_rounded,
              color: Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Text(
              'Theme',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          // Toggle switch
          GestureDetector(
            onTap: () {
              setState(() {
                _isLightMode = !_isLightMode;
              });
            },
            child: Container(
              width: 44,
              height: 24,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: _isLightMode
                    ? const Color(0xFF3B82F6)
                    : Colors.white.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: AnimatedAlign(
                duration: const Duration(milliseconds: 200),
                alignment:
                    _isLightMode ? Alignment.centerRight : Alignment.centerLeft,
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooterAction() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        padding: const EdgeInsets.only(top: 16),
        decoration: BoxDecoration(
          border: Border(
            top: BorderSide(
              color: Colors.white.withValues(alpha: 0.1),
              width: 1,
            ),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xFFEF4444).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {},
              borderRadius: BorderRadius.circular(12),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.logout_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Sign out',
                      style: TextStyle(
                        color: Color(0xFFEF4444),
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
