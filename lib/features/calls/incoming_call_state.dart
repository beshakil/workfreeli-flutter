import 'package:flutter_riverpod/flutter_riverpod.dart';

class IncomingCallState {
  final String? conversationId;
  final String? callerId;
  final String? callerName;
  final String? callerImg;
  final String? convTitle;
  final bool isVideo;

  const IncomingCallState({
    this.conversationId,
    this.callerId,
    this.callerName,
    this.callerImg,
    this.convTitle,
    this.isVideo = false,
  });

  bool get hasActiveCall => conversationId != null;

  /// Build from a raw XMPP `jitsi_busy_status` or FCM `jitsi_ring_send` payload.
  /// Handles both XMPP keys (caller_fullname, caller_img) and FCM keys
  /// (user_fullname, user_img) so either source works correctly.
  factory IncomingCallState.fromXmppData(Map<String, dynamic> data) {
    return IncomingCallState(
      conversationId: data['conversation_id']?.toString(),
      callerId: (data['caller_id'] ?? data['user_id'])?.toString(),
      callerName: (data['caller_fullname'] ??
              data['user_fullname'] ??
              data['sendername'] ??
              data['fnln'] ??
              'Unknown')
          .toString()
          .trim(),
      callerImg: (data['caller_img'] ?? data['user_img'])?.toString(),
      convTitle: (data['convname'] ?? data['conv_title'])?.toString(),
      isVideo: (data['set_calltype'] ?? data['call_type'] ?? 'audio')
              .toString()
              .toLowerCase() ==
          'video',
    );
  }
}

class IncomingCallNotifier extends StateNotifier<IncomingCallState> {
  IncomingCallNotifier() : super(const IncomingCallState());

  void show(IncomingCallState incoming) => state = incoming;

  void dismiss() => state = const IncomingCallState();
}

final incomingCallProvider =
    StateNotifierProvider<IncomingCallNotifier, IncomingCallState>(
  (_) => IncomingCallNotifier(),
);
