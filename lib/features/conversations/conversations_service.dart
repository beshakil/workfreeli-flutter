import '../../core/encryption/encryption_service.dart';
import '../../core/models/conversation_models.dart';
import '../../core/network/graphql_client.dart';

const _getRoomsQuery = '''
query Rooms(\$userId: String!) {
  rooms(user_id: \$userId) {
    conversation_id
    title
    group
    archive
    close_for
    pin
    has_mute
    friend_id
    conv_img
    last_msg_time
    system_conversation
    participants
    company_id
  }
}
''';

const _getMessagesQuery = '''
query Messages(\$conversation_id: String!, \$page: Int!) {
  messages(conversation_id: \$conversation_id, page: \$page) {
    msgs {
      msg_id
      msg_body
      msg_type
      sender
      sendername
      senderimg
      created_at
      all_attachment {
        id
        originalname
        file_type
        file_size
        key
        location
      }
    }
    pagination {
      page
      totalPages
      total
    }
  }
}
''';

// Includes all_attachment in response so file attachments display correctly.
const _sendMessageMutation = '''
mutation SendMsg(\$input: msgInput!) {
  send_msg(input: \$input) {
    msg {
      msg_id
      msg_body
      msg_type
      sender
      sendername
      senderimg
      created_at
      all_attachment {
        id
        originalname
        file_type
        file_size
        key
        location
      }
    }
  }
}
''';

class ConversationsService {
  ConversationsService._();

  static Future<List<Room>> getRooms(String userId) async {
    final data = await GraphQLService.call(
      _getRoomsQuery,
      variables: {'userId': userId},
    );

    final list = data['rooms'] as List<dynamic>? ?? [];
    final rooms = list
        .map((e) => Room.fromJson(e as Map<String, dynamic>, selfId: userId))
        .where((r) => r.id.isNotEmpty && !r.isArchived)
        .toList();

    rooms.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return (b.lastMsgTime ?? '').compareTo(a.lastMsgTime ?? '');
    });

    return rooms;
  }

  static Future<MessagePage> getMessages(
    String roomId, {
    int page = 1,
    String? selfId,
  }) async {
    final data = await GraphQLService.call(
      _getMessagesQuery,
      variables: {'conversation_id': roomId, 'page': page},
    );

    final outer = data['messages'] as Map<String, dynamic>? ?? {};
    final msgList = outer['msgs'] as List<dynamic>? ?? [];
    final pagination = outer['pagination'] as Map<String, dynamic>? ?? {};

    return MessagePage(
      messages: msgList
          .map((e) => ChatMessage.fromJson(
                e as Map<String, dynamic>,
                selfId: selfId,
              ))
          .toList(),
      page: pagination['page'] as int? ?? page,
      totalPages: pagination['totalPages'] as int? ?? 1,
      total: pagination['total'] as int? ?? 0,
    );
  }

  /// Sends an AES-encrypted message with optional file attachments.
  ///
  /// [attachFiles] is the curated file-info list returned by
  /// [FilesService.uploadFileRaw]. Each map contains only the fields in the
  /// `allFilesData` GraphQL input type so Apollo Server does not reject them.
  static Future<ChatMessage> sendMessage(
    String roomId,
    String text,
    String selfId,
    String companyId,
    List<String> participants, {
    List<Map<String, dynamic>> attachFiles = const [],
  }) async {
    final encryptedBody = EncryptionService.encrypt(text);
    final hasFiles = attachFiles.isNotEmpty;

    // React FileUpload.js: any attachment → 'media_attachment', regardless of
    // whether the user also typed text.
    final msgType = hasFiles ? 'media_attachment' : 'text';

    // Categorise uploaded files into the four arrays the backend stores
    // (mirrors the FileUpload.js loop in the React client exactly).
    final imgfile   = <String>[];
    final audiofile = <String>[];
    final videofile = <String>[];
    final otherfile = <String>[];
    for (final f in attachFiles) {
      final mime = (f['mimetype'] as String? ?? '').toLowerCase();
      final path = '${f['bucket']}/${f['key']}';
      if (mime.contains('image')) {
        imgfile.add(path);
      } else if (mime.contains('video')) {
        videofile.add(path);
      } else if (mime.contains('audio')) {
        audiofile.add(path);
      } else {
        otherfile.add(path);
      }
    }

    final input = <String, dynamic>{
      'conversation_id': roomId,
      'msg_body':        encryptedBody,
      'msg_type':        msgType,
      'sender':          selfId,
      'company_id':      companyId,
      'participants':    participants,
      // is_reply_msg is declared String! (non-null) in msgInput — omitting it
      // causes a GraphQL variable-type error and the mutation is rejected.
      'is_reply_msg':    'no',
      if (hasFiles)
        'attach_files': {
          'imgfile':   imgfile,
          'audiofile': audiofile,
          'videofile': videofile,
          'otherfile': otherfile,
          'allfiles':  attachFiles,
        },
    };

    final data = await GraphQLService.call(
      _sendMessageMutation,
      variables: {'input': input},
    );

    final msgMap =
        (data['send_msg'] as Map<String, dynamic>?)?['msg']
            as Map<String, dynamic>? ??
        {};
    return ChatMessage.fromJson(msgMap, selfId: selfId);
  }
}
