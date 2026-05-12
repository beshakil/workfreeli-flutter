import 'package:intl/intl.dart';
import '../encryption/encryption_service.dart';
import '../../features/files/file_models.dart';

/// Safe parser (handles String / List / null)
String _safeString(dynamic value) {
  if (value == null) return '';
  if (value is List) return value.join(' ');
  return value.toString();
}

/// Strips HTML tags and decodes common HTML entities.
String _stripHtml(String html) {
  if (html.isEmpty) return html;
  var text = html.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'<[^>]+>'), '');
  text = text
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&nbsp;', ' ');
  return text.trim();
}

class Room {
  final String id;
  final String title;
  final bool isGroup;
  final bool isArchived;
  final bool isPinned;
  final bool isMuted;
  final bool isClosedFor;
  final String? friendId;
  final String? convImg;
  final String? lastMsgTime;
  final String? lastMsgPreview;
  final String? systemConversation;
  final List<String> participants;
  final String? companyId;

  const Room({
    required this.id,
    required this.title,
    required this.isGroup,
    this.isArchived = false,
    this.isPinned = false,
    this.isMuted = false,
    this.isClosedFor = false,
    this.friendId,
    this.convImg,
    this.lastMsgTime,
    this.lastMsgPreview,
    this.systemConversation,
    this.participants = const [],
    this.companyId,
  });

  factory Room.fromJson(Map<String, dynamic> json, {String? selfId}) => Room(
        id: _safeString(json['conversation_id']),
        title: _safeString(json['title']).isEmpty
            ? 'Untitled'
            : _safeString(json['title']),
        isGroup: _safeString(json['group']) == 'yes',
        isArchived: _safeString(json['archive']) == 'yes',
        isClosedFor: _safeString(json['close_for']) == 'yes',
        isPinned: (json['pin'] as List<dynamic>?)?.contains(selfId) ?? false,
        isMuted:
            (json['has_mute'] as List<dynamic>?)?.contains(selfId) ?? false,
        friendId: _safeString(json['friend_id']),
        convImg: json['conv_img']?.toString(),
        lastMsgTime: _safeString(json['last_msg_time']),
        systemConversation: _safeString(json['system_conversation']),
        companyId: _safeString(json['company_id']),
        participants: (json['participants'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            [],
      );

  Room copyWith({
    String? title,
    String? lastMsgPreview,
    String? lastMsgTime,
    bool? isMuted,
    bool? isArchived,
    bool? isPinned,
    bool? isClosedFor,
    List<String>? participants,
  }) =>
      Room(
        id: id,
        title: title ?? this.title,
        isGroup: isGroup,
        isArchived: isArchived ?? this.isArchived,
        isPinned: isPinned ?? this.isPinned,
        isMuted: isMuted ?? this.isMuted,
        isClosedFor: isClosedFor ?? this.isClosedFor,
        friendId: friendId,
        convImg: convImg,
        lastMsgTime: lastMsgTime ?? this.lastMsgTime,
        lastMsgPreview: lastMsgPreview ?? this.lastMsgPreview,
        systemConversation: systemConversation,
        participants: participants ?? this.participants,
        companyId: companyId,
      );

  bool get isSystemConversation =>
      systemConversation != null &&
      systemConversation != 'No' &&
      systemConversation!.isNotEmpty;

  String get initials {
    final words = title.trim().split(RegExp(r'\s+'));
    if (words.length >= 2 && words[0].isNotEmpty && words[1].isNotEmpty) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return title.isNotEmpty ? title[0].toUpperCase() : '?';
  }

  String get formattedTime {
    if (lastMsgTime == null || lastMsgTime!.isEmpty) return '';
    try {
      final raw = lastMsgTime!;
      final dt = DateTime.tryParse(raw) ??
          DateTime.fromMillisecondsSinceEpoch(int.tryParse(raw) ?? 0);
      if (dt.millisecondsSinceEpoch == 0) return '';
      final now = DateTime.now();
      final diff = now.difference(dt);

      if (diff.inSeconds < 60) return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m';
      if (diff.inHours < 24) return '${diff.inHours}h';
      if (diff.inDays < 7) return '${diff.inDays}d';

      return DateFormat('MMM d').format(dt);
    } catch (_) {
      return '';
    }
  }
}

// ── Message attachment ────────────────────────────────────────────────────────

class MessageAttachment {
  final String id;
  final String originalName;
  final String fileType;
  final String? fileSize;
  final String? key;
  final String? location;
  final List<TagDetails> tags;

  const MessageAttachment({
    required this.id,
    required this.originalName,
    required this.fileType,
    this.fileSize,
    this.key,
    this.location,
    this.tags = const [],
  });

  factory MessageAttachment.fromJson(Map<String, dynamic> json) {
    // Parse tags - try multiple possible field names from backend
    List<TagDetails> tags = [];

    // Try 'tag_list_details' first (used by file gallery API)
    var tagListDetails = json['tag_list_details'] as List<dynamic>?;
    // Fall back to 'tags' field (common alternative)
    tagListDetails ??= json['tags'] as List<dynamic>?;
    // Try 'tag_list' as another fallback
    tagListDetails ??= json['tag_list'] as List<dynamic>?;

    if (tagListDetails != null) {
      tags = tagListDetails
          .whereType<Map<String, dynamic>>()
          .map((e) => TagDetails.fromJson(e))
          .toList();
    }

    return MessageAttachment(
      id: _safeString(json['id']),
      originalName: _safeString(json['originalname']).isEmpty
          ? 'Unknown file'
          : _safeString(json['originalname']),
      fileType: _safeString(json['file_type']),
      fileSize: _formatSize(json['file_size']),
      key: json['key']?.toString(),
      location: json['location']?.toString(),
      tags: tags,
    );
  }

  String downloadUrl(String baseUrl) {
    if (location != null && location!.startsWith('http')) return location!;
    if (key != null && key!.isNotEmpty) return '$baseUrl/$key';
    return '';
  }

  String get displayType {
    final ext = originalName.contains('.')
        ? originalName.split('.').last.toUpperCase()
        : fileType.toUpperCase();
    return ext.length > 4 ? ext.substring(0, 4) : ext;
  }

  bool get isImage {
    final t = fileType.toLowerCase();
    final ext = originalName.split('.').last.toLowerCase();
    return t == 'image' ||
        ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
  }

  static String _formatSize(dynamic raw) {
    if (raw == null) return '';
    final bytes = raw is int ? raw : int.tryParse(raw.toString()) ?? 0;
    if (bytes <= 0) return '';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}

// ── Chat message ──────────────────────────────────────────────────────────────

class ChatMessage {
  final String id;
  final String msg;
  final String msgType;
  final String senderId;
  final String senderName;
  final String? senderImg;
  final String createdAt;
  final bool isSelf;
  final List<MessageAttachment> attachments;

  const ChatMessage({
    required this.id,
    required this.msg,
    required this.msgType,
    required this.senderId,
    required this.senderName,
    this.senderImg,
    required this.createdAt,
    this.isSelf = false,
    this.attachments = const [],
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json, {String? selfId}) {
    final raw = EncryptionService.decrypt(_safeString(json['msg_body']));
    final attachList = json['all_attachment'] as List<dynamic>? ?? [];
    return ChatMessage(
      id: _safeString(json['msg_id']),
      msg: _stripHtml(raw),
      msgType: _safeString(json['msg_type']).isEmpty
          ? 'text'
          : _safeString(json['msg_type']),
      senderId: _safeString(json['sender']),
      senderName: _safeString(json['sendername']).isEmpty
          ? 'Unknown'
          : _safeString(json['sendername']),
      senderImg: json['senderimg']?.toString(),
      createdAt: _safeString(json['created_at']),
      isSelf: selfId != null && _safeString(json['sender']) == selfId,
      attachments: attachList
          .map((e) => MessageAttachment.fromJson(e as Map<String, dynamic>))
          .where((a) => a.id.isNotEmpty || a.originalName != 'Unknown file')
          .toList(),
    );
  }

  String get senderInitials {
    final parts = senderName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2 && parts[0].isNotEmpty && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return senderName.isNotEmpty ? senderName[0].toUpperCase() : '?';
  }

  String get formattedTime {
    try {
      final raw = createdAt;
      final dt = DateTime.tryParse(raw) ??
          DateTime.fromMillisecondsSinceEpoch(int.tryParse(raw) ?? 0);
      return DateFormat('h:mm a').format(dt.toLocal());
    } catch (_) {
      return '';
    }
  }

  bool get isTextMessage => msgType == 'text' || msgType.isEmpty;
  bool get hasAttachments => attachments.isNotEmpty;
}

class MessagePage {
  final List<ChatMessage> messages;
  final int page;
  final int totalPages;
  final int total;

  const MessagePage({
    required this.messages,
    required this.page,
    required this.totalPages,
    required this.total,
  });

  bool get hasMore => page < totalPages;
}
