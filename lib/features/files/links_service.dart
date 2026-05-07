import '../../core/network/graphql_client.dart';
import 'file_models.dart';

// ── GraphQL query ─────────────────────────────────────────────────────────────

const _getLinksQuery = '''
query Hub_all_link_msgs(
  \$conversation_ids: [String!],
  \$from: String,
  \$to: String,
  \$url: String,
  \$user_ids: [String!],
  \$sort_by: String,
  \$sort_style: String,
  \$page: Int,
  \$timezone: String
) {
  hub_all_link_msgs(
    conversation_ids: \$conversation_ids,
    from: \$from,
    to: \$to,
    url: \$url,
    user_ids: \$user_ids,
    sort_by: \$sort_by,
    sort_style: \$sort_style,
    page: \$page,
    timezone: \$timezone
  ) {
    links {
      url_id
      created_at
      msg_id
      conversation_id
      company_id
      user_id
      url
      title
      has_hide
      has_delete
      root_conv_id
      is_delete
      secret_user
      other_user
      participants
      conversation_title
      uploaded_by
    }
    pagination {
      page
      totalPages
      total
    }
  }
}
''';

// ── Service ───────────────────────────────────────────────────────────────────

class LinksService {
  LinksService._();

  static Future<LinksResult> getLinks({
    required List<String> conversationIds,
    String? from,
    String? to,
    String? url,
    List<String>? userIds,
    String? sortBy,
    String? sortStyle,
    int page = 1,
    String? timezone,
  }) async {
    final data = await GraphQLService.call(
      _getLinksQuery,
      variables: {
        'conversation_ids': conversationIds,
        if (from != null) 'from': from,
        if (to != null) 'to': to,
        if (url != null && url.isNotEmpty) 'url': url,
        if (userIds != null && userIds.isNotEmpty) 'user_ids': userIds,
        if (sortBy != null) 'sort_by': sortBy,
        if (sortStyle != null) 'sort_style': sortStyle,
        'page': page,
        if (timezone != null) 'timezone': timezone,
      },
    );

    final result = data['hub_all_link_msgs'] as Map<String, dynamic>? ?? {};
    final linksList = result['links'] as List<dynamic>? ?? [];
    final paginationMap = result['pagination'] as Map<String, dynamic>? ?? {};

    return LinksResult(
      links: linksList
          .map((e) => Link.fromJson(e as Map<String, dynamic>))
          .toList(),
      pagination: LinkPaginationInfo.fromJson(paginationMap),
    );
  }
}
