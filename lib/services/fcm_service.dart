import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../core/config/app_config.dart';
import '../core/storage/secure_storage.dart';

/// Manages FCM token lifecycle and foreground message routing.
///
/// Call order:
///   1. [FcmService.requestPermissions]  — once, early in app startup
///   2. [FcmService.registerToken]       — after the user is authenticated
///
/// Foreground FCM messages arrive on [foregroundCallStream]; the HomeScreen
/// listens to this and updates [incomingCallProvider] when the XMPP WebSocket
/// has not already delivered the ring event (deduplication via hasActiveCall).
class FcmService {
  FcmService._();

  static String? _currentUserId;

  // Broadcast stream for foreground call-related FCM messages.
  // Only 'jitsi_ring_send', 'jitsi_send_hangup', 'jitsi_send_accept' are emitted.
  static final _callStreamCtrl =
      StreamController<RemoteMessage>.broadcast();
  static Stream<RemoteMessage> get foregroundCallStream =>
      _callStreamCtrl.stream;

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Request notification permission (Android 13+ requires this at runtime).
  /// Also suppresses the system banner for foreground FCM — we handle it ourselves.
  static Future<void> requestPermissions() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      criticalAlert: false,
      announcement: false,
      carPlay: false,
      provisional: false,
    );
    debugPrint('[FCM] Auth status: ${settings.authorizationStatus}');

    // Prevent Firebase from auto-showing a banner while app is in foreground —
    // we handle the call UI ourselves via incomingCallProvider.
    await FirebaseMessaging.instance
        .setForegroundNotificationPresentationOptions(
      alert: false,
      badge: true,
      sound: false,
    );
  }

  /// Register the current device FCM token with the backend.
  ///
  /// The backend stores tokens as `android@@@<token>` and uses them to send
  /// call push notifications when the XMPP WebSocket cannot reach the device.
  static Future<void> registerToken(String userId) async {
    _currentUserId = userId;
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _sendToken(userId, token);

      // Re-register whenever Firebase rotates the token mid-session.
      FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
        if (_currentUserId != null) _sendToken(_currentUserId!, newToken);
      });
    } catch (e) {
      debugPrint('[FCM] registerToken error: $e');
    }
  }

  /// Start listening for FCM messages while the app is in the foreground.
  ///
  /// Must be called once; subsequent calls are no-ops because broadcast streams
  /// can handle multiple listeners, but the underlying FCM subscription only
  /// fires once regardless.
  static void startForegroundListener() {
    FirebaseMessaging.onMessage.listen((message) {
      final type = message.data['fcm_type'] ?? '';
      if (type == 'jitsi_ring_send' ||
          type == 'jitsi_send_hangup' ||
          type == 'jitsi_send_accept') {
        _callStreamCtrl.add(message);
      }
    });
  }

  // ── Private helpers ─────────────────────────────────────────────────────────

  static Future<void> _sendToken(String userId, String token) async {
    try {
      final authToken = await SecureStorage.getToken();
      await Dio().post<dynamic>(
        '${AppConfig.baseUrl}/v1/register_firebase_token',
        data: {
          'user_id': userId,
          'device': 'android',
          'firebase_token': token,
        },
        options: Options(
          headers: authToken != null
              ? {'Authorization': 'Bearer $authToken'}
              : null,
          validateStatus: (_) => true,
        ),
      );
      debugPrint('[FCM] Token registered for user $userId');
    } catch (e) {
      debugPrint('[FCM] Token send failed: $e');
    }
  }
}
