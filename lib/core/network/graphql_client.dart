import 'package:dio/dio.dart';
import '../config/app_config.dart';

// graphql_flutter's link chain (AuthLink → HttpLink) triggers a
// "Bad state: Future already completed" crash on every request because the
// async stream transformer races with an internal timeout Completer.
// Fix: bypass the link system completely and use Dio directly.
// GraphQL is just HTTP POST — Dio handles it perfectly.

class GqlException implements Exception {
  final String message;
  const GqlException(this.message);

  @override
  String toString() => message;
}

class GraphQLService {
  GraphQLService._();

  static String? _token;
  static String? _refreshToken;
  static bool _isRefreshing = false;

  // Incremented on every clearToken() and setTokens() call.
  // A request captures this at start time; if the counter changed by the time
  // the response arrives (because a logout/re-login happened mid-flight),
  // the auth error from the stale request is ignored.
  static int _generation = 0;

  // Fired by AuthNotifier when the server rejects the JWT and we cannot
  // recover via refresh (expired refresh token, invalid token, etc.).
  // Cleared on logout so the callback does not fire after session teardown.
  static void Function()? onAuthError;

  // Fired after a successful token refresh so the caller can persist the new
  // tokens to SecureStorage without this layer knowing about storage.
  static void Function(String token, String refreshToken)? onTokensRefreshed;

  static final _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 30),
      receiveTimeout: const Duration(seconds: 30),
    ),
  );

  // Separate Dio instance for the refresh call — no Bearer header needed.
  static final _refreshDio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 15),
    ),
  );

  static void setToken(String token) {
    _generation++;
    _token = token;
  }

  static void setTokens(String token, String refreshToken) {
    _generation++;
    _token = token;
    _refreshToken = refreshToken;
  }

  static void clearToken() {
    _generation++;
    _token = null;
    _refreshToken = null;
    _isRefreshing = false;
    onAuthError = null;       // prevent callback firing after logout
    onTokensRefreshed = null;
  }

  // ── Token refresh ─────────────────────────────────────────────────────────

  // Matches React's getRefreshToken() in Common.js:
  //   POST /v1/refreshToken { refresh_token }
  //   Response: { token, refresh_token }
  static Future<bool> _tryRefresh() async {
    if (_isRefreshing) return false;
    if (_refreshToken == null || _refreshToken!.isEmpty) return false;

    _isRefreshing = true;
    try {
      final resp = await _refreshDio.post(
        AppConfig.refreshTokenUrl,
        data: {'refresh_token': _refreshToken},
        options: Options(headers: {'Content-Type': 'application/json'}),
      );
      final body = resp.data;
      if (body is! Map) return false;

      final newToken = body['token'] as String?;
      final newRefresh =
          (body['refresh_token'] as String?) ?? _refreshToken;

      if (newToken == null || newToken.isEmpty) return false;

      _token = newToken;
      _refreshToken = newRefresh;
      onTokensRefreshed?.call(newToken, newRefresh!);
      // ignore: avoid_print
      print('[GQL AUTH] token refreshed');
      return true;
    } catch (e) {
      // ignore: avoid_print
      print('[GQL AUTH] refresh failed: $e');
      return false;
    } finally {
      _isRefreshing = false;
    }
  }

  // ── Low-level execution ───────────────────────────────────────────────────

  static String? _extractOperationName(String document) {
    final match = RegExp(
      r'^\s*(?:query|mutation|subscription)\s+(\w+)',
      multiLine: true,
    ).firstMatch(document);
    return match?.group(1);
  }

  // Sends the raw GraphQL POST. Throws GqlException on GraphQL errors.
  static Future<Map<String, dynamic>> _execute(
    String document,
    Map<String, dynamic>? variables,
  ) async {
    final operationName = _extractOperationName(document);
    final response = await _dio.post(
      AppConfig.graphqlUrl,
      data: {
        'query': document,
        if (operationName != null) 'operationName': operationName,
        if (variables != null && variables.isNotEmpty) 'variables': variables,
      },
      options: Options(
        headers: {
          'Content-Type': 'application/json',
          if (_token != null) 'Authorization': 'Bearer $_token',
        },
      ),
    );

    final body = response.data;
    if (body is! Map) {
      throw const GqlException('Unexpected response format from server.');
    }

    final errors = body['errors'];
    if (errors is List && errors.isNotEmpty) {
      final msg =
          ((errors.first as Map)['message'] as String?) ?? 'GraphQL error';
      // ignore: avoid_print
      print('[GQL ERROR] op=$operationName msg=$msg');
      throw GqlException(msg);
    }

    final data = (body['data'] as Map?)?.cast<String, dynamic>() ?? {};
    // ignore: avoid_print
    print('[GQL OK] op=$operationName keys=${data.keys.toList()}');
    return data;
  }

  // ── Public API ────────────────────────────────────────────────────────────

  /// Executes a GraphQL query or mutation.
  ///
  /// On "jwt expired": silently refreshes the token (matching React behaviour)
  /// and retries once. On any other auth rejection: fires [onAuthError] so the
  /// AuthNotifier can force a logout and redirect to /login.
  static Future<Map<String, dynamic>> call(
    String document, {
    Map<String, dynamic>? variables,
  }) async {
    // Snapshot the session generation at the start of this call.
    // If it changes before the response arrives (logout / re-login happened),
    // any auth error from this stale request must be ignored.
    final callGeneration = _generation;

    try {
      return await _execute(document, variables);
    } on GqlException catch (e) {
      final lower = e.message.toLowerCase();
      final isExpired =
          lower.contains('jwt') && lower.contains('expir');

      if (isExpired) {
        // Mirror React: refresh → reload-equivalent (retry the same request).
        final refreshed = await _tryRefresh();
        if (refreshed) {
          try {
            return await _execute(document, variables);
          } on GqlException {
            // Retry also failed — give up and force logout.
            if (callGeneration == _generation) onAuthError?.call();
            rethrow;
          }
        }
        // Refresh itself failed — force logout.
        if (callGeneration == _generation) onAuthError?.call();
        rethrow;
      }

      final isAuthError = lower.contains('authorization') ||
          lower.contains('unauthori') ||
          lower.contains('not authenticated');
      // Only fire onAuthError when the response belongs to the current session.
      // A stale request (made before logout) arriving after re-login would
      // otherwise immediately log the user out again.
      if (isAuthError && callGeneration == _generation) onAuthError?.call();

      rethrow;
    } on DioException catch (e) {
      final detail = e.response?.data?.toString() ??
          e.message ??
          'Network error. Check your connection.';
      throw GqlException(detail);
    } catch (e) {
      throw GqlException(e.toString());
    }
  }
}
