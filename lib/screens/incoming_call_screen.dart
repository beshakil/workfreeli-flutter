import 'dart:async';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/calls/call_signaling_service.dart';
import '../features/calls/calls_providers.dart';
import '../features/calls/jitsi_service.dart';
import '../features/user/user_providers.dart';
import '../features/xmpp/xmpp_provider.dart';
import '../services/call_notification_service.dart';
import '../theme/app_theme.dart';

/// Full-screen ringing UI shown when:
///  - The app is opened from a background/terminated FCM notification, OR
///  - An incoming call arrives while the app is in the foreground and the user
///    tapped a notification "Accept" action button.
///
/// [callData]    — raw FCM/XMPP payload (keys: user_fullname, user_img,
///                 conversation_id, set_calltype / call_type, convname).
/// [autoAccept]  — true when the user already tapped "Accept" on the
///                 notification action; the screen skips the ringing UI
///                 and accepts immediately.
class IncomingCallScreen extends ConsumerStatefulWidget {
  const IncomingCallScreen({
    super.key,
    required this.callData,
    this.autoAccept = false,
  });

  final Map<String, dynamic> callData;
  final bool autoAccept;

  @override
  ConsumerState<IncomingCallScreen> createState() => _IncomingCallScreenState();
}

class _IncomingCallScreenState extends ConsumerState<IncomingCallScreen>
    with TickerProviderStateMixin {
  // ── Derived call info ───────────────────────────────────────────────────────
  late final String _callerName;
  late final String? _callerImg;
  late final String _conversationId;
  late final bool _isVideo;
  late final String _convTitle;

  // ── Animation ───────────────────────────────────────────────────────────────
  late final AnimationController _pulseCtrl;
  late final AnimationController _ringCtrl;
  late final Animation<double> _pulse1;
  late final Animation<double> _pulse2;
  late final Animation<double> _ringRotation;

  // ── Timeout ─────────────────────────────────────────────────────────────────
  Timer? _timeoutTimer;
  int _remainingSeconds = 60;
  bool _isHandled = false; // prevents accept/decline from firing twice

  @override
  void initState() {
    super.initState();
    _parseCallData();
    _initAnimations();
    _startTimeout();
    if (widget.autoAccept) {
      // Small delay so the screen is built before we trigger the async flow.
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _handleAccept());
    }
  }

  void _parseCallData() {
    final d = widget.callData;
    _callerName = d['user_fullname']?.toString() ?? 'Unknown';
    _callerImg = d['user_img']?.toString();
    _conversationId = d['conversation_id']?.toString() ?? '';
    _isVideo =
        (d['call_type'] ?? d['set_calltype'] ?? '').toString() == 'video';
    _convTitle = (d['convname'] ?? d['conv_title'] ?? '').toString();
  }

  void _initAnimations() {
    _pulseCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat();

    _ringCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _pulse1 = Tween<double>(begin: 1.0, end: 1.35).animate(
      CurvedAnimation(
        parent: _pulseCtrl,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );
    _pulse2 = Tween<double>(begin: 1.0, end: 1.6).animate(
      CurvedAnimation(
        parent: _pulseCtrl,
        curve: const Interval(0.2, 0.8, curve: Curves.easeOut),
      ),
    );
    _ringRotation = Tween<double>(begin: -0.04, end: 0.04).animate(
      CurvedAnimation(parent: _ringCtrl, curve: Curves.easeInOut),
    );
  }

  void _startTimeout() {
    _timeoutTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) { t.cancel(); return; }
      setState(() => _remainingSeconds--);
      if (_remainingSeconds <= 0) {
        t.cancel();
        _dismissMissed();
      }
    });
  }

  // ── Actions ─────────────────────────────────────────────────────────────────

  Future<void> _handleAccept() async {
    if (_isHandled) return;
    _isHandled = true;
    _timeoutTimer?.cancel();
    await CallNotificationService.dismissCallNotification();

    final me = ref.read(meProvider).valueOrNull;
    if (me == null) { _pop(); return; }

    final granted = await JitsiService.requestCallPermissions();
    if (!granted) { _pop(); return; }

    // Show progress so the user knows we're connecting.
    if (mounted) {
      setState(() {}); // triggers the "Connecting…" state via _isHandled
    }

    try {
      final jwt = await CallSignalingService.acceptCall(
        userId: me.id,
        conversationId: _conversationId,
      );
      if (jwt == null || jwt.isEmpty) { _pop(); return; }

      final fullName = '${me.firstname} ${me.lastname}'.trim();

      await JitsiService.join(
        conversationId: _conversationId,
        jwtToken: jwt,
        isVideo: _isVideo,
        userName: fullName,
        userEmail: me.email,
        userAvatar: me.img,
        onReadyToClose: () async {
          try {
            await CallSignalingService.hangupCall(
              userId: me.id,
              userFullName: fullName,
              conversationId: _conversationId,
            );
          } catch (_) {}
          ref.invalidate(callHistoryProvider);
        },
      );
    } catch (e) {
      debugPrint('[IncomingCallScreen] Accept failed: $e');
    }

    _pop();
  }

  Future<void> _handleDecline() async {
    if (_isHandled) return;
    _isHandled = true;
    _timeoutTimer?.cancel();
    await CallNotificationService.dismissCallNotification();

    final me = ref.read(meProvider).valueOrNull;
    if (me != null) {
      try {
        await CallSignalingService.hangupCall(
          userId: me.id,
          userFullName: '${me.firstname} ${me.lastname}'.trim(),
          conversationId: _conversationId,
          endCall: false,
        );
      } catch (_) {}
    }
    _pop();
  }

  void _dismissMissed() {
    if (_isHandled) return;
    _isHandled = true;
    CallNotificationService.dismissCallNotification();
    _pop();
  }

  void _pop() {
    if (!mounted) return;
    // Always clear the provider so the next incoming call triggers the listener.
    ref.read(incomingCallProvider.notifier).dismiss();
    Navigator.of(context).pop();
  }

  @override
  void dispose() {
    _timeoutTimer?.cancel();
    _pulseCtrl.dispose();
    _ringCtrl.dispose();
    super.dispose();
  }

  // ── XMPP hangup listener (caller cancelled while screen is open) ────────────

  @override
  Widget build(BuildContext context) {
    // Dismiss if the backend sends hangup via XMPP while this screen is visible.
    ref.listen(xmppEventStreamProvider, (_, next) {
      if (!next.hasValue) return;
      final type = next.value?.type ?? '';
      if (type == 'jitsi_send_hangup' || type == 'jitsi_send_accept') {
        _dismissMissed();
      }
    });

    // Force portrait so the full-screen UI always looks correct.
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

    return PopScope(
      canPop: false, // user must tap Accept or Decline
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF0A1628), Color(0xFF0F2750), Color(0xFF071020)],
        ),
      ),
      child: SafeArea(
        child: _isHandled
            ? _buildConnectingState()
            : _buildRingingState(),
      ),
    );
  }

  Widget _buildConnectingState() {
    return const Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CircularProgressIndicator(color: Colors.white),
          SizedBox(height: 20),
          Text(
            'Connecting…',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRingingState() {
    return Column(
      children: [
        const SizedBox(height: 32),
        _buildStatusRow(),
        const Spacer(flex: 2),
        _buildAvatarSection(),
        const Spacer(flex: 1),
        _buildCallerInfo(),
        const Spacer(flex: 2),
        _buildCountdown(),
        const SizedBox(height: 16),
        _buildActionButtons(),
        const SizedBox(height: 48),
      ],
    );
  }

  Widget _buildStatusRow() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              _isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
              color: Colors.white70,
              size: 16,
            ),
            const SizedBox(width: 6),
            Text(
              'Incoming ${_isVideo ? 'video' : 'audio'} call',
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 14,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
        if (_convTitle.isNotEmpty && _convTitle != _callerName) ...[
          const SizedBox(height: 4),
          Text(
            _convTitle,
            style: const TextStyle(
              color: Color(0xFF6B8CC4),
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildAvatarSection() {
    return SizedBox(
      width: 200,
      height: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Outer pulse ring
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Transform.scale(
              scale: _pulse2.value,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.18),
                    width: 2,
                  ),
                ),
              ),
            ),
          ),
          // Inner pulse ring
          AnimatedBuilder(
            animation: _pulseCtrl,
            builder: (_, __) => Transform.scale(
              scale: _pulse1.value,
              child: Container(
                width: 138,
                height: 138,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: AppTheme.primary.withValues(alpha: 0.35),
                    width: 2.5,
                  ),
                ),
              ),
            ),
          ),
          // Ringing bell rotation on avatar
          AnimatedBuilder(
            animation: _ringRotation,
            builder: (_, child) => Transform.rotate(
              angle: _ringRotation.value,
              child: child,
            ),
            child: _buildAvatar(120),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(double size) {
    final hasValidUrl = _callerImg != null &&
        _callerImg!.isNotEmpty &&
        (_callerImg!.startsWith('http://') || _callerImg!.startsWith('https://'));

    if (hasValidUrl) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: _callerImg!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorWidget: (_, __, ___) => _initialsAvatar(size),
        ),
      );
    }
    return _initialsAvatar(size);
  }

  Widget _initialsAvatar(double size) {
    const palettes = [
      [Color(0xFF6366F1), Color(0xFF8B5CF6)],
      [Color(0xFFEC4899), Color(0xFFF43F5E)],
      [Color(0xFF3B82F6), Color(0xFF06B6D4)],
      [Color(0xFF10B981), Color(0xFF059669)],
      [Color(0xFFF59E0B), Color(0xFFEF4444)],
    ];
    final colors = palettes[_callerName.hashCode.abs() % palettes.length];
    final words = _callerName.trim().split(RegExp(r'\s+'));
    final initials = words.length >= 2
        ? '${words[0][0]}${words[1][0]}'.toUpperCase()
        : _callerName.isNotEmpty
            ? _callerName[0].toUpperCase()
            : '?';

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: colors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Text(
          initials,
          style: TextStyle(
            color: Colors.white,
            fontSize: size * 0.33,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildCallerInfo() {
    return Column(
      children: [
        Text(
          _callerName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 28,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 8),
        _AnimatedDotsLabel(
          prefix: _isVideo ? 'Video calling' : 'Calling',
        ),
      ],
    );
  }

  Widget _buildCountdown() {
    final color = _remainingSeconds <= 10
        ? const Color(0xFFEF4444)
        : Colors.white38;
    return Text(
      '$_remainingSeconds s',
      style: TextStyle(
        color: color,
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildActionButtons() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _CircleButton(
          icon: Icons.call_end_rounded,
          color: const Color(0xFFEF4444),
          label: 'Decline',
          size: 72,
          onTap: _handleDecline,
        ),
        _CircleButton(
          icon: _isVideo ? Icons.videocam_rounded : Icons.phone_rounded,
          color: const Color(0xFF22C55E),
          label: 'Accept',
          size: 72,
          onTap: _handleAccept,
        ),
      ],
    );
  }
}

// ── Animated "Calling…" dots ──────────────────────────────────────────────────

class _AnimatedDotsLabel extends StatefulWidget {
  const _AnimatedDotsLabel({required this.prefix});
  final String prefix;

  @override
  State<_AnimatedDotsLabel> createState() => _AnimatedDotsLabelState();
}

class _AnimatedDotsLabelState extends State<_AnimatedDotsLabel> {
  int _dots = 1;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 600), (_) {
      if (mounted) setState(() => _dots = (_dots % 3) + 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(
      '${widget.prefix}${'.' * _dots}',
      style: const TextStyle(
        color: Color(0xFF93C5FD),
        fontSize: 16,
        fontWeight: FontWeight.w400,
        letterSpacing: 0.5,
      ),
    );
  }
}

// ── Circular action button ────────────────────────────────────────────────────

class _CircleButton extends StatelessWidget {
  const _CircleButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.size,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String label;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: color.withValues(alpha: 0.45),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: size * 0.44),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
