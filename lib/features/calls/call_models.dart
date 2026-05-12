import '../../core/models/conversation_models.dart';

enum CallDirection { incoming, outgoing, missed }

class CallHistoryEntry {
  final String conversationId;
  final String msgId;
  final String sender;
  final String convTitle;
  final String? convImg;
  final DateTime createdAt;
  final String callDuration;
  final String callType;
  final String callStatus;
  final List<String> participants;

  const CallHistoryEntry({
    required this.conversationId,
    required this.msgId,
    required this.sender,
    required this.convTitle,
    this.convImg,
    required this.createdAt,
    required this.callDuration,
    required this.callType,
    required this.callStatus,
    required this.participants,
  });

  factory CallHistoryEntry.fromJson(Map<String, dynamic> json) =>
      CallHistoryEntry(
        conversationId: json['conversation_id']?.toString() ?? '',
        msgId: json['msg_id']?.toString() ?? '',
        sender: json['sender']?.toString() ?? '',
        convTitle: (json['conv_title']?.toString() ??
                    json['sendername']?.toString() ??
                    json['fnln']?.toString() ??
                    '')
                .trim()
                .isNotEmpty
            ? (json['conv_title']?.toString() ??
                    json['sendername']?.toString() ??
                    json['fnln']?.toString() ??
                    '')
                .trim()
            : 'Unknown',
        convImg: json['conv_img']?.toString(),
        createdAt: _parseDate(json['created_at']),
        callDuration: json['call_duration']?.toString() ?? '',
        callType: json['call_type']?.toString() ?? 'audio',
        callStatus: json['call_status']?.toString() ?? 'Missed',
        participants: (json['participants'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );

  static DateTime _parseDate(dynamic value) {
    if (value == null) return DateTime.now();
    final s = value.toString();
    return DateTime.tryParse(s) ??
        DateTime.fromMillisecondsSinceEpoch(int.tryParse(s) ?? 0);
  }

  bool get isMissed => callStatus == 'Missed' || callDuration.isEmpty;
  bool get isVideo => callType.toLowerCase() == 'video';
  bool get isGroup => participants.length > 2;

  CallDirection direction(String selfId) {
    if (sender == selfId) return CallDirection.outgoing;
    if (isMissed) return CallDirection.missed;
    return CallDirection.incoming;
  }

  String get initials {
    final words = convTitle.trim().split(RegExp(r'\s+'));
    if (words.length >= 2 && words[0].isNotEmpty && words[1].isNotEmpty) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return convTitle.isNotEmpty ? convTitle[0].toUpperCase() : '?';
  }

  /// Builds a minimal Room for navigation to MessageScreen.
  Room toRoom() => Room(
        id: conversationId,
        title: convTitle,
        isGroup: isGroup,
        participants: participants,
        convImg: convImg,
      );
}
