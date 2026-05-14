import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
  final List<TextEditingController> _otpControllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpFocusNodes = List.generate(6, (_) => FocusNode());
  bool _trustDevice = false;
  bool _resent = false;
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
    for (var controller in _otpControllers) {
      controller.dispose();
    }
    for (var focusNode in _otpFocusNodes) {
      focusNode.dispose();
    }
    _animController.dispose();
    super.dispose();
  }

  Future<void> _handleVerify() async {
    final code = _otpControllers.map((c) => c.text).join();
    if (code.length != 6) return;
    await ref
        .read(authNotifierProvider.notifier)
        .verifyOtp(code, trustDevice: _trustDevice);
  }

  void _onOtpChanged(int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _otpFocusNodes[index + 1].requestFocus();
    } else if (value.isEmpty && index > 0) {
      // Handle backspace - move to previous box
      _otpFocusNodes[index - 1].requestFocus();
    }
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
                                    'Verify your identity',
                                    style: (_isDarkMode
                                            ? AppTheme.headingLarge_dm
                                            : AppTheme.headingLarge)
                                        .copyWith(fontSize: 28),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Center(
                                  child: Text.rich(
                                    TextSpan(
                                      text: "We've sent a 6-digit code to ",
                                      style: _isDarkMode
                                          ? AppTheme.bodyMedium_dm
                                              .copyWith(height: 1.6)
                                          : AppTheme.bodyMedium
                                              .copyWith(height: 1.6),
                                      children: [
                                        TextSpan(
                                          text: email,
                                          style: (_isDarkMode
                                                  ? AppTheme.bodyMedium_dm
                                                  : AppTheme.bodyMedium)
                                              .copyWith(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
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

                                // OTP input label
                                Text(
                                  'Verification code',
                                  style: (_isDarkMode
                                          ? AppTheme.bodyMedium_dm
                                          : AppTheme.bodyMedium)
                                      .copyWith(fontWeight: FontWeight.w600),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: List.generate(6, (index) {
                                    return SizedBox(
                                      width: 48,
                                      height: 52,
                                      child: TextField(
                                        controller: _otpControllers[index],
                                        focusNode: _otpFocusNodes[index],
                                        keyboardType: TextInputType.number,
                                        textAlign: TextAlign.center,
                                        maxLength: 1,
                                        style: (_isDarkMode
                                                ? AppTheme.headingMedium_dm
                                                : AppTheme.headingMedium)
                                            .copyWith(fontSize: 24),
                                        onChanged: (value) =>
                                            _onOtpChanged(index, value),
                                        onSubmitted: (_) {
                                          if (index < 5) {
                                            _otpFocusNodes[index + 1]
                                                .requestFocus();
                                          } else {
                                            _handleVerify();
                                          }
                                        },
                                        inputFormatters: [
                                          FilteringTextInputFormatter
                                              .digitsOnly,
                                        ],
                                        decoration: InputDecoration(
                                          counterText: '',
                                          hintText: '·',
                                          hintStyle: (_isDarkMode
                                                  ? AppTheme.headingMedium_dm
                                                  : AppTheme.headingMedium)
                                              .copyWith(
                                            color: _isDarkMode
                                                ? AppTheme.textDim_dm
                                                : AppTheme.textDim,
                                            fontSize: 24,
                                          ),
                                          filled: true,
                                          fillColor: _isDarkMode
                                              ? AppTheme.bgElevated_dm
                                              : Colors.white,
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 12),
                                          border: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            borderSide: BorderSide(
                                                color: _isDarkMode
                                                    ? AppTheme.border_dm
                                                    : AppTheme.border,
                                                width: 1.5),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            borderSide: BorderSide(
                                                color: _isDarkMode
                                                    ? AppTheme.border_dm
                                                    : AppTheme.border,
                                                width: 1.5),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            borderSide: BorderSide(
                                                color: _isDarkMode
                                                    ? AppTheme.accentDark_dm
                                                    : AppTheme.primary,
                                                width: 2),
                                          ),
                                        ),
                                      ),
                                    );
                                  }),
                                ),
                                const SizedBox(height: 20),

                                // Trust device toggle
                                GestureDetector(
                                  onTap: () => setState(
                                      () => _trustDevice = !_trustDevice),
                                  child: Row(
                                    children: [
                                      AnimatedContainer(
                                        duration:
                                            const Duration(milliseconds: 200),
                                        width: 20,
                                        height: 20,
                                        decoration: BoxDecoration(
                                          color: _trustDevice
                                              ? (_isDarkMode
                                                  ? AppTheme.accentDark_dm
                                                  : AppTheme.primary)
                                              : (_isDarkMode
                                                  ? AppTheme.bgElevated_dm
                                                  : Colors.white),
                                          borderRadius:
                                              BorderRadius.circular(5),
                                          border: Border.all(
                                            color: _trustDevice
                                                ? Colors.transparent
                                                : (_isDarkMode
                                                    ? AppTheme.border_dm
                                                    : AppTheme.border),
                                            width: 1.5,
                                          ),
                                        ),
                                        child: _trustDevice
                                            ? const Icon(Icons.check_rounded,
                                                color: Colors.white, size: 14)
                                            : null,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Trust this device (skip OTP next time)',
                                          style: _isDarkMode
                                              ? AppTheme.bodyMedium_dm
                                              : AppTheme.bodySmall,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Verify button
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
                                          isLoading ? null : _handleVerify,
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
                                              'Verify & Continue',
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

                                // Resend link
                                Center(
                                  child: GestureDetector(
                                    onTap: _resent ? null : _resendOtp,
                                    child: Text.rich(
                                      TextSpan(
                                        text: "Didn't receive the code? ",
                                        style: _isDarkMode
                                            ? AppTheme.caption_dm
                                            : AppTheme.caption,
                                        children: [
                                          TextSpan(
                                            text: _resent ? 'Sent!' : 'Resend',
                                            style: (_isDarkMode
                                                    ? AppTheme.caption_dm
                                                    : AppTheme.caption)
                                                .copyWith(
                                              color: _resent
                                                  ? (_isDarkMode
                                                      ? AppTheme.accentDark_dm
                                                      : AppTheme.accent)
                                                  : (_isDarkMode
                                                      ? AppTheme.accentDark_dm
                                                      : AppTheme.primary),
                                              fontWeight: FontWeight.w600,
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
