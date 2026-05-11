import 'package:flutter/material.dart';
import 'dart:ui';
import '../../theme/app_theme.dart';

class AccountInfo {
  final String name;
  final String role;
  final String initial;
  final Color avatarColor;
  final bool isActive;

  const AccountInfo({
    required this.name,
    required this.role,
    required this.initial,
    required this.avatarColor,
    this.isActive = false,
  });
}

class SwitchAccountModal extends StatelessWidget {
  final List<AccountInfo> accounts;
  final VoidCallback onClose;
  final Function(AccountInfo) onAccountSelected;

  const SwitchAccountModal({
    super.key,
    required this.accounts,
    required this.onClose,
    required this.onAccountSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onClose,
      child: Stack(
        children: [
          // Blurred background overlay
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
              child: Container(
                color: Colors.black.withValues(alpha: 0.1),
              ),
            ),
          ),
          // Center modal container
          Center(
            child: GestureDetector(
              onTap: () {}, // Prevent closing when tapping on modal
              child: Container(
                width: 400,
                constraints: const BoxConstraints(maxHeight: 600),
                decoration: BoxDecoration(
                  color: AppTheme.bgCard,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.15),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    _buildHeader(),
                    const Divider(height: 1, color: AppTheme.border),
                    // Account list
                    Flexible(
                      child: _buildAccountList(),
                    ),
                    const Divider(height: 1, color: AppTheme.border),
                    // Footer
                    _buildFooter(),
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
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Text(
            'Switch Account',
            style: AppTheme.headingSmall.copyWith(
              color: const Color(0xFF0F2750),
              fontSize: 18,
              decoration: TextDecoration.none,
            ),
          ),
          const Spacer(),
          Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onClose,
              borderRadius: BorderRadius.circular(20),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(
                  Icons.close_rounded,
                  color: AppTheme.textMuted,
                  size: 22,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountList() {
    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: accounts.length,
      itemBuilder: (context, index) {
        final account = accounts[index];
        return _buildAccountTile(account);
      },
    );
  }

  Widget _buildAccountTile(AccountInfo account) {
    final isSelected = account.isActive;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onAccountSelected(account),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.accentSoft : Colors.transparent,
          ),
          child: Row(
            children: [
              // Avatar
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: account.avatarColor,
                  shape: BoxShape.circle,
                  border: isSelected
                      ? Border.all(
                          color: AppTheme.accent,
                          width: 2,
                        )
                      : null,
                ),
                child: Center(
                  child: Text(
                    account.initial,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              // Account info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      account.name,
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w600,
                        color:
                            isSelected ? AppTheme.accent : AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      account.role,
                      style: AppTheme.bodySmall.copyWith(
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              // Active indicator
              if (isSelected)
                const Icon(
                  Icons.check_circle_rounded,
                  color: AppTheme.accent,
                  size: 24,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // Add new account action
          },
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.border),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.add_circle_outline_rounded,
                  color: AppTheme.accent,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Add Another Account',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.accent,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
