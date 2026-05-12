import '../../core/network/graphql_client.dart';
import 'call_models.dart';

// Requests only the fields needed for call history rendering.
// conv_title and conv_img are populated server-side by the resolver
// (friend name/avatar for DMs, room title/image for group calls).
const _callHistoryQuery = '''
query CallHistoryGroup {
  call_history_group {
    status
    history_group {
      conversation_id
      msg_id
      sender
      sendername
      fnln
      senderimg
      conv_title
      conv_img
      created_at
      call_duration
      call_type
      call_status
      participants
    }
  }
}
''';

class CallsService {
  CallsService._();

  static Future<List<CallHistoryEntry>> getCallHistory() async {
    final data = await GraphQLService.call(_callHistoryQuery);

    final outer =
        data['call_history_group'] as Map<String, dynamic>? ?? {};
    final list = outer['history_group'] as List<dynamic>? ?? [];

    return list
        .map((e) => CallHistoryEntry.fromJson(e as Map<String, dynamic>))
        .where((e) => e.conversationId.isNotEmpty)
        .toList();
  }
}
