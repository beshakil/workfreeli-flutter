import 'dart:io';

import 'package:dio/dio.dart';

import '../../core/config/app_config.dart';
import '../../core/network/graphql_client.dart';
import '../../core/storage/secure_storage.dart';
import 'file_models.dart';

// ── GraphQL query ─────────────────────────────────────────────────────────────

const _getFilesQuery = '''
query GetFileGallery(
  \$page: Int
  \$tab: String
  \$conversation_id: String
  \$file_type: String
) {
  get_file_gallery(
    page: \$page
    tab: \$tab
    conversation_id: \$conversation_id
    file_type: \$file_type
  ) {
    files {
      id
      conversation_id
      conversation_title
      uploaded_by
      file_type
      key
      location
      originalname
      file_size
      created_at
      referenceId
      reference_type
      star
      tag_list_details {
        tag_id
        title
        tag_color
        tag_type
      }
    }
    summary {
      total
      image
      audio
      video
      voice
      other
    }
    pagination {
      page
      totalPages
      total
    }
  }
}
''';

// ── Result types ────────────────────────────────────────────────────────────────

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

class FilesResult {
  final List<SharedFile> files;
  final FilesSummary summary;
  final PaginationInfo pagination;

  const FilesResult({
    required this.files,
    required this.summary,
    required this.pagination,
  });
}

// ── Service ───────────────────────────────────────────────────────────────────

class FilesService {
  FilesService._();

  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 60),
      receiveTimeout: const Duration(seconds: 120),
    ),
  );

  // ── Query ─────────────────────────────────────────────────────────────────

  /// Fetches the file gallery.
  ///
  /// [tab] mirrors the web: `'file'` (default) or `'links'` (maps to file_sub_type 'ref').
  /// [fileType] mirrors the web filter chips: `'image'`, `'video'`, `'audio'`,
  /// `'voice'`, `'docs'`. Pass `null` / omit for all files.
  /// [fileSubType] additional filter: `'ref'` for shared links, `'star'` for starred,
  /// `'tag'` for tagged files, `'share'` for shared files.
  static Future<FilesResult> getFiles({
    int page = 1,
    String tab = 'file',
    String? conversationId,
    String? fileType,
    String? fileSubType,
  }) async {
    final data = await GraphQLService.call(
      _getFilesQuery,
      variables: {
        'page': page,
        'tab': tab,
        // 'all_files' → files from every conversation the user belongs to
        'conversation_id': conversationId ?? 'all_files',
        if (fileType != null && fileType != 'all') 'file_type': fileType,
        if (fileSubType != null) 'file_sub_type': fileSubType,
      },
    );

    final gallery = data['get_file_gallery'] as Map<String, dynamic>? ?? {};
    final list = gallery['files'] as List<dynamic>? ?? [];
    final summaryMap = gallery['summary'] as Map<String, dynamic>? ?? {};
    final paginationMap = gallery['pagination'] as Map<String, dynamic>? ?? {};

    return FilesResult(
      files: list
          .map((e) => SharedFile.fromJson(e as Map<String, dynamic>))
          .where((f) => f.id.isNotEmpty)
          .toList(),
      summary: FilesSummary.fromJson(summaryMap),
      pagination: PaginationInfo.fromJson(paginationMap),
    );
  }

  /// Fetches tags for the file hub.
  ///
  /// [conversationId] optional - limits tags to a specific conversation.
  /// Pass empty string for all conversations (matches React client behavior).
  static Future<List<TagDetails>> getTags({
    String? conversationId,
  }) async {
    const getTagsQuery = '''
query GetFileGallery(
  \$conversation_id: String,
  \$file_type: String,
  \$file_sub_type: String,
  \$tag_id: [String!]
) {
  get_file_gallery(
    conversation_id: \$conversation_id,
    file_type: \$file_type,
    file_sub_type: \$file_sub_type,
    tag_id: \$tag_id,
    tab: "tag"
  ) {
    tags {
      tag_id
      title
      tag_color
      tag_type
      tagged_by
      use_count
      favourite
    }
  }
}
''';

    final data = await GraphQLService.call(
      getTagsQuery,
      variables: {
        'conversation_id': conversationId ?? '',
        'file_type': 'all',
        'file_sub_type': '',
        'tag_id': ['all'],
      },
    );

    final gallery = data['get_file_gallery'] as Map<String, dynamic>? ?? {};
    final tagsList = gallery['tags'] as List<dynamic>? ?? [];

    return tagsList
        .map((e) => TagDetails.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  // ── Upload (returns SharedFile for the files list) ─────────────────────────

  /// Uploads [file] to `/v1/upload_obj` and returns a [SharedFile] suitable
  /// for prepending to the files list.
  static Future<SharedFile> uploadFile({
    required File file,
    required String userEmail,
    void Function(int sent, int total)? onProgress,
  }) async {
    final info = await uploadFileRaw(
      file: file,
      userEmail: userEmail,
      onProgress: onProgress,
    );

    return SharedFile(
      id: info['key'] as String? ?? '',
      originalName:
          info['originalname'] as String? ?? file.uri.pathSegments.last,
      fileType: info['file_type'] as String? ?? 'other',
      fileSize: _formatSize(info['file_size']),
      location: info['location'] as String?,
      key: info['key'] as String?,
      uploadedBy: null,
      createdAt: DateTime.now().toIso8601String(),
    );
  }

  // ── Upload (returns curated map for message attach_files) ────────────────

  /// Uploads [file] and returns a curated file-info map that matches the
  /// `allFilesData` GraphQL input type exactly — no extra fields that the
  /// schema would reject (`metadata`, `transforms`, `etag`, `contentType`).
  ///
  /// The returned map is passed directly into:
  ///   `send_msg(input: { attach_files: { allfiles: [<map>] } })`
  /// mirroring the React web client's FileUpload.js exactly.
  static Future<Map<String, dynamic>> uploadFileRaw({
    required File file,
    required String userEmail,
    void Function(int sent, int total)? onProgress,
  }) async {
    final token = await SecureStorage.getToken();
    final bucketName = userEmail.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '-');
    final fileName = file.uri.pathSegments.last;

    final formData = FormData.fromMap({
      'bucket_name': bucketName,
      // React uses moment().format('x') + index → millisecond timestamp string
      'sl': DateTime.now().millisecondsSinceEpoch.toString(),
      'file_upload': await MultipartFile.fromFile(
        file.path,
        filename: fileName,
      ),
    });

    final response = await _dio.post(
      AppConfig.uploadUrl,
      data: formData,
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
      ),
      onSendProgress: onProgress,
    );

    final body = response.data as Map?;
    if (body == null || body['status'] == false) {
      throw GqlException(body?['msg']?.toString() ?? 'Upload failed.');
    }

    final fileInfoList = body['file_info'] as List?;
    if (fileInfoList == null || fileInfoList.isEmpty) {
      throw const GqlException('Upload succeeded but file_info missing.');
    }

    final raw = fileInfoList.first as Map<String, dynamic>;

    // Return ONLY the fields present in the allFilesData GraphQL input type.
    // Extra server fields (metadata, transforms, etag, contentType) are NOT in
    // the schema and cause a "Field not defined" rejection from Apollo Server.
    // voriginalName = originalname (React sends both; ours are the same name).
    return {
      'originalname': raw['originalname'] ?? fileName,
      'voriginalName': raw['originalname'] ?? fileName,
      'mimetype': raw['mimetype'] ?? 'application/octet-stream',
      'bucket': raw['bucket'] ?? bucketName,
      'key': raw['key'] ?? '',
      'acl': raw['acl'] ?? 'public-read',
      'size': raw['size'] is int
          ? raw['size']
          : int.tryParse('${raw['size']}') ?? 0,
      'location': raw['location'] ?? '',
    };
  }

  // ── Download ──────────────────────────────────────────────────────────────

  static Future<void> downloadFile({
    required String url,
    required String savePath,
    void Function(int received, int total)? onProgress,
  }) async {
    final token = await SecureStorage.getToken();

    await _dio.download(
      url,
      savePath,
      options: Options(
        headers: {
          if (token != null) 'Authorization': 'Bearer $token',
        },
        responseType: ResponseType.bytes,
      ),
      onReceiveProgress: onProgress,
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

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
