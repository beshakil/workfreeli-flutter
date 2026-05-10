import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/app_config.dart';

// ── Event ─────────────────────────────────────────────────────────────────────

/// A decoded XMPP push event (e.g. new_message, read_status_msg).
class XmppEvent {
  final String type;
  final Map<String, dynamic> data;
  const XmppEvent({required this.type, required this.data});
}

// ── State ─────────────────────────────────────────────────────────────────────

enum XmppState { disconnected, connecting, authenticating, connected, error }

// ── Service ───────────────────────────────────────────────────────────────────

/// Lightweight XMPP-over-WebSocket client (RFC 7395).
///
/// Lifecycle:
///   1. Call [register] once after login to create the ejabberd account.
///   2. Call [connect] to open the WebSocket and authenticate via SASL PLAIN.
///   3. Subscribe to [events] for real-time pushes (new_message, etc.).
///   4. Call [disconnect] on logout.
///
/// Auto-reconnects on unexpected disconnect with exponential back-off
/// (2 s → 4 s → 8 s … capped at 60 s).
class XmppService extends ChangeNotifier {
  XmppService._();
  static final XmppService instance = XmppService._();

  // ── Internal state ──────────────────────────────────────────────────────────

  WebSocket? _ws;
  XmppState _state = XmppState.disconnected;
  XmppState get state => _state;

  // Credentials saved on connect/register so reconnect can replay them.
  String _userId = '';
  String _xmppUser = '';      // username returned by registration API
  String _deviceToken = '';   // persistent random device ID sent to registration
  String _resource = '';

  // The ejabberd password is a fixed server-side value — NOT the JWT.
  static const _xmppPassword = 'a123456';

  /// Exposed so the auth layer can check whether XMPP is initialised.
  String get userId => _userId;

  // Last dispatched event — lets ChangeNotifier consumers read it.
  XmppEvent? _lastEvent;
  XmppEvent? get lastEvent => _lastEvent;

  // Broadcast stream for screens that subscribe directly.
  final _eventController = StreamController<XmppEvent>.broadcast();
  Stream<XmppEvent> get events => _eventController.stream;

  // XMPP stream-negotiation flags (reset on each connect attempt).
  bool _saslDone = false;
  bool _streamReopened = false;
  bool _bindDone = false;

  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _intentionalDisconnect = false;

  // ── Public API ──────────────────────────────────────────────────────────────

  /// Register this user on the ejabberd XMPP server and store the returned
  /// [xmpp_user] so [_sendSaslPlain] can use the correct JID local-part.
  ///
  /// [deviceToken] is a persistent random device identifier (NOT the JWT).
  Future<void> register({
    required String userId,
    required String deviceToken,
  }) async {
    _deviceToken = deviceToken;
    try {
      final resp = await Dio().post<dynamic>(
        AppConfig.xmppRegisterUrl,
        data: {'user_id': userId, 'token': deviceToken},
        options: Options(
          contentType: 'application/json',
          validateStatus: (_) => true,
        ),
      );
      // Extract xmpp_user from response (may be nested under 'data').
      final body = resp.data;
      String? xmppUser;
      if (body is Map) {
        xmppUser = body['xmpp_user'] as String?;
        xmppUser ??= (body['data'] as Map?)?['xmpp_user'] as String?;
      }
      _xmppUser = (xmppUser != null && xmppUser.isNotEmpty) ? xmppUser : userId;
      debugPrint('[XMPP] Registered: xmpp_user=$_xmppUser');
    } catch (e) {
      debugPrint('[XMPP] Registration error: $e');
      _xmppUser = userId; // fallback — will retry on SASL failure
    }
  }

  /// Open WebSocket connection and authenticate via SASL PLAIN.
  /// Must be called after [register] so [_xmppUser] is populated.
  Future<void> connect({
    required String userId,
    required String deviceId,
  }) async {
    _userId = userId;
    if (_xmppUser.isEmpty) _xmppUser = userId; // guard
    _resource = 'mobile${deviceId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').substring(0, min(8, deviceId.length))}';
    _intentionalDisconnect = false;
    _reconnectAttempt = 0;
    await _connect();
  }

  /// Clean disconnect — called on logout.
  void disconnect() {
    debugPrint('[XMPP] Intentional disconnect');
    _intentionalDisconnect = true;
    _cleanup();
  }

  // ── Connection lifecycle ────────────────────────────────────────────────────

  Future<void> _connect() async {
    if (_state == XmppState.connecting || _state == XmppState.connected) return;
    _setState(XmppState.connecting);
    _resetFlags();

    try {
      final wsUrl = AppConfig.xmppWsUrl;
      debugPrint('[XMPP] Connecting → $wsUrl');

      _ws = await WebSocket.connect(
        wsUrl,
        protocols: ['xmpp'],
      ).timeout(const Duration(seconds: 15));

      _ws!.listen(
        _onData,
        onError: _onSocketError,
        onDone: _onSocketDone,
        cancelOnError: false,
      );

      // Open XMPP framing stream (RFC 7395).
      _sendRaw('<open xmlns="urn:ietf:params:xml:ns:xmpp-framing" '
          'to="${AppConfig.xmppDomain}" version="1.0"/>');

      _startPing();
      debugPrint('[XMPP] WebSocket open, waiting for server features');
    } catch (e) {
      debugPrint('[XMPP] Connect failed: $e');
      _setState(XmppState.error);
      _scheduleReconnect();
    }
  }

  void _resetFlags() {
    _saslDone = false;
    _streamReopened = false;
    _bindDone = false;
  }

  // ── Stanza dispatch (state machine) ────────────────────────────────────────

  void _onData(dynamic raw) {
    final data = raw.toString();
    if (data.trim().isEmpty) return; // whitespace keepalive echo
    debugPrint('[XMPP] ← ${data.length > 300 ? '${data.substring(0, 300)}…' : data}');

    if (!_saslDone) {
      _handlePreAuth(data);
    } else if (!_streamReopened) {
      _handlePostSasl(data);
    } else if (!_bindDone) {
      _handleBinding(data);
    } else {
      _handleStanza(data);
    }
  }

  // Phase 1: before SASL success
  void _handlePreAuth(String data) {
    if (data.contains('PLAIN') || data.contains('<mechanisms')) {
      _sendSaslPlain();
    } else if (data.contains('<success')) {
      debugPrint('[XMPP] SASL success');
      _saslDone = true;
      _setState(XmppState.authenticating);
      // Re-open stream after SASL (RFC 6120 §6.4.6).
      _sendRaw('<open xmlns="urn:ietf:params:xml:ns:xmpp-framing" '
          'to="${AppConfig.xmppDomain}" version="1.0"/>');
    } else if (data.contains('<failure') || data.contains('not-authorized')) {
      debugPrint('[XMPP] SASL failure: $data');
      _setState(XmppState.error);
      // Re-register with the current token (may have been refreshed since last
      // attempt) so ejabberd's password is updated before we retry.
      _registerAndReconnect();
    }
  }

  // Phase 2: after SASL — bind resource
  void _handlePostSasl(String data) {
    if (data.contains('<open') || data.contains('stream:features') || data.contains('<bind')) {
      if (!_streamReopened) {
        _streamReopened = true;
        _sendRaw('<iq type="set" id="bind_1">'
            '<bind xmlns="urn:ietf:params:xml:ns:xmpp-bind">'
            '<resource>$_resource</resource>'
            '</bind></iq>');
      }
    }
  }

  // Phase 3: binding result
  void _handleBinding(String data) {
    if (data.contains('bind') &&
        (data.contains('result') || data.contains('<jid>'))) {
      _bindDone = true;
      _reconnectAttempt = 0;
      _setState(XmppState.connected);
      debugPrint('[XMPP] Bound — fully connected as $_userId@${AppConfig.xmppDomain}/$_resource');
      // Send initial presence so other clients know we're online.
      _sendRaw('<presence/>');
      _dispatch(XmppEvent(type: 'xmpp_connected', data: {}));
    } else if (data.contains('error')) {
      // Bind failed — proceed anyway without a resource.
      debugPrint('[XMPP] Bind error (continuing without resource): $data');
      _bindDone = true;
      _setState(XmppState.connected);
      _dispatch(XmppEvent(type: 'xmpp_connected', data: {}));
    }
  }

  // Phase 4: normal operation — parse stanzas
  void _handleStanza(String data) {
    if (data.contains('<message')) _parseMessageStanza(data);
    if (data.contains('<presence')) _parsePresenceStanza(data);
    // IQ responses (pings etc.) are silently ignored.
  }

  // ── Stanza parsers ──────────────────────────────────────────────────────────

  void _parseMessageStanza(String xml) {
    final bodyMatch =
        RegExp(r'<body[^>]*>([\s\S]*?)</body>').firstMatch(xml);
    if (bodyMatch == null) return;

    final rawBody = bodyMatch.group(1) ?? '';
    if (rawBody.trim().isEmpty) return;

    try {
      final json = jsonDecode(rawBody) as Map<String, dynamic>;
      final type = (json['xmpp_type'] as String? ?? '').trim();
      if (type.isEmpty) return;
      debugPrint('[XMPP] Event → $type');
      _dispatch(XmppEvent(type: type, data: json));
    } catch (e) {
      debugPrint('[XMPP] JSON parse error in body: $e');
    }
  }

  void _parsePresenceStanza(String xml) {
    final from = RegExp(r'from="([^"]*)"').firstMatch(xml)?.group(1) ?? '';
    final type = RegExp(r'type="([^"]*)"').firstMatch(xml)?.group(1) ?? 'available';
    if (from.isNotEmpty) {
      _dispatch(XmppEvent(type: 'presence', data: {'from': from, 'type': type}));
    }
  }

  // ── SASL PLAIN ──────────────────────────────────────────────────────────────

  void _sendSaslPlain() {
    // RFC 4616: \0authcid\0password  (authzid omitted → empty)
    // xmpp_user comes from the registration API response.
    // Password is the fixed server-side value, NOT the JWT.
    final credentials =
        base64Encode(utf8.encode('\x00$_xmppUser\x00$_xmppPassword'));
    _sendRaw('<auth xmlns="urn:ietf:params:xml:ns:xmpp-sasl" '
        'mechanism="PLAIN">$credentials</auth>');
    debugPrint('[XMPP] SASL PLAIN sent for $_xmppUser');
  }

  // ── Keep-alive ping ─────────────────────────────────────────────────────────

  void _startPing() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_state == XmppState.connected) {
        _sendRaw(' '); // whitespace keepalive (RFC 6120 §4.6.1)
      }
    });
  }

  // ── Low-level send ──────────────────────────────────────────────────────────

  void _sendRaw(String xml) {
    try {
      if (_ws != null && _ws!.readyState == WebSocket.open) {
        _ws!.add(xml);
      }
    } catch (e) {
      debugPrint('[XMPP] Send error: $e');
    }
  }

  // ── Dispatch helper ─────────────────────────────────────────────────────────

  void _dispatch(XmppEvent event) {
    _lastEvent = event;
    if (!_eventController.isClosed) {
      _eventController.add(event);
    }
    notifyListeners();
  }

  // ── Error / disconnect handling ─────────────────────────────────────────────

  void _onSocketError(Object error) {
    debugPrint('[XMPP] Socket error: $error');
    _setState(XmppState.error);
    if (!_intentionalDisconnect) _scheduleReconnect();
  }

  void _onSocketDone() {
    debugPrint('[XMPP] Socket closed');
    if (_state != XmppState.disconnected) {
      _setState(XmppState.disconnected);
    }
    if (!_intentionalDisconnect) _scheduleReconnect();
  }

  Future<void> _registerAndReconnect() async {
    if (_userId.isNotEmpty && _deviceToken.isNotEmpty) {
      await register(userId: _userId, deviceToken: _deviceToken);
    }
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    if (_intentionalDisconnect) return;
    _reconnectTimer?.cancel();
    final seconds = min(60, pow(2, _reconnectAttempt).toInt() * 2);
    _reconnectAttempt++;
    debugPrint('[XMPP] Reconnect in ${seconds}s (attempt $_reconnectAttempt)');
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      if (!_intentionalDisconnect) _connect();
    });
  }

  void _cleanup() {
    _pingTimer?.cancel();
    _pingTimer = null;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    try {
      _ws?.close();
    } catch (_) {}
    _ws = null;
    _setState(XmppState.disconnected);
  }

  void _setState(XmppState s) {
    if (_state == s) return;
    _state = s;
    notifyListeners();
  }

  @override
  void dispose() {
    _cleanup();
    _eventController.close();
    super.dispose();
  }
}
