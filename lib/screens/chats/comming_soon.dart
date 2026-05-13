import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../theme/app_theme.dart';

/// Bottom sheet modal for "Coming Soon" features.
///
/// Displays a centered icon, title, description, and a close button
/// to indicate that a feature is under development.
class ComingSoonModal extends ConsumerWidget {
  /// The title of the feature (e.g., "AI Assistant", "Encryption")
  final String title;

  /// Optional description text
  final String? description;

  /// Optional icon to display (defaults to construction icon)
  final IconData? icon;

  const ComingSoonModal({
    super.key,
    required this.title,
    this.description,
    this.icon,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Handle bar indicator
              Container(
                margin: const EdgeInsets.only(bottom: 24, top: 16),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),

              // Coming Soon label
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Coming Soon',
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              // Icon
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppTheme.primary.withValues(alpha: 0.1),
                      AppTheme.accentSoft,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Icon(
                  icon ?? Icons.construction_rounded,
                  size: 40,
                  color: AppTheme.primary,
                ),
              ),

              const SizedBox(height: 20),

              // Title
              Text(
                title,
                style: AppTheme.headingSmall.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              // Description
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Text(
                  description ??
                      'This feature is currently under development and will be available soon.',
                  style: AppTheme.bodyMedium.copyWith(
                    color: AppTheme.textDim,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),

              const SizedBox(height: 24),

              // Divider
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Divider(
                  color: AppTheme.border.withValues(alpha: 0.3),
                  height: 1,
                ),
              ),

              const SizedBox(height: 16),

              // Close button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Got it',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}
