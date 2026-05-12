import 'package:flutter/foundation.dart';
import 'package:jitsi_meet_flutter_sdk/jitsi_meet_flutter_sdk.dart';
import 'package:permission_handler/permission_handler.dart';

import 'call_signaling_service.dart';

class JitsiService {
  JitsiService._();

  static final _jitsiMeet = JitsiMeet();

  /// Request camera and microphone permissions.
  /// Returns true only when both are granted.
  static Future<bool> requestCallPermissions() async {
    final statuses = await [
      Permission.camera,
      Permission.microphone,
    ].request();
    return statuses.values.every((s) => s.isGranted);
  }

  /// Open a Jitsi call.
  ///
  /// [conversationId] is the UUID conversation ID — room name is derived by
  /// stripping hyphens, matching the web client and server behaviour.
  ///
  /// [onReadyToClose] fires when the user hangs up inside Jitsi so the caller
  /// can post the hangup signal and refresh call history.
  static Future<void> join({
    required String conversationId,
    required String jwtToken,
    required bool isVideo,
    required String userName,
    required String userEmail,
    String? userAvatar,
    Future<void> Function()? onReadyToClose,
  }) async {
    final roomName = CallSignalingService.roomNameFor(conversationId);

    final options = JitsiMeetConferenceOptions(
      serverURL: 'https://wfvs001.freeli.io',
      room: roomName,
      token: jwtToken,
      configOverrides: {
        'startWithVideoMuted': !isVideo,
        'startWithAudioMuted': false,
        'p2p': {'enabled': false},
        'useTurnUdp': true,
        'useTurnTcp': true,
        'prejoinPageEnabled': false,
        'disableDeepLinking': true,
        'disableThirdPartyRequests': true,
      },
      featureFlags: {
        'welcomepage.enabled': false,
        'resolution': 360,
        'add-people.enabled': false,
      },
      userInfo: JitsiMeetUserInfo(
        displayName: userName,
        email: userEmail,
        avatar: userAvatar ?? '',
      ),
    );

    await _jitsiMeet.join(
      options,
      JitsiMeetEventListener(
        conferenceJoined: (url) =>
            debugPrint('[Jitsi] Conference joined: $url'),
        conferenceTerminated: (url, error) {
          if (error != null) debugPrint('[Jitsi] Terminated with error: $error');
        },
        readyToClose: () {
          debugPrint('[Jitsi] Ready to close');
          onReadyToClose?.call();
        },
      ),
    );
  }
}
