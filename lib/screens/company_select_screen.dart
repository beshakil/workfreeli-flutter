import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/auth_state.dart';
import '../core/models/auth_models.dart';

class CompanySelectScreen extends ConsumerStatefulWidget {
  const CompanySelectScreen({super.key});

  @override
  ConsumerState<CompanySelectScreen> createState() =>
      _CompanySelectScreenState();
}

class _CompanySelectScreenState extends ConsumerState<CompanySelectScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeIn),
    );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  Future<void> _select(String companyId) async {
    await ref.read(authNotifierProvider.notifier).selectCompany(companyId);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final companies = authState.companies ?? [];
    final isLoading = authState.isLoading;
    final error =
        authState.step == AuthStep.companyPending ? authState.error : null;

    return Scaffold(
      backgroundColor: AppTheme.bg,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFF0F1117), Color(0xFF16132A), Color(0xFF0F1117)],
          ),
        ),
        child: Center(
          child: SlideTransition(
            position: _slideAnimation,
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 400),
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppTheme.bgCard,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.border),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 32,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Brand
                      Row(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              gradient: AppTheme.accentGradient,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Center(
                              child: Text('F',
                                  style: AppTheme.headingSmall.copyWith(
                                      color: Colors.white, fontSize: 20)),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                const LinearGradient(colors: [
                              AppTheme.textPrimary,
                              AppTheme.primaryLight,
                            ]).createShader(bounds),
                            child: Text('Workfreeli',
                                style: AppTheme.headingMedium.copyWith(
                                    color: Colors.white, fontSize: 24)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      Text('Select workspace', style: AppTheme.headingMedium),
                      const SizedBox(height: 6),
                      Text(
                        'Your account belongs to multiple workspaces. Choose one to continue.',
                        style: AppTheme.bodySmall.copyWith(height: 1.5),
                      ),
                      const SizedBox(height: 24),

                      // Error banner
                      if (error != null)
                        Container(
                          padding: const EdgeInsets.all(12),
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: AppTheme.danger.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                                color: AppTheme.danger.withValues(alpha: 0.2)),
                          ),
                          child: Text(error,
                              style: AppTheme.bodySmall
                                  .copyWith(color: AppTheme.danger)),
                        ),

                      // Company list
                      ...companies.map((c) => _CompanyTile(
                            company: c,
                            isLoading: isLoading,
                            onTap: () => _select(c.companyId),
                          )),

                      const SizedBox(height: 8),
                      Center(
                        child: GestureDetector(
                          onTap: () => ref
                              .read(authNotifierProvider.notifier)
                              .logout(),
                          child: Text(
                            'Sign out',
                            style: AppTheme.caption.copyWith(
                              color: AppTheme.textDim,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CompanyTile extends StatelessWidget {
  const _CompanyTile({
    required this.company,
    required this.isLoading,
    required this.onTap,
  });

  final Company company;
  final bool isLoading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final initials = company.companyName.isNotEmpty
        ? company.companyName
            .split(' ')
            .take(2)
            .map((w) => w.isNotEmpty ? w[0].toUpperCase() : '')
            .join()
        : '?';

    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.bgElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                company.companyName,
                style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w500),
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textDim, size: 20),
          ],
        ),
      ),
    );
  }
}
