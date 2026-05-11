import 'package:flutter/material.dart';

/// Dropdown menu for chat filter options
class HomeChatFilterDropdown extends StatefulWidget {
  /// Called when a filter option is selected
  final Function(String filter) onFilterSelected;

  /// Currently selected filter
  final String selectedFilter;

  const HomeChatFilterDropdown({
    super.key,
    required this.onFilterSelected,
    this.selectedFilter = 'All',
  });

  @override
  State<HomeChatFilterDropdown> createState() => _HomeChatFilterDropdownState();
}

class _HomeChatFilterDropdownState extends State<HomeChatFilterDropdown>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _animation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _animation,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: 220,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildFilterOption('All', 'All'),
                _buildFilterOption('Created by me', 'Created by me'),
                _buildFilterOption('Created by others', 'Created by others'),
                _buildDivider(),
                _buildFilterOption('Rooms', 'Rooms'),
                _buildFilterOption('Direct messages', 'Direct messages'),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFilterOption(String label, String value) {
    final isSelected = widget.selectedFilter == value;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          widget.onFilterSelected(value);
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFF3B82F6)
                        : const Color(0xFF1E293B),
                    fontSize: 14,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (isSelected)
                const Icon(
                  Icons.check_rounded,
                  color: Color(0xFF3B82F6),
                  size: 20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Container(
      height: 1,
      margin: const EdgeInsets.symmetric(vertical: 4),
      color: const Color(0xFFE2E8F0),
    );
  }
}
