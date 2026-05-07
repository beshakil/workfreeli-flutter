import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/auth_state.dart';

class OtpScreen extends ConsumerStatefulWidget {
  const OtpScreen({super.key});

  @override
  ConsumerState<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends ConsumerState<OtpScreen>
    with SingleTickerProviderStateMixin {
  final _otpController = TextEditingController();
  bool _trustDevice = false;
  bool _resent = false;

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
    _otpController.dispose();
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    final code = _otpController.text.trim();
    if (code.length != 6) return;
    await ref
        .read(authNotifierProvider.notifier)
        .verifyOtp(code, trustDevice: _trustDevice);
  }

  Future<void> _resendOtp() async {
    final email = ref.read(authNotifierProvider).email;
    if (email == null) return;
    setState(() => _resent = true);
    await ref.read(authNotifierProvider.notifier).signinWithOtp(email);
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) setState(() => _resent = false);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);
    final isLoading = authState.isLoading;
    final email = authState.email ?? '';
    final error =
        authState.step == AuthStep.otpPending ? authState.error : null;

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

                      Text('Verify your identity',
                          style: AppTheme.headingMedium),
                      const SizedBox(height: 6),
                      Text.rich(
                        TextSpan(
                          text: "We've sent a 6-digit code to ",
                          style: AppTheme.bodySmall.copyWith(height: 1.5),
                          children: [
                            TextSpan(
                              text: email,
                              style: AppTheme.bodySmall.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ],
                        ),
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

                      // OTP input
                      Text('Verification code',
                          style: AppTheme.bodySmall
                              .copyWith(fontWeight: FontWeight.w500)),
                      const SizedBox(height: 6),
                      TextField(
                        controller: _otpController,
                        keyboardType: TextInputType.number,
                        textAlign: TextAlign.center,
                        maxLength: 6,
                        style: AppTheme.headingMedium.copyWith(
                          letterSpacing: 8,
                          fontSize: 24,
                        ),
                        onSubmitted: (_) => _handleVerify(),
                        decoration: InputDecoration(
                          counterText: '',
                          hintText: '······',
                          hintStyle: AppTheme.headingMedium.copyWith(
                            color: AppTheme.textDim,
                            letterSpacing: 8,
                            fontSize: 24,
                          ),
                          filled: true,
                          fillColor: AppTheme.bgElevated,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 16),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: AppTheme.border),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide:
                                const BorderSide(color: AppTheme.border),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: const BorderSide(
                                color: AppTheme.primary, width: 1.5),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Trust device toggle
                      GestureDetector(
                        onTap: () =>
                            setState(() => _trustDevice = !_trustDevice),
                        child: Row(
                          children: [
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                color: _trustDevice
                                    ? AppTheme.primary
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(5),
                                border: Border.all(
                                  color: _trustDevice
                                      ? AppTheme.primary
                                      : AppTheme.border,
                                  width: 1.5,
                                ),
                              ),
                              child: _trustDevice
                                  ? const Icon(Icons.check_rounded,
                                      color: Colors.white, size: 14)
                                  : null,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              'Trust this device (skip OTP next time)',
                              style: AppTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Verify button
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
                            onPressed: isLoading ? null : _handleVerify,
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
                                : Text('Verify & Continue',
                                    style: AppTheme.bodyLarge.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w600)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Resend link
                      Center(
                        child: GestureDetector(
                          onTap: _resent ? null : _resendOtp,
                          child: Text.rich(
                            TextSpan(
                              text: "Didn't receive the code? ",
                              style: AppTheme.caption,
                              children: [
                                TextSpan(
                                  text: _resent ? 'Sent!' : 'Resend',
                                  style: AppTheme.caption.copyWith(
                                    color: _resent
                                        ? AppTheme.accent
                                        : AppTheme.primaryLight,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
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
