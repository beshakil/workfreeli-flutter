import 'package:flutter/material.dart';

/// A global, reusable header widget for the Workfreeli application.
///
/// Designed to be used across multiple screens. Provides branding (logo)
/// on the left and action icons (filter, menu) on the right.
class HomeScreenHeader extends StatefulWidget {
  /// Height of the header bar.
  static const double headerHeight = 60.0;

  /// Called when the filter icon is tapped.
  final VoidCallback? onFilterTap;

  /// Called when the menu icon is tapped.
  final VoidCallback? onMenuTap;

  /// Currently selected filter
  final String selectedFilter;

  /// Whether the filter dropdown is visible
  final bool showFilterDropdown;

  const HomeScreenHeader({
    super.key,
    this.onFilterTap,
    this.onMenuTap,
    this.selectedFilter = 'All',
    this.showFilterDropdown = false,
  });

  @override
  State<HomeScreenHeader> createState() => _HomeScreenHeaderState();
}

class _HomeScreenHeaderState extends State<HomeScreenHeader> {
  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: HomeScreenHeader.headerHeight,
      child: Container(
        decoration: const BoxDecoration(
          color: Color(0xFF0F2750),
        ),
        padding: const EdgeInsets.only(left: 12, top: 8, bottom: 8),
        child: Row(
          children: [
            // ── Logo section ──────────────────────────────────────────
            _buildLogo(),
            const Spacer(),
            // ── Action icons ──────────────────────────────────────────
            _buildIconButton(
              icon: Icons.filter_alt_rounded,
              onTap: widget.onFilterTap,
            ),
            const SizedBox(width: 4),
            _buildIconButton(
              icon: Icons.menu_rounded,
              onTap: widget.onMenuTap,
            ),
            const SizedBox(width: 8),
          ],
        ),
      ),
    );
  }

  /// Builds the brand logo using the workfreeli-logo.png image.
  Widget _buildLogo() {
    return Image.asset(
      'assets/images/workfreeli-logo.png',
      height: 28,
      fit: BoxFit.contain,
    );
  }

  /// Builds a circular icon button with white icon color.
  Widget _buildIconButton({
    required IconData icon,
    required VoidCallback? onTap,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            icon,
            color: Colors.white,
            size: 26,
          ),
        ),
      ),
    );
  }
}
