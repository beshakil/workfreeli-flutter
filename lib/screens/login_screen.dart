import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/auth_state.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _otpLoginMode = false;
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
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleSignIn() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;
    final notifier = ref.read(authNotifierProvider.notifier);
    if (_otpLoginMode) {
      await notifier.signinWithOtp(email);
    } else {
      final password = _passwordController.text;
      if (password.isEmpty) return;
      await notifier.validate(email, password);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;
    final error =
        authState.step == AuthStep.unauthenticated ? authState.error : null;

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

                                // Welcome Text
                                Center(
                                  child: Text(
                                    'Welcome back',
                                    style: (_isDarkMode
                                            ? AppTheme.headingLarge_dm
                                            : AppTheme.headingLarge)
                                        .copyWith(fontSize: 32),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Center(
                                  child: Text(
                                    _otpLoginMode
                                        ? "Enter your email and we'll send you a one-time code."
                                        : 'Sign in to your workspace to continue collaborating.',
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

                                // Email field
                                Text(
                                  'Email address',
                                  style: (_isDarkMode
                                          ? AppTheme.bodyMedium_dm
                                          : AppTheme.bodyMedium)
                                      .copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 8),
                                _buildTextField(
                                  controller: _emailController,
                                  hint: 'you@example.com',
                                  keyboardType: TextInputType.emailAddress,
                                ),
                                const SizedBox(height: 20),

                                // Password field (hidden in OTP mode)
                                if (!_otpLoginMode) ...[
                                  Text(
                                    'Password',
                                    style: (_isDarkMode
                                            ? AppTheme.bodyMedium_dm
                                            : AppTheme.bodyMedium)
                                        .copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 8),
                                  _buildTextField(
                                    controller: _passwordController,
                                    hint: 'Enter your password',
                                    obscure: _obscurePassword,
                                    suffix: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off_rounded
                                            : Icons.visibility_rounded,
                                        color: _isDarkMode
                                            ? AppTheme.textMuted_dm
                                            : AppTheme.textMuted,
                                        size: 20,
                                      ),
                                      onPressed: () => setState(() =>
                                          _obscurePassword = !_obscurePassword),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                ] else
                                  const SizedBox(height: 24),

                                // Sign In button
                                SizedBox(
                                  width: double.infinity,
                                  height: 52,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient: _isDarkMode
                                          ? AppTheme.primaryGradient_dm
                                          : AppTheme.primaryGradient,
                                      borderRadius: BorderRadius.circular(12),
                                      boxShadow: [
                                        BoxShadow(
                                          color: (_isDarkMode
                                                  ? AppTheme.primaryDark_dm
                                                  : AppTheme.primary)
                                              .withValues(alpha: 0.25),
                                          blurRadius: 16,
                                          offset: const Offset(0, 6),
                                        ),
                                      ],
                                    ),
                                    child: ElevatedButton(
                                      onPressed:
                                          isLoading ? null : _handleSignIn,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12)),
                                      ),
                                      child: isLoading
                                          ? const SizedBox(
                                              width: 24,
                                              height: 24,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2.5,
                                                valueColor:
                                                    AlwaysStoppedAnimation(
                                                        Colors.white),
                                              ),
                                            )
                                          : Text(
                                              _otpLoginMode
                                                  ? 'Send OTP Code'
                                                  : 'Sign In',
                                              style: (_isDarkMode
                                                      ? AppTheme.bodyLarge_dm
                                                      : AppTheme.bodyLarge)
                                                  .copyWith(
                                                      color: Colors.white,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 16),
                                            ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 20),

                                // Toggle OTP / password mode
                                Center(
                                  child: GestureDetector(
                                    onTap: () => setState(
                                        () => _otpLoginMode = !_otpLoginMode),
                                    child: Text.rich(
                                      TextSpan(
                                        text: _otpLoginMode
                                            ? 'Sign in with password instead'
                                            : 'Sign in with email OTP instead',
                                        style: (_isDarkMode
                                                ? AppTheme.bodyMedium_dm
                                                : AppTheme.bodyMedium)
                                            .copyWith(
                                          color: _isDarkMode
                                              ? AppTheme.accentDark_dm
                                              : AppTheme.primary,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
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

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    TextInputType keyboardType = TextInputType.text,
    bool obscure = false,
    Widget? suffix,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscure,
      style: (_isDarkMode ? AppTheme.bodyLarge_dm : AppTheme.bodyLarge),
      onSubmitted: (_) => _handleSignIn(),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: (_isDarkMode ? AppTheme.bodyMedium_dm : AppTheme.bodyMedium)
            .copyWith(
                color: _isDarkMode ? AppTheme.textDim_dm : AppTheme.textDim),
        filled: true,
        fillColor: _isDarkMode ? AppTheme.bgElevated_dm : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
              color: _isDarkMode ? AppTheme.border_dm : AppTheme.border,
              width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
              color: _isDarkMode ? AppTheme.border_dm : AppTheme.border,
              width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(
              color: _isDarkMode ? AppTheme.accentDark_dm : AppTheme.primary,
              width: 2),
        ),
        suffixIcon: suffix,
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
