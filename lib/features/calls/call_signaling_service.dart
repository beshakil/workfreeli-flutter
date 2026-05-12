import '../../core/network/graphql_client.dart';
import '../../core/storage/secure_storage.dart';

const _kJitsiDomain = 'https://wfvs001.freeli.io';

class CallSignalingService {
  CallSignalingService._();

  static String roomNameFor(String conversationId) =>
      conversationId.replaceAll('-', '');

  static String callLinkFor(String conversationId) =>
      '$_kJitsiDomain/${roomNameFor(conversationId)}';

  // ── Outgoing call ───────────────────────────────────────────────────────────

  /// Ring all participants in [conversationId] and return the Jitsi JWT.
  static Future<String?> startCall({
    required String userId,
    required String conversationId,
    required String convTitle,
    required List<String> participants,
    required String companyId,
    required bool isGroup,
  }) async {
    final token = await SecureStorage.getXmppDeviceToken() ?? '';
    final others = participants.where((p) => p != userId).toList();

    final data = await GraphQLService.call(
      _ringCallingQuery,
      variables: {
        'user_id': userId,
        'conversation_id': conversationId,
        'conversation_type': isGroup ? 'group' : 'personal',
        'arr_participants': others,
        'participants_all': participants,
        'participants_admin': <String>[],
        'convname': convTitle,
        'call_link': callLinkFor(conversationId),
        'call_option': 'ring',
        'company_id': companyId,
        'token': token,
      },
    );

    final result = data['jitsi_ring_calling'] as Map<String, dynamic>?;
    return result?['jwt_token'] as String?;
  }

  // ── Incoming call ───────────────────────────────────────────────────────────

  /// Accept an incoming call. Returns the Jitsi JWT.
  static Future<String?> acceptCall({
    required String userId,
    required String conversationId,
  }) async {
    final token = await SecureStorage.getXmppDeviceToken() ?? '';

    final data = await GraphQLService.call(
      _callAcceptQuery,
      variables: {
        'user_id': userId,
        'conversation_id': conversationId,
        'token': token,
        'type': 'accept',
        'device_type': 'mobile',
      },
    );

    final result = data['jitsi_call_accept'] as Map<String, dynamic>?;
    return result?['jwt_token'] as String?;
  }

  // ── End call ────────────────────────────────────────────────────────────────

  /// Hang up or reject a call. Set [endCall] = false to only reject/leave
  /// without terminating for all participants (group call leave).
  static Future<void> hangupCall({
    required String userId,
    required String userFullName,
    required String conversationId,
    bool endCall = true,
  }) async {
    final token = await SecureStorage.getXmppDeviceToken() ?? '';

    await GraphQLService.call(
      _callHangupQuery,
      variables: {
        'user_id': userId,
        'user_fullname': userFullName,
        'conversation_id': conversationId,
        'token': token,
        'hold_status': false,
        'switch_status': false,
        'end_call': endCall,
      },
    );
  }
}

// ── GraphQL documents ──────────────────────────────────────────────────────────

const _ringCallingQuery = r'''
query JitsiRingCalling(
  $user_id: String!
  $conversation_id: String!
  $conversation_type: String!
  $arr_participants: [String]
  $participants_all: [String]
  $participants_admin: [String]
  $convname: String
  $call_link: String
  $call_option: String
  $company_id: String!
  $token: String!
) {
  jitsi_ring_calling(
    user_id: $user_id
    conversation_id: $conversation_id
    conversation_type: $conversation_type
    arr_participants: $arr_participants
    participants_all: $participants_all
    participants_admin: $participants_admin
    convname: $convname
    call_link: $call_link
    call_option: $call_option
    company_id: $company_id
    token: $token
  ) {
    status
    msg
    jwt_token
  }
}
''';

const _callAcceptQuery = r'''
query JitsiCallAccept(
  $user_id: String!
  $conversation_id: String!
  $token: String!
  $type: String
  $device_type: String
) {
  jitsi_call_accept(
    user_id: $user_id
    conversation_id: $conversation_id
    token: $token
    type: $type
    device_type: $device_type
  ) {
    status
    jwt_token
  }
}
''';

const _callHangupQuery = r'''
query JitsiCallHangup(
  $user_id: String!
  $user_fullname: String
  $conversation_id: String!
  $token: String!
  $hold_status: Boolean
  $switch_status: Boolean
  $end_call: Boolean
) {
  jitsi_call_hangup(
    user_id: $user_id
    user_fullname: $user_fullname
    conversation_id: $conversation_id
    token: $token
    hold_status: $hold_status
    switch_status: $switch_status
    end_call: $end_call
  ) {
    status
  }
}
''';
