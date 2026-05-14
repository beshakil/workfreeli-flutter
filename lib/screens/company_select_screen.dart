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
  bool _isDarkMode = false;

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
      backgroundColor: _isDarkMode ? AppTheme.bg_dm : AppTheme.bg,
      body: SafeArea(
        child: Stack(
          children: [
            // Background gradient
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _isDarkMode
                      ? const [
                          Color(0xFF0D1117),
                          Color(0xFF161B27),
                          Color(0xFF0D1117)
                        ]
                      : const [
                          Color(0xFFF1F5F9),
                          Color(0xFFE2E8F0),
                          Color(0xFFF1F5F9)
                        ],
                ),
              ),
            ),
            // Theme toggle in top-right corner
            Positioned(
              top: 8,
              right: 8,
              child: _buildThemeToggle(),
            ),
            // Main content
            Center(
              child: SlideTransition(
                position: _slideAnimation,
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: EdgeInsets.only(
                          left: 24,
                          right: 24,
                          top: 16,
                          bottom: constraints.maxHeight * 0.08,
                        ),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 32, vertical: 40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Brand Logo
                                Center(
                                  child: Image.asset(
                                    _isDarkMode
                                        ? 'assets/images/workfreeli-dark-logo.png'
                                        : 'assets/images/workfreeli-light-logo.png',
                                    height: 50,
                                    fit: BoxFit.contain,
                                  ),
                                ),
                                const SizedBox(height: 40),

                                // Title
                                Center(
                                  child: Text(
                                    'Select workspace',
                                    style: (_isDarkMode
                                            ? AppTheme.headingLarge_dm
                                            : AppTheme.headingLarge)
                                        .copyWith(fontSize: 28),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Center(
                                  child: Text(
                                    'Your account belongs to multiple workspaces. Choose one to continue.',
                                    style: _isDarkMode
                                        ? AppTheme.bodyMedium_dm
                                            .copyWith(height: 1.6)
                                        : AppTheme.bodyMedium
                                            .copyWith(height: 1.6),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                                const SizedBox(height: 28),

                                // Error banner
                                if (error != null)
                                  Container(
                                    padding: const EdgeInsets.all(14),
                                    margin: const EdgeInsets.only(bottom: 20),
                                    decoration: BoxDecoration(
                                      color: (_isDarkMode
                                              ? AppTheme.danger_dm
                                              : AppTheme.danger)
                                          .withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                          color: (_isDarkMode
                                                  ? AppTheme.danger_dm
                                                  : AppTheme.danger)
                                              .withValues(alpha: 0.2)),
                                    ),
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.error_outline_rounded,
                                          color: _isDarkMode
                                              ? AppTheme.danger_dm
                                              : AppTheme.danger,
                                          size: 20,
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Text(
                                            error,
                                            style: (_isDarkMode
                                                    ? AppTheme.bodyMedium_dm
                                                    : AppTheme.bodyMedium)
                                                .copyWith(
                                              color: _isDarkMode
                                                  ? AppTheme.danger_dm
                                                  : AppTheme.danger,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // Company list
                                ...companies.map((c) => _CompanyTile(
                                      company: c,
                                      isLoading: isLoading,
                                      isDarkMode: _isDarkMode,
                                      onTap: () => _select(c.companyId),
                                    )),

                                const SizedBox(height: 8),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemeToggle() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _isDarkMode = !_isDarkMode;
        });
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: _isDarkMode ? AppTheme.bgElevated_dm : AppTheme.accentSoft,
          shape: BoxShape.circle,
          border: Border.all(
            color: _isDarkMode ? AppTheme.border_dm : AppTheme.border,
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _isDarkMode ? 0.35 : 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Icon(
          _isDarkMode ? Icons.nightlight_round : Icons.wb_sunny_rounded,
          size: 22,
          color: _isDarkMode ? AppTheme.accentDark_dm : AppTheme.warning,
        ),
      ),
    );
  }
}

class _CompanyTile extends StatelessWidget {
  const _CompanyTile({
    required this.company,
    required this.isLoading,
    required this.isDarkMode,
    required this.onTap,
  });

  final Company company;
  final bool isLoading;
  final bool isDarkMode;
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
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDarkMode ? AppTheme.bgElevated_dm : AppTheme.bgElevated,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDarkMode ? AppTheme.border_dm : AppTheme.border,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                gradient: isDarkMode
                    ? AppTheme.primaryGradient_dm
                    : AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: (isDarkMode
                            ? AppTheme.primaryDark_dm
                            : AppTheme.primary)
                        .withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  initials,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                company.companyName,
                style: (isDarkMode ? AppTheme.bodyLarge_dm : AppTheme.bodyLarge)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: isDarkMode ? AppTheme.textDim_dm : AppTheme.textDim,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}
