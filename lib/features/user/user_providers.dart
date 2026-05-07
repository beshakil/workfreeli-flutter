import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'user_models.dart';
import 'user_service.dart';

// Not autoDispose — cached for the session lifetime.
final meProvider = FutureProvider<AppUser>((ref) => UserService.me());

// Maps user ID → display name for the current company.
// Used by the task board to show assignee names instead of raw IDs.
// Depends on meProvider so it automatically uses the correct company_id.
final usersMapProvider = FutureProvider<Map<String, String>>((ref) async {
  final me = await ref.watch(meProvider.future);
  return UserService.getUsersMap(me.companyId);
});
