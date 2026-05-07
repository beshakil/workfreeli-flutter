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
    final error = authState.step == AuthStep.unauthenticated
        ? authState.error
        : null;

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
                              child: Text(
                                'F',
                                style: AppTheme.headingSmall.copyWith(
                                    color: Colors.white, fontSize: 20),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          ShaderMask(
                            shaderCallback: (bounds) =>
                                const LinearGradient(colors: [
                              AppTheme.textPrimary,
                              AppTheme.primaryLight,
                            ]).createShader(bounds),
                            child: Text(
                              'Workfreeli',
                              style: AppTheme.headingMedium.copyWith(
                                  color: Colors.white, fontSize: 24),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),

                      Text('Welcome back', style: AppTheme.headingMedium),
                      const SizedBox(height: 6),
                      Text(
                        _otpLoginMode
                            ? "Enter your email and we'll send you a one-time code."
                            : 'Sign in to your workspace to continue collaborating.',
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

                      // Email field
                      Text('Email address',
                          style: AppTheme.bodySmall
                              .copyWith(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      _buildTextField(
                        controller: _emailController,
                        hint: 'you@example.com',
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 16),

                      // Password field (hidden in OTP mode)
                      if (!_otpLoginMode) ...[
                        Text('Password',
                            style: AppTheme.bodySmall
                                .copyWith(fontWeight: FontWeight.w500)),
                        const SizedBox(height: 6),
                        _buildTextField(
                          controller: _passwordController,
                          hint: 'Enter your password',
                          obscure: _obscurePassword,
                          suffix: IconButton(
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_off_rounded
                                  : Icons.visibility_rounded,
                              color: AppTheme.textDim,
                              size: 20,
                            ),
                            onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword),
                          ),
                        ),
                        const SizedBox(height: 24),
                      ] else
                        const SizedBox(height: 24),

                      // Sign In button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: AppTheme.primaryGradient,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primary.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: isLoading ? null : _handleSignIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10)),
                            ),
                            child: isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.5,
                                      valueColor: AlwaysStoppedAnimation(
                                          Colors.white),
                                    ),
                                  )
                                : Text(
                                    _otpLoginMode
                                        ? 'Send OTP Code'
                                        : 'Sign In',
                                    style: AppTheme.bodyLarge.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600),
                                  ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Toggle OTP / password mode
                      Center(
                        child: GestureDetector(
                          onTap: () =>
                              setState(() => _otpLoginMode = !_otpLoginMode),
                          child: Text.rich(
                            TextSpan(
                              text: _otpLoginMode
                                  ? 'Sign in with password instead'
                                  : 'Sign in with email OTP instead',
                              style: AppTheme.caption.copyWith(
                                color: AppTheme.primaryLight,
                                fontWeight: FontWeight.w500,
                              ),
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
      style: AppTheme.bodyLarge,
      onSubmitted: (_) => _handleSignIn(),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTheme.bodyLarge.copyWith(color: AppTheme.textDim),
        filled: true,
        fillColor: AppTheme.bgElevated,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppTheme.primary, width: 1.5),
        ),
        suffixIcon: suffix,
      ),
    );
  }
}
