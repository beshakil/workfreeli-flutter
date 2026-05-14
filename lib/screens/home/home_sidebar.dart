import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../features/auth/auth_providers.dart';
import '../../features/user/user_providers.dart';
import 'dart:ui';
import 'switch_account_modal.dart';

class HomeSidebar extends ConsumerStatefulWidget {
  final VoidCallback onClose;

  const HomeSidebar({super.key, required this.onClose});

  @override
  ConsumerState<HomeSidebar> createState() => _HomeSidebarState();
}

class _HomeSidebarState extends ConsumerState<HomeSidebar> {
  bool _isLightMode = true;
  bool _showSwitchAccountModal = false;

  // Demo account data
  final List<AccountInfo> _demoAccounts = [
    const AccountInfo(
      name: 'MD Ahmed Shakil',
      role: 'ITL Dev',
      initial: 'M',
      avatarColor: Color(0xFF3B82F6),
      isActive: true,
    ),
    const AccountInfo(
      name: 'Sarah Johnson',
      role: 'Product Manager',
      initial: 'S',
      avatarColor: Color(0xFFEF4444),
      isActive: false,
    ),
    const AccountInfo(
      name: 'Michael Chen',
      role: 'UX Designer',
      initial: 'M',
      avatarColor: Color(0xFFF59E0B),
      isActive: false,
    ),
  ];

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
                      const SizedBox(height: 20),
                      // Header Container with Logo & Actions
                      _buildHeaderContainer(),
                      const SizedBox(height: 20),
                      // Combined User Bio & Switch Account Container
                      _buildUserBioAndSwitchAccount(),
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
          // Switch Account Modal
          if (_showSwitchAccountModal)
            SwitchAccountModal(
              accounts: _demoAccounts,
              onClose: () {
                setState(() {
                  _showSwitchAccountModal = false;
                });
              },
              onAccountSelected: (account) {
                // Handle account selection
                setState(() {
                  _showSwitchAccountModal = false;
                });
                // TODO: Implement actual account switching logic
              },
            ),
        ],
      ),
    );
  }

  Widget _buildUserBioAndSwitchAccount() {
    final meAsync = ref.watch(meProvider);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // User Avatar
          meAsync.when(
            data: (user) => _buildUserAvatar(user),
            loading: () => _buildLoadingAvatar(),
            error: (_, __) =>
                _buildFallbackAvatar('?', const Color(0xFF3B82F6)),
          ),
          const SizedBox(height: 12),
          // User Name
          meAsync.when(
            data: (user) => Text(
              user.fullName,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
            loading: () => _buildLoadingText(width: 140),
            error: (_, __) => const Text(
              'User',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 6),
          // Company Name
          meAsync.when(
            data: (user) => Text(
              user.companyName.isNotEmpty ? user.companyName : 'No Company',
              style: const TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            loading: () => _buildLoadingText(width: 100),
            error: (_, __) => const Text(
              'Company',
              style: TextStyle(
                color: Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Divider
          Container(
            height: 1,
            color: Colors.white.withValues(alpha: 0.1),
          ),
          const SizedBox(height: 12),
          // Switch Account
          _buildSwitchAccount(),
        ],
      ),
    );
  }

  Widget _buildUserAvatar(dynamic user) {
    final img = user.img;
    final hasValidUrl = img != null &&
        img.isNotEmpty &&
        (img.startsWith('http://') || img.startsWith('https://'));

    if (hasValidUrl) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: CachedNetworkImage(
          imageUrl: img,
          width: 64,
          height: 64,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _buildFallbackAvatar(
            user.initials.isNotEmpty ? user.initials : '?',
            const Color(0xFF3B82F6),
          ),
        ),
      );
    }

    return _buildFallbackAvatar(
      user.initials.isNotEmpty ? user.initials : '?',
      const Color(0xFF3B82F6),
    );
  }

  Widget _buildFallbackAvatar(String initials, Color color) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingAvatar() {
    return Container(
      width: 64,
      height: 64,
      decoration: const BoxDecoration(
        color: Color(0xFF3B82F6),
        shape: BoxShape.circle,
      ),
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingText({required double width}) {
    return Container(
      width: width,
      height: 18,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }

  Widget _buildHeaderContainer() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: Row(
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
    );
  }

  Widget _buildLogo() {
    return Image.asset(
      'assets/images/workfreeli-dark-logo.png',
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          setState(() {
            _showSwitchAccountModal = true;
          });
        },
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left side: Stacked avatars + text
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Stacked avatars
                  SizedBox(
                    height: 32,
                    width: 76,
                    child: Stack(
                      children: [
                        // First avatar (back)
                        Positioned(
                          left: 0,
                          child: _buildSmallAvatar(
                              'M', const Color(0xFF3B82F6), 0),
                        ),
                        // Second avatar (middle)
                        Positioned(
                          left: 24,
                          child: _buildSmallAvatar(
                              'S', const Color(0xFFEF4444), 1),
                        ),
                        // Third avatar (front)
                        Positioned(
                          left: 48,
                          child: _buildSmallAvatar(
                              'M', const Color(0xFFF59E0B), 2),
                        ),
                      ],
                    ),
                  ),
                  // 10px gap
                  const SizedBox(width: 10),
                  // Switch Account text
                  const Text(
                    'Switch Account',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              // Right side: Icon
              const Icon(
                Icons.swap_horiz_rounded,
                color: Color(0xFF94A3B8),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSmallAvatar(String letter, Color color, int index) {
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
              borderRadius: BorderRadius.circular(8),
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
          iconBgColor: Colors.white.withValues(alpha: 0.1),
          iconColor: const Color(0xFFEF4444),
          badge: '2',
        ),
        const SizedBox(height: 4),
        _buildMenuItem(
          icon: Icons.notifications_rounded,
          label: 'All notifications',
          iconBgColor: Colors.white.withValues(alpha: 0.1),
          iconColor: Colors.white,
        ),
        const SizedBox(height: 4),
        _buildMenuItem(
          icon: Icons.lock_rounded,
          label: 'Change password',
          iconBgColor: Colors.white.withValues(alpha: 0.1),
          iconColor: Colors.white,
        ),
        const SizedBox(height: 4),
        _buildMenuItem(
          icon: Icons.shield_rounded,
          label: 'Admin settings',
          iconBgColor: Colors.white.withValues(alpha: 0.1),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
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
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        children: [
          // Sun icon
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
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
              onTap: () => ref.read(authNotifierProvider.notifier).logout(),
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
