import '../../core/network/graphql_client.dart';
import 'user_models.dart';

const _meQuery = '''
query Me {
  me {
    id
    firstname
    lastname
    email
    company_id
    company_name
    img
    phone
    role
    access
    timezone
    multi_company
  }
}
''';

const _getUsersQuery = '''
query Users(\$company_id: String!) {
  users(company_id: \$company_id) {
    id
    fnln
  }
}
''';

class UserService {
  UserService._();

  static Future<AppUser> me() async {
    final data = await GraphQLService.call(_meQuery);
    final me = data['me'] as Map<String, dynamic>?;
    if (me == null) throw const GqlException('No user data returned.');
    return AppUser.fromJson(me);
  }

  /// Returns a map of user ID → display name for the given company.
  /// Used by the task board to resolve assign_to IDs to readable names.
  static Future<Map<String, String>> getUsersMap(String companyId) async {
    final data = await GraphQLService.call(
      _getUsersQuery,
      variables: {'company_id': companyId},
    );
    final list = data['users'] as List<dynamic>? ?? [];
    final map = <String, String>{};
    for (final u in list) {
      final id   = u['id']   as String? ?? '';
      final name = (u['fnln'] as String? ?? '').trim();
      if (id.isNotEmpty) map[id] = name.isNotEmpty ? name : id;
    }
    return map;
  }
}
