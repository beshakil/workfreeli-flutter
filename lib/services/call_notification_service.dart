import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';

// ── Constants ─────────────────────────────────────────────────────────────────

const _kChannelId = 'incoming_calls';
const _kChannelName = 'Incoming Calls';
const _kChannelDesc = 'Full-screen alerts for incoming audio/video calls';
const _kNotifId = 9999;
const _kPendingCallKey = 'pending_call_data';
const _kPendingActionKey = 'pending_call_action';

// ── Background action handler (must be top-level, no class) ──────────────────

/// Fires in a background isolate when the user taps a notification action
/// while the app is NOT in the foreground.
///
/// "Decline" uses `showsUserInterface: false` so the app is never opened.
/// We simply mark the call as declined in SharedPreferences; the backend
/// times the call out after 60 s anyway.
@pragma('vm:entry-point')
void _onBackgroundNotificationAction(NotificationResponse response) async {
  final prefs = await SharedPreferences.getInstance();
  if (response.actionId == 'decline_call') {
    await prefs.remove(_kPendingCallKey);
    await prefs.setString(_kPendingActionKey, 'decline');
  }
  // 'accept_call' has showsUserInterface:true → app resumes →
  // handled in the main isolate via CallNotificationService.responseStream.
}

// ── Service ───────────────────────────────────────────────────────────────────

class CallNotificationService {
  CallNotificationService._();

  static final _plugin = FlutterLocalNotificationsPlugin();

  // Emits notification responses while the app is in the foreground or
  // when it resumes from the background after the user taps an action.
  static final _responseCtrl = StreamController<NotificationResponse>.broadcast();
  static Stream<NotificationResponse> get responseStream => _responseCtrl.stream;

  // Cached response from getNotificationAppLaunchDetails() — set during init()
  // so HomeScreen can read it after providers are ready.
  static NotificationResponse? _launchResponse;
  static NotificationResponse? get launchResponse => _launchResponse;
  static void clearLaunchResponse() => _launchResponse = null;

  // ── Initialisation ──────────────────────────────────────────────────────────

  /// Must be called from main() in the main isolate AND from the Firebase
  /// background handler isolate before showing any notification.
  static Future<void> init() async {
    const initSettings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );

    await _plugin.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (response) {
        _launchResponse ??= response; // capture for terminated-app flow
        _responseCtrl.add(response);
      },
      onDidReceiveBackgroundNotificationResponse: _onBackgroundNotificationAction,
    );

    // Create a max-importance channel so notifications always bypass DND and
    // appear as heads-up (or full-screen on lock screen).
    await _plugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
      const AndroidNotificationChannel(
        _kChannelId,
        _kChannelName,
        description: _kChannelDesc,
        importance: Importance.max,
        playSound: true,
        enableVibration: true,
        enableLights: true,
      ),
    );

    // Detect if the app was cold-started by tapping this plugin's notification
    // (distinct from Firebase's own getInitialMessage).
    final launchDetails = await _plugin.getNotificationAppLaunchDetails();
    if (launchDetails?.didNotificationLaunchApp == true &&
        launchDetails?.notificationResponse != null) {
      _launchResponse = launchDetails!.notificationResponse;
    }
  }

  // ── Show / dismiss ──────────────────────────────────────────────────────────

  /// Shows a full-screen incoming-call notification.
  ///
  /// Safe to call from both the main isolate (foreground FCM) and the
  /// Firebase background-message isolate.
  static Future<void> showIncomingCallNotification(
      Map<String, dynamic> data) async {
    final callerName = data['user_fullname']?.toString() ?? 'Incoming Call';
    final isVideo =
        (data['call_type'] ?? data['set_calltype'] ?? '').toString() == 'video';

    // Persist so HomeScreen can reconstruct the call state after app launch.
    await _savePendingCall(data);

    const details = AndroidNotificationDetails(
      _kChannelId,
      _kChannelName,
      channelDescription: _kChannelDesc,
      importance: Importance.max,
      priority: Priority.max,
      // fullScreenIntent fires the IncomingCallScreen even on lock screen.
      fullScreenIntent: true,
      category: AndroidNotificationCategory.call,
      // ongoing + autoCancel:false keeps the notification visible until
      // the call is accepted, declined, or timed out.
      ongoing: true,
      autoCancel: false,
      playSound: true,
      enableVibration: true,
      actions: [
        AndroidNotificationAction(
          'decline_call',
          'Decline',
          cancelNotification: true,
          // Don't open the app for Decline; handled in background isolate.
          showsUserInterface: false,
        ),
        AndroidNotificationAction(
          'accept_call',
          'Accept',
          cancelNotification: true,
          // Bring the app to foreground so we can run acceptCall().
          showsUserInterface: true,
        ),
      ],
    );

    await _plugin.show(
      _kNotifId,
      'Incoming ${isVideo ? 'Video' : 'Audio'} Call',
      callerName,
      const NotificationDetails(android: details),
      payload: jsonEncode(data),
    );
  }

  /// Cancel the ongoing call notification (call was answered/hung-up/timed out).
  static Future<void> dismissCallNotification() async {
    await _plugin.cancel(_kNotifId);
    await _clearPendingCall();
  }

  // ── Background FCM handler entry point ─────────────────────────────────────

  /// Called by the Firebase background-message handler in main.dart.
  static Future<void> handleBackgroundFcmMessage(RemoteMessage message) async {
    final fcmType = message.data['fcm_type'] ?? '';
    switch (fcmType) {
      case 'jitsi_ring_send':
        await showIncomingCallNotification(message.data);
      case 'jitsi_send_hangup':
      case 'jitsi_send_accept':
        // Caller cancelled or someone else accepted — dismiss.
        await dismissCallNotification();
    }
  }

  // ── Pending call persistence ────────────────────────────────────────────────

  static Future<void> _savePendingCall(Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kPendingCallKey, jsonEncode(data));
  }

  static Future<void> _clearPendingCall() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kPendingCallKey);
    await prefs.remove(_kPendingActionKey);
  }

  /// Read and atomically clear any pending call + action stored while the app
  /// was in the background or terminated.
  ///
  /// Returns `(data: null, action: 'none')` when there is nothing pending.
  static Future<({Map<String, dynamic>? data, String action})>
      consumePendingCall() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kPendingCallKey);
    final action = prefs.getString(_kPendingActionKey) ?? 'none';
    await prefs.remove(_kPendingCallKey);
    await prefs.remove(_kPendingActionKey);
    if (raw == null) return (data: null, action: action);
    try {
      return (
        data: jsonDecode(raw) as Map<String, dynamic>,
        action: action,
      );
    } catch (e) {
      debugPrint('[CallNotif] Failed to decode pending call: $e');
      return (data: null, action: 'none');
    }
  }
}
