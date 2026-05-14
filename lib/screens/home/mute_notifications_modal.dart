import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/conversations/conversations_providers.dart';
import '../../features/conversations/conversations_service.dart';
import '../../theme/app_theme.dart';

/// Centered dialog modal for muting notifications with duration options.
///
/// Provides options to mute notifications for different durations:
/// - Until manually turned back on
/// - For 30 minutes
/// - For 1 hour
/// - For 12 hours
/// - For 1 day
/// - For 1 month
class MuteNotificationsModal extends ConsumerStatefulWidget {
  /// The room/conversation to mute
  final Room room;

  /// The current user's ID
  final String selfId;

  const MuteNotificationsModal({
    super.key,
    required this.room,
    required this.selfId,
  });

  @override
  ConsumerState<MuteNotificationsModal> createState() =>
      _MuteNotificationsModalState();
}

class _MuteNotificationsModalState
    extends ConsumerState<MuteNotificationsModal> {
  String _selectedOption = 'indefinitely';

  final List<_MuteOption> _options = const [
    _MuteOption(
      value: 'indefinitely',
      label: 'Until I turn it back on',
      icon: Icons.notifications_off_rounded,
    ),
    _MuteOption(
      value: '30_minutes',
      label: 'For 30 minutes',
      icon: Icons.timer_rounded,
    ),
    _MuteOption(
      value: '1_hour',
      label: 'For 1 Hour',
      icon: Icons.schedule_rounded,
    ),
    _MuteOption(
      value: '12_hours',
      label: 'For 12 Hours',
      icon: Icons.hourglass_empty_rounded,
    ),
    _MuteOption(
      value: '1_day',
      label: 'For 1 Day',
      icon: Icons.today_rounded,
    ),
    _MuteOption(
      value: '1_month',
      label: 'For 1 Month',
      icon: Icons.calendar_today_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        decoration: BoxDecoration(
          color: AppTheme.bgCard,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header Section with Back Arrow and Title
            Container(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              decoration: BoxDecoration(
                color: AppTheme.bgCard,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      InkWell(
                        onTap: () => Navigator.of(context).pop(),
                        borderRadius: BorderRadius.circular(8),
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Icon(
                            Icons.arrow_back_ios_new_rounded,
                            size: 18,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Mute all Workfreeli notifications',
                          style: AppTheme.headingSmall.copyWith(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  // Instructional Text
                  Text(
                    'Please select one of the mute options.',
                    style: AppTheme.bodyMedium.copyWith(
                      color: AppTheme.textDim,
                    ),
                  ),
                ],
              ),
            ),

            // Divider
            // Container(
            //   height: 1,
            //   margin: const EdgeInsets.symmetric(horizontal: 20),
            //   color: AppTheme.border,
            // ),

            // Mute Options List
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding:
                    const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                itemCount: _options.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, index) {
                  final option = _options[index];
                  final isSelected = _selectedOption == option.value;
                  return _MuteOptionTile(
                    option: option,
                    isSelected: isSelected,
                    onTap: () {
                      setState(() {
                        _selectedOption = option.value;
                      });
                    },
                  );
                },
              ),
            ),

            // Divider
            // Container(
            //   height: 1,
            //   margin: const EdgeInsets.symmetric(horizontal: 20),
            //   color: AppTheme.border,
            // ),

            // Footer Buttons
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Cancel Button
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        side: BorderSide(color: AppTheme.border),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Cancel',
                        style: AppTheme.bodyLarge.copyWith(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Mute Button
                  Expanded(
                    child: FilledButton(
                      onPressed: _handleMute,
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        backgroundColor: AppTheme.primary,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Mute',
                        style: AppTheme.bodyLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleMute() async {
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();

    try {
      // TODO: Implement duration-based mute logic
      // For now, using the existing toggleMute which mutes indefinitely
      await ConversationsService.toggleMute(widget.room.id, widget.selfId);
      ref.invalidate(roomsProvider);

      messenger.showSnackBar(
        SnackBar(
          content: Text('Notifications muted successfully'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            'Failed: ${e.toString().replaceFirst('Exception: ', '')}',
          ),
          backgroundColor: AppTheme.danger,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// ── Mute option model ──────────────────────────────────────────────────────────

class _MuteOption {
  final String value;
  final String label;
  final IconData icon;

  const _MuteOption({
    required this.value,
    required this.label,
    required this.icon,
  });
}

// ── Mute option tile ───────────────────────────────────────────────────────────

class _MuteOptionTile extends StatelessWidget {
  const _MuteOptionTile({
    required this.option,
    required this.isSelected,
    required this.onTap,
  });

  final _MuteOption option;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected ? AppTheme.primary : AppTheme.border,
              width: 1.5,
            ),
          ),
          child: Row(
            children: [
              // Radio button
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : AppTheme.textDim,
                    width: 2,
                  ),
                  color: isSelected ? AppTheme.primary : Colors.transparent,
                ),
                child: isSelected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: const BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 14),
              // Icon
              Icon(
                option.icon,
                size: 20,
                color: isSelected ? AppTheme.primary : AppTheme.textMuted,
              ),
              const SizedBox(width: 12),
              // Label
              Expanded(
                child: Text(
                  option.label,
                  style: AppTheme.bodyLarge.copyWith(
                    color: isSelected ? AppTheme.primary : AppTheme.textPrimary,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
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
