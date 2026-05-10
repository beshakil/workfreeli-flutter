import 'package:intl/intl.dart';

/// Parses an ISO 8601 string OR a millisecond-epoch integer/string.
DateTime? _parseDate(dynamic raw) {
  if (raw == null) return null;
  if (raw is int) return DateTime.fromMillisecondsSinceEpoch(raw);
  final s = raw.toString();
  if (s.isEmpty) return null;
  return DateTime.tryParse(s) ??
      (int.tryParse(s) != null
          ? DateTime.fromMillisecondsSinceEpoch(int.parse(s))
          : null);
}

// ── Tag details ────────────────────────────────────────────────────────────────

class TagDetails {
  final String tagId;
  final String title;
  final String? tagColor;
  final String? tagType;
  final String? taggedBy;
  final int? useCount;
  final List<String>? favourite; // Array of user IDs who favourited
  final List<String>? teamList;
  final String? createdAt;

  const TagDetails({
    required this.tagId,
    required this.title,
    this.tagColor,
    this.tagType,
    this.taggedBy,
    this.useCount,
    this.favourite,
    this.teamList,
    this.createdAt,
  });

  TagDetails copyWith({int? useCount}) => TagDetails(
        tagId: tagId,
        title: title,
        tagColor: tagColor,
        tagType: tagType,
        taggedBy: taggedBy,
        useCount: useCount ?? this.useCount,
        favourite: favourite,
        teamList: teamList,
        createdAt: createdAt,
      );

  factory TagDetails.fromJson(Map<String, dynamic> json) => TagDetails(
        tagId: json['tag_id'] as String? ?? json['_id'] as String? ?? '',
        title: json['title'] as String? ?? '',
        tagColor: json['tag_color'] as String?,
        tagType: json['tag_type'] as String?,
        taggedBy: json['tagged_by'] as String?,
        useCount: json['use_count'] as int?,
        favourite: (json['favourite'] as List<dynamic>?)?.cast<String>(),
        teamList: (json['team_list'] as List<dynamic>?)?.cast<String>(),
        createdAt: json['created_at'] as String?,
      );
}

// ── File summary ──────────────────────────────────────────────────────────────

/// Counts returned by `get_file_gallery { summary { ... } }`.
class FilesSummary {
  final int total;
  final int image;
  final int audio;
  final int video;
  final int voice;
  final int other;

  const FilesSummary({
    this.total = 0,
    this.image = 0,
    this.audio = 0,
    this.video = 0,
    this.voice = 0,
    this.other = 0,
  });

  /// Documents (backend calls it 'other').
  int get docs => other;

  factory FilesSummary.fromJson(Map<String, dynamic> json) => FilesSummary(
        total: json['total'] as int? ?? 0,
        image: json['image'] as int? ?? 0,
        audio: json['audio'] as int? ?? 0,
        video: json['video'] as int? ?? 0,
        voice: json['voice'] as int? ?? 0,
        other: json['other'] as int? ?? 0,
      );
}

// ── Pagination info ────────────────────────────────────────────────────────────

class PaginationInfo {
  final int page;
  final int totalPages;
  final int total;

  const PaginationInfo({
    required this.page,
    required this.totalPages,
    required this.total,
  });

  factory PaginationInfo.fromJson(Map<String, dynamic> json) => PaginationInfo(
        page: json['page'] as int? ?? 1,
        totalPages: json['totalPages'] as int? ?? 1,
        total: json['total'] as int? ?? 0,
      );

  bool get hasMore => page < totalPages;
}

// ── Shared file ───────────────────────────────────────────────────────────────

class SharedFile {
  final String id;
  final String originalName;
  final String fileType;
  final String? fileSize;
  final String? location;
  final String? key;
  final String? uploadedBy;
  final String? conversationId;
  final String? conversationTitle;
  final String? createdAt;
  final String? referenceId;
  final String? referenceType;
  final bool star;
  final bool isImage;
  final bool isVideo;
  final bool isAudio;
  final List<TagDetails> tags;
  final int viewCount; // For links - how many people viewed

  const SharedFile({
    required this.id,
    required this.originalName,
    required this.fileType,
    this.fileSize,
    this.location,
    this.key,
    this.uploadedBy,
    this.conversationId,
    this.conversationTitle,
    this.createdAt,
    this.referenceId,
    this.referenceType,
    this.star = false,
    this.isImage = false,
    this.isVideo = false,
    this.isAudio = false,
    this.tags = const [],
    this.viewCount = 0,
  });

  factory SharedFile.fromJson(Map<String, dynamic> json) {
    final type = (json['file_type'] as String? ?? '').toLowerCase();

    // Parse tag_list_details
    List<TagDetails> tags = [];
    final tagListDetails = json['tag_list_details'] as List<dynamic>?;
    if (tagListDetails != null) {
      tags = tagListDetails
          .map((e) => TagDetails.fromJson(e as Map<String, dynamic>))
          .toList();
    }

    // Parse file_view to get count
    int viewCount = 0;
    final fileViewData = json['file_view'] as List<dynamic>?;
    if (fileViewData != null) {
      viewCount = fileViewData.length;
    }

    return SharedFile(
      id: json['id'] as String? ?? '',
      originalName: json['originalname'] as String? ?? 'Unknown file',
      fileType: json['file_type'] as String? ?? 'other',
      fileSize: _formatSize(json['file_size']),
      location: json['location']?.toString(),
      key: json['key']?.toString(),
      uploadedBy: json['uploaded_by']?.toString(),
      conversationId: json['conversation_id']?.toString(),
      conversationTitle: json['conversation_title']?.toString(),
      createdAt: json['created_at']?.toString(),
      referenceId: json['referenceId']?.toString(),
      referenceType: json['reference_type']?.toString(),
      star: json['star'] == true,
      isImage: type == 'image',
      isVideo: type == 'video',
      isAudio: type == 'audio' || type == 'voice',
      tags: tags,
      viewCount: viewCount,
    );
  }

  SharedFile copyWith({bool? star, List<TagDetails>? tags}) => SharedFile(
        id: id,
        originalName: originalName,
        fileType: fileType,
        fileSize: fileSize,
        location: location,
        key: key,
        uploadedBy: uploadedBy,
        conversationId: conversationId,
        conversationTitle: conversationTitle,
        createdAt: createdAt,
        referenceId: referenceId,
        referenceType: referenceType,
        star: star ?? this.star,
        isImage: isImage,
        isVideo: isVideo,
        isAudio: isAudio,
        tags: tags ?? this.tags,
        viewCount: viewCount,
      );

  /// Full URL to download/preview this file from the file server.
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

  /// Date in "DD/MM/YYYY" format matching the React web app.
  String get formattedDate {
    final dt = _parseDate(createdAt);
    if (dt == null) return '';
    return DateFormat('dd/MM/yyyy').format(dt.toLocal());
  }

  /// Time in "h:mm a" format matching the React web app.
  String get formattedTimePart {
    final dt = _parseDate(createdAt);
    if (dt == null) return '';
    return DateFormat('h:mm a').format(dt.toLocal());
  }

  /// Relative time label ("2h ago", "3d ago") for file cards.
  String get formattedTime {
    final dt = _parseDate(createdAt);
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
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

// ── Link ───────────────────────────────────────────────────────────────────────

class Link {
  final String urlId;
  final String? title;
  final String url;
  final String msgId;
  final String conversationId;
  final String companyId;
  final String userId;
  final String? createdAt;
  final String? conversationTitle;
  final String? uploadedBy;
  final List<String> participants;
  final bool hasHide;
  final bool hasDelete;
  final bool isSecret;
  final List<String> secretUser;
  final List<String> otherUser;

  const Link({
    required this.urlId,
    this.title,
    required this.url,
    required this.msgId,
    required this.conversationId,
    required this.companyId,
    required this.userId,
    this.createdAt,
    this.conversationTitle,
    this.uploadedBy,
    this.participants = const [],
    this.hasHide = false,
    this.hasDelete = false,
    this.isSecret = false,
    this.secretUser = const [],
    this.otherUser = const [],
  });

  factory Link.fromJson(Map<String, dynamic> json) {
    return Link(
      urlId: json['url_id'] as String? ?? '',
      title: json['title'] as String?,
      url: json['url'] as String? ?? '',
      msgId: json['msg_id'] as String? ?? '',
      conversationId: json['conversation_id'] as String? ?? '',
      companyId: json['company_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      createdAt: json['created_at']?.toString(),
      conversationTitle: json['conversation_title']?.toString(),
      uploadedBy: json['uploaded_by']?.toString(),
      participants:
          (json['participants'] as List<dynamic>?)?.cast<String>() ?? [],
      hasHide: json['has_hide'] is List
          ? (json['has_hide'] as List).isNotEmpty
          : false,
      hasDelete: json['has_delete'] is List
          ? (json['has_delete'] as List).isNotEmpty
          : false,
      isSecret: json['is_secret'] == true,
      secretUser: (json['secret_user'] as List<dynamic>?)?.cast<String>() ?? [],
      otherUser: (json['other_user'] as List<dynamic>?)?.cast<String>() ?? [],
    );
  }

  Link copyWith({
    String? title,
    String? url,
    List<String>? participants,
    bool? hasHide,
    bool? hasDelete,
  }) =>
      Link(
        urlId: urlId,
        title: title ?? this.title,
        url: url ?? this.url,
        msgId: msgId,
        conversationId: conversationId,
        companyId: companyId,
        userId: userId,
        createdAt: createdAt,
        conversationTitle: conversationTitle,
        uploadedBy: uploadedBy,
        participants: participants ?? this.participants,
        hasHide: hasHide ?? this.hasHide,
        hasDelete: hasDelete ?? this.hasDelete,
        isSecret: isSecret,
        secretUser: secretUser,
        otherUser: otherUser,
      );

  String get formattedDate {
    final dt = _parseDate(createdAt);
    if (dt == null) return '';
    return DateFormat('dd/MM/yyyy').format(dt.toLocal());
  }

  String get formattedTime {
    final dt = _parseDate(createdAt);
    if (dt == null) return '';
    final now = DateTime.now();
    final diff = now.difference(dt);
    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
    return '${(diff.inDays / 30).floor()}mo ago';
  }
}

// ── Link pagination ────────────────────────────────────────────────────────────

class LinkPaginationInfo {
  final int page;
  final int totalPages;
  final int total;

  const LinkPaginationInfo({
    required this.page,
    required this.totalPages,
    required this.total,
  });

  factory LinkPaginationInfo.fromJson(Map<String, dynamic> json) =>
      LinkPaginationInfo(
        page: json['page'] as int? ?? 1,
        totalPages: json['totalPages'] as int? ?? 1,
        total: json['total'] as int? ?? 0,
      );

  bool get hasMore => page < totalPages;
}

// ── Link result ────────────────────────────────────────────────────────────────

class LinksResult {
  final List<Link> links;
  final LinkPaginationInfo pagination;

  const LinksResult({
    required this.links,
    required this.pagination,
  });
}
