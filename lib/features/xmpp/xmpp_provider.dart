import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/secure_storage.dart';
import '../user/user_providers.dart';
import 'xmpp_service.dart';

export 'xmpp_service.dart' show XmppService, XmppState, XmppEvent;

// ── Singleton access ──────────────────────────────────────────────────────────

/// Exposes the [XmppService] singleton as a ChangeNotifier so widgets can
/// watch connection state via `ref.watch(xmppServiceProvider)`.
final xmppServiceProvider = ChangeNotifierProvider<XmppService>((ref) {
  return XmppService.instance;
});

// ── Auto-connect after login ──────────────────────────────────────────────────

/// Watches the current user and auto-connects XMPP when authenticated.
/// Place `ref.watch(xmppAutoConnectProvider)` in the home screen's build
/// method so the connection is established once the user is available.
final xmppAutoConnectProvider = FutureProvider<void>((ref) async {
  final user = await ref.watch(meProvider.future);

  // Retrieve or generate a persistent random device token (NOT the JWT).
  // Mirrors getXmppToken() from the web client (stored in localStorage).
  var deviceToken = await SecureStorage.getXmppDeviceToken();
  if (deviceToken == null || deviceToken.isEmpty) {
    final rng = Random();
    deviceToken =
        '${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}'
        '${rng.nextInt(0x7fffffff).toRadixString(36)}';
    await SecureStorage.saveXmppDeviceToken(deviceToken);
  }

  final deviceId = await SecureStorage.getDeviceId() ?? user.id;

  final svc = XmppService.instance;
  // Register first — response gives us the ejabberd username (xmpp_user).
  await svc.register(userId: user.id, deviceToken: deviceToken);
  // Then open the WebSocket; SASL uses xmpp_user + fixed server password.
  await svc.connect(userId: user.id, deviceId: deviceId);
  debugPrint('[XmppProvider] Auto-connect triggered for ${user.id}');
});

// ── XMPP event stream ─────────────────────────────────────────────────────────

/// Provides the raw XMPP event [Stream] for screens that need it.
/// Does NOT auto-dispose — the stream lives for the entire session.
final xmppEventStreamProvider = StreamProvider<XmppEvent>((ref) {
  return XmppService.instance.events;
});
