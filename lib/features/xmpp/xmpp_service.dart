import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../../core/config/app_config.dart';

// ── Event ─────────────────────────────────────────────────────────────────────

class XmppEvent {
  final String type;
  final Map<String, dynamic> data;
  const XmppEvent({required this.type, required this.data});
}

// ── State ─────────────────────────────────────────────────────────────────────

enum XmppState { disconnected, connecting, authenticating, connected, error }

// ── Service ───────────────────────────────────────────────────────────────────

class XmppService extends ChangeNotifier {
  XmppService._();
  static final XmppService instance = XmppService._();

  // ── Internal state ──────────────────────────────────────────────────────────

  WebSocket? _ws;
  XmppState _state = XmppState.disconnected;
  XmppState get state => _state;

  String _userId = '';
  String _xmppUser = '';
  String _xmppDomain = AppConfig.xmppDomain;
  String _resource = '';

  static const _xmppPassword = 'a123456';

  String get userId => _userId;

  XmppEvent? _lastEvent;
  XmppEvent? get lastEvent => _lastEvent;

  final _eventController = StreamController<XmppEvent>.broadcast();
  Stream<XmppEvent> get events => _eventController.stream;

  // Stream-negotiation flags (reset on each connect attempt).
  bool _saslDone = false;
  bool _streamReopened = false;
  bool _bindDone = false;

  // SCRAM state.
  bool _useScram = false;
  String _scramVariant = 'SHA-1';
  String _scramClientNonce = '';
  String _scramClientFirstMsgBare = '';

  Timer? _pingTimer;
  Timer? _reconnectTimer;
  int _reconnectAttempt = 0;
  bool _intentionalDisconnect = false;

  // ── Public API ──────────────────────────────────────────────────────────────

  Future<void> register({
    required String userId,
    required String deviceToken,
    String? authToken,
  }) async {
    if (_state == XmppState.connected || _state == XmppState.connecting) {
      debugPrint('[XMPP] Already connected — skipping re-registration');
      return;
    }
    try {
      final headers = <String, dynamic>{'Content-Type': 'application/json'};
      if (authToken != null && authToken.isNotEmpty) {
        headers['Authorization'] = 'Bearer $authToken';
      }

      final resp = await Dio().post<dynamic>(
        AppConfig.xmppRegisterUrl,
        data: {'user_id': userId, 'token': deviceToken},
        options: Options(headers: headers, validateStatus: (_) => true),
      );

      final body = resp.data;
      String? xmppUser;
      if (body is Map) {
        xmppUser = body['xmpp_user'] as String?;
        xmppUser ??= (body['data'] as Map?)?['xmpp_user'] as String?;
        // Use the server-returned xmpp_domain if provided so the XMPP domain
        // in the open stanza matches what the backend uses for XMPP delivery.
        final serverDomain = body['xmpp_domain'] as String?;
        if (serverDomain != null && serverDomain.isNotEmpty) {
          _xmppDomain = serverDomain;
        }
        debugPrint('[XMPP] Registration: status=${body['status']} xmpp_user=$xmppUser domain=$_xmppDomain');
      }

      _xmppUser = (xmppUser != null && xmppUser.isNotEmpty) ? xmppUser : userId;
      debugPrint('[XMPP] Using xmpp_user=$_xmppUser domain=$_xmppDomain');
    } catch (e) {
      debugPrint('[XMPP] Registration error: $e');
      _xmppUser = userId;
    }
  }

  Future<void> connect({
    required String userId,
    required String deviceId,
  }) async {
    _userId = userId;
    if (_xmppUser.isEmpty) _xmppUser = userId;
    _resource =
        'mobile${deviceId.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '').substring(0, min(8, deviceId.length))}';
    _intentionalDisconnect = false;
    _reconnectAttempt = 0;
    await _connect();
  }

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

      _ws = await WebSocket.connect(wsUrl, protocols: ['xmpp'])
          .timeout(const Duration(seconds: 15));

      _ws!.listen(
        _onData,
        onError: _onSocketError,
        onDone: _onSocketDone,
        cancelOnError: false,
      );

      _sendRaw('<open xmlns="urn:ietf:params:xml:ns:xmpp-framing" '
          'to="$_xmppDomain" version="1.0"/>');

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
    _useScram = false;
    _scramVariant = 'SHA-1';
    _scramClientNonce = '';
    _scramClientFirstMsgBare = '';
    _xmppDomain = AppConfig.xmppDomain;
  }

  // ── Stanza state machine ────────────────────────────────────────────────────

  void _onData(dynamic raw) {
    final data = raw.toString();
    if (data.trim().isEmpty) return;
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

  // Phase 1: pick best SCRAM variant from server's mechanisms list.
  // Robust: triggers on <mechanisms>, SCRAM/PLAIN keywords, or <stream:features>.
  void _handlePreAuth(String data) {
    if (data.contains('<challenge')) {
      if (_useScram) _handleScramChallenge(data);
      return;
    }

    if (data.contains('<success')) {
      debugPrint('[XMPP] SASL success');
      _saslDone = true;
      _setState(XmppState.authenticating);
      _sendRaw('<open xmlns="urn:ietf:params:xml:ns:xmpp-framing" '
          'to="$_xmppDomain" version="1.0"/>');
      return;
    }

    if (data.contains('<failure') || data.contains('not-authorized')) {
      debugPrint('[XMPP] SASL failure: $data');
      _setState(XmppState.error);
      _scheduleReconnect();
      return;
    }

    // Trigger on any stanza that lists auth mechanisms.
    // Broad match handles servers that format features differently.
    final hasMechanisms = data.contains('<mechanisms') ||
        data.contains('<stream:features') ||
        data.contains('SCRAM') ||
        data.contains('PLAIN');

    if (!hasMechanisms || _useScram) return;

    if (data.contains('SCRAM-SHA-256')) {
      debugPrint('[XMPP] Server offers SCRAM-SHA-256 — using it');
      _sendScramFirstMessage(variant: 'SHA-256');
    } else if (data.contains('SCRAM-SHA-1')) {
      debugPrint('[XMPP] Server offers SCRAM-SHA-1 — using it');
      _sendScramFirstMessage(variant: 'SHA-1');
    } else if (data.contains('PLAIN')) {
      debugPrint('[XMPP] Falling back to SASL PLAIN');
      _sendSaslPlain();
    }
  }

  // Phase 2: after SASL — send resource bind on second stream:features.
  void _handlePostSasl(String data) {
    if (data.contains('<open') ||
        data.contains('stream:features') ||
        data.contains('<bind')) {
      if (!_streamReopened) {
        _streamReopened = true;
        _sendRaw('<iq type="set" id="bind_1">'
            '<bind xmlns="urn:ietf:params:xml:ns:xmpp-bind">'
            '<resource>$_resource</resource>'
            '</bind></iq>');
      }
    }
  }

  // Phase 3: bind result.
  void _handleBinding(String data) {
    if (data.contains('bind') &&
        (data.contains('result') || data.contains('<jid>'))) {
      _bindDone = true;
      _reconnectAttempt = 0;
      _setState(XmppState.connected);
      debugPrint(
          '[XMPP] Bound — fully connected as $_xmppUser@$_xmppDomain/$_resource');
      _sendRaw('<presence/>');
      _dispatch(XmppEvent(type: 'xmpp_connected', data: {}));
    } else if (data.contains('error')) {
      debugPrint('[XMPP] Bind error (continuing without resource): $data');
      _bindDone = true;
      _setState(XmppState.connected);
      _dispatch(XmppEvent(type: 'xmpp_connected', data: {}));
    }
  }

  // Phase 4: normal operation.
  void _handleStanza(String data) {
    if (data.contains('<message')) _parseMessageStanza(data);
    if (data.contains('<presence')) _parsePresenceStanza(data);
  }

  // ── Stanza parsers ──────────────────────────────────────────────────────────

  // XML text content arrives with predefined entities escaped by ejabberd.
  // JSON uses double-quotes extensively, so &quot; is the common culprit.
  static String _unescapeXml(String s) => s
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&'); // amp last — avoids double-unescaping

  void _parseMessageStanza(String xml) {
    final bodyMatch =
        RegExp(r'<body[^>]*>([\s\S]*?)</body>').firstMatch(xml);
    if (bodyMatch == null) return;

    final rawBody = _unescapeXml(bodyMatch.group(1) ?? '');
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
    final type =
        RegExp(r'type="([^"]*)"').firstMatch(xml)?.group(1) ?? 'available';
    if (from.isNotEmpty) {
      _dispatch(
          XmppEvent(type: 'presence', data: {'from': from, 'type': type}));
    }
  }

  // ── SCRAM-SHA-1 / SHA-256 (RFC 5802) ───────────────────────────────────────

  void _sendScramFirstMessage({String variant = 'SHA-1'}) {
    _useScram = true;
    _scramVariant = variant;

    final nonceBytes =
        List<int>.generate(18, (_) => Random.secure().nextInt(256));
    _scramClientNonce = base64.encode(nonceBytes);
    _scramClientFirstMsgBare = 'n=$_xmppUser,r=$_scramClientNonce';

    final firstMsg = 'n,,$_scramClientFirstMsgBare';
    final encoded = base64.encode(utf8.encode(firstMsg));
    _sendRaw('<auth xmlns="urn:ietf:params:xml:ns:xmpp-sasl" '
        'mechanism="SCRAM-$_scramVariant">$encoded</auth>');
    debugPrint('[XMPP] SCRAM-$_scramVariant step 1 sent for $_xmppUser');
  }

  void _handleScramChallenge(String xmlData) {
    final match =
        RegExp(r'<challenge[^>]*>([\s\S]*?)</challenge>').firstMatch(xmlData);
    if (match == null) {
      debugPrint('[XMPP] SCRAM: no challenge element');
      return;
    }

    final serverFirstMsg =
        utf8.decode(base64.decode(match.group(1)!.trim()));
    debugPrint('[XMPP] SCRAM challenge: $serverFirstMsg');

    String? combinedNonce, saltB64;
    int iterations = 4096;
    for (final part in serverFirstMsg.split(',')) {
      if (part.startsWith('r=')) combinedNonce = part.substring(2);
      if (part.startsWith('s=')) saltB64 = part.substring(2);
      if (part.startsWith('i=')) iterations = int.tryParse(part.substring(2)) ?? 4096;
    }

    if (combinedNonce == null || saltB64 == null) {
      debugPrint('[XMPP] SCRAM: malformed challenge');
      return;
    }
    if (!combinedNonce.startsWith(_scramClientNonce)) {
      debugPrint('[XMPP] SCRAM: server nonce mismatch — aborting');
      return;
    }

    final salt = base64.decode(saltB64);
    final passwordBytes = utf8.encode(_xmppPassword);
    final useSha256 = _scramVariant == 'SHA-256';

    final saltedPassword = useSha256
        ? _pbkdf2(sha256, passwordBytes, salt, iterations, 32)
        : _pbkdf2(sha1, passwordBytes, salt, iterations, 20);

    final clientKey = useSha256
        ? Hmac(sha256, saltedPassword).convert(utf8.encode('Client Key')).bytes
        : Hmac(sha1, saltedPassword).convert(utf8.encode('Client Key')).bytes;

    final storedKey = useSha256
        ? sha256.convert(clientKey).bytes
        : sha1.convert(clientKey).bytes;

    final channelBinding = base64.encode(utf8.encode('n,,'));
    final clientFinalWithoutProof = 'c=$channelBinding,r=$combinedNonce';
    final authMessage =
        '$_scramClientFirstMsgBare,$serverFirstMsg,$clientFinalWithoutProof';

    final clientSignature = useSha256
        ? Hmac(sha256, storedKey).convert(utf8.encode(authMessage)).bytes
        : Hmac(sha1, storedKey).convert(utf8.encode(authMessage)).bytes;

    final clientProof = List<int>.generate(
      clientKey.length,
      (i) => clientKey[i] ^ clientSignature[i],
    );

    final clientFinalMsg =
        '$clientFinalWithoutProof,p=${base64.encode(clientProof)}';
    _sendRaw('<response xmlns="urn:ietf:params:xml:ns:xmpp-sasl">'
        '${base64.encode(utf8.encode(clientFinalMsg))}</response>');
    debugPrint('[XMPP] SCRAM-$_scramVariant step 2 sent (iterations=$iterations)');
  }

  // PBKDF2-HMAC (RFC 2898 §5.2), one output block.
  static Uint8List _pbkdf2(
    Hash hash,
    List<int> password,
    List<int> salt,
    int iterations,
    int keyLength,
  ) {
    final hmac = Hmac(hash, password);
    final saltWithBlock = Uint8List(salt.length + 4);
    saltWithBlock.setAll(0, salt);
    saltWithBlock[salt.length + 3] = 1;
    List<int> u = hmac.convert(saltWithBlock).bytes;
    final result = List<int>.from(u);
    for (int i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (int j = 0; j < result.length; j++) {
        result[j] ^= u[j];
      }
    }
    return Uint8List.fromList(result.sublist(0, keyLength));
  }

  // ── SASL PLAIN (fallback) ───────────────────────────────────────────────────

  void _sendSaslPlain() {
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
      if (_state == XmppState.connected) _sendRaw(' ');
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

  // ── Dispatch ────────────────────────────────────────────────────────────────

  void _dispatch(XmppEvent event) {
    _lastEvent = event;
    if (!_eventController.isClosed) _eventController.add(event);
    notifyListeners();
  }

  // ── Socket callbacks ────────────────────────────────────────────────────────

  void _onSocketError(Object error) {
    debugPrint('[XMPP] Socket error: $error');
    _setState(XmppState.error);
    if (!_intentionalDisconnect) _scheduleReconnect();
  }

  void _onSocketDone() {
    debugPrint('[XMPP] Socket closed');
    if (_state != XmppState.disconnected) _setState(XmppState.disconnected);
    if (!_intentionalDisconnect) _scheduleReconnect();
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
