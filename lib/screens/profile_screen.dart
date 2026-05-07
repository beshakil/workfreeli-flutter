import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../features/auth/auth_providers.dart';
import '../features/user/user_providers.dart';
import '../features/user/user_models.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(meProvider);

    return meAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AppTheme.primary),
      ),
      error: (err, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person_off_rounded,
                size: 48, color: AppTheme.textDim),
            const SizedBox(height: 16),
            Text('Could not load profile',
                style:
                    AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            Text(
              err.toString().replaceFirst('Exception: ', ''),
              style: AppTheme.caption,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () => ref.invalidate(meProvider),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Retry'),
              style: TextButton.styleFrom(foregroundColor: AppTheme.primary),
            ),
          ],
        ),
      ),
      data: (user) => _ProfileContent(user: user),
    );
  }
}

class _ProfileContent extends ConsumerWidget {
  const _ProfileContent({required this.user});
  final AppUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Banner with gradient
          Container(
            height: 160 + MediaQuery.of(context).padding.top,
            decoration: const BoxDecoration(gradient: AppTheme.bannerGradient),
          ),

          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar — overlaps the banner
                Transform.translate(
                  offset: const Offset(0, -44),
                  child: Container(
                    width: 88,
                    height: 88,
                    decoration: BoxDecoration(
                      gradient: AppTheme.avatarIndigo,
                      borderRadius: BorderRadius.circular(44),
                      border: Border.all(color: AppTheme.bg, width: 4),
                    ),
                    child: Center(
                      child: Text(
                        user.initials,
                        style: AppTheme.headingLarge.copyWith(
                          color: Colors.white,
                          fontSize: 32,
                        ),
                      ),
                    ),
                  ),
                ),

                Transform.translate(
                  offset: const Offset(0, -28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(user.fullName, style: AppTheme.headingMedium),
                      const SizedBox(height: 4),
                      Text(user.email,
                          style: AppTheme.bodyMedium
                              .copyWith(color: AppTheme.textMuted)),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: AppTheme.success,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('Online',
                              style: AppTheme.bodySmall
                                  .copyWith(color: AppTheme.success)),
                        ],
                      ),
                    ],
                  ),
                ),

                _sectionTitle('Workspace'),
                const SizedBox(height: 12),
                _infoTile(Icons.business_rounded, 'Organization',
                    user.companyName),
                _infoTile(Icons.shield_rounded, 'Role',
                    _capitalize(user.role ?? 'Member')),
                if (user.email.isNotEmpty)
                  _infoTile(Icons.email_rounded, 'Email', user.email),
                if (user.phone != null && user.phone!.isNotEmpty)
                  _infoTile(Icons.phone_rounded, 'Phone', user.phone!),
                if (user.timezone != null && user.timezone!.isNotEmpty)
                  _infoTile(Icons.schedule_rounded, 'Timezone', user.timezone!),
                if (user.multiCompany)
                  _infoTile(Icons.apartment_rounded, 'Account',
                      'Multi-workspace'),

                const SizedBox(height: 28),
                _sectionTitle('Settings'),
                const SizedBox(height: 12),
                _settingsTile(Icons.notifications_rounded, 'Notifications',
                    true, onChanged: (_) {}),
                _settingsTile(Icons.dark_mode_rounded, 'Dark Mode', true,
                    onChanged: (_) {}),
                _settingsTile(Icons.language_rounded, 'Language', null,
                    subtitle: 'English'),
                const SizedBox(height: 20),

                // Sign Out
                Container(
                  width: double.infinity,
                  height: 50,
                  margin: const EdgeInsets.only(bottom: 32),
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        ref.read(authNotifierProvider.notifier).logout(),
                    icon: const Icon(Icons.logout_rounded,
                        color: AppTheme.danger, size: 20),
                    label: Text('Sign Out',
                        style: AppTheme.bodyMedium.copyWith(
                            color: AppTheme.danger,
                            fontWeight: FontWeight.w600)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(
                          color: AppTheme.danger.withValues(alpha: 0.3)),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  Widget _sectionTitle(String title) =>
      Text(title.toUpperCase(), style: AppTheme.labelSmall);

  Widget _infoTile(IconData icon, String title, String value) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.bgElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.textMuted, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Text(title,
                style: AppTheme.bodyMedium.copyWith(color: AppTheme.textMuted)),
          ),
          Text(value,
              style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _settingsTile(
    IconData icon,
    String title,
    bool? toggle, {
    String? subtitle,
    ValueChanged<bool>? onChanged,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppTheme.bgElevated,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: AppTheme.textMuted, size: 20),
          ),
          const SizedBox(width: 14),
          Expanded(child: Text(title, style: AppTheme.bodyMedium)),
          if (toggle != null && onChanged != null)
            Switch(
              value: toggle,
              onChanged: onChanged,
              activeThumbColor: AppTheme.primary,
              inactiveTrackColor: AppTheme.bgElevated,
            )
          else if (subtitle != null)
            Text(subtitle, style: AppTheme.bodySmall),
        ],
      ),
    );
  }
}
