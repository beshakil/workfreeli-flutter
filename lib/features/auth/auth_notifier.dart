import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/auth_models.dart';
import '../../core/navigation/navigator_key.dart';
import '../../core/network/graphql_client.dart';
import '../../core/storage/secure_storage.dart';
import '../conversations/conversations_providers.dart';
import '../files/files_providers.dart';
import '../tasks/tasks_providers.dart';
import '../user/user_providers.dart';
import '../user/user_service.dart';
import '../xmpp/xmpp_provider.dart';
import 'auth_service.dart';
import 'auth_state.dart';
import 'device_info_helper.dart';

class AuthNotifier extends StateNotifier<AuthState> {
  AuthNotifier(this._ref) : super(const AuthState.loading()) {
    _registerCallbacks();
    _init();
  }

  final Ref _ref;

  // Registers both GraphQLService callbacks so they survive a logout → re-login
  // cycle (clearToken() nullifies them, so we re-register after every token set).
  void _registerCallbacks() {
    GraphQLService.onAuthError = _onServerAuthError;
    GraphQLService.onTokensRefreshed = _onTokensRefreshed;
  }

  // Called by GraphQLService after a transparent token refresh succeeds.
  // Persist the new tokens to SecureStorage so a cold restart still works.
  // XMPP uses a fixed server-side password (not the JWT), so no XMPP sync needed.
  void _onTokensRefreshed(String newToken, String newRefresh) {
    SecureStorage.saveTokens(newToken, newRefresh);
  }

  // Called by GraphQLService when the server rejects the JWT and a refresh
  // is not possible (expired refresh token, completely invalid token, etc.).
  // Guard: only act while the user is in an authenticated session so we do
  // not loop during login flows or after a manual logout.
  void _onServerAuthError() {
    if (state.step == AuthStep.authenticated) {
      logout();
    }
  }

  Future<void> _init() async {
    await Future.delayed(const Duration(milliseconds: 1200));
    final token = await SecureStorage.getToken();
    final refreshToken = await SecureStorage.getRefreshToken();
    if (token != null && token.isNotEmpty) {
      // Set BOTH tokens so the refresh flow works after a cold restart.
      GraphQLService.setTokens(token, refreshToken ?? '');
      _registerCallbacks(); // re-register: hot-restart may have cleared them
      try {
        await UserService.me();
        state = const AuthState.authenticated();
      } on GqlException catch (e) {
        // Only clear the token for genuine auth failures.
        // Network errors (DioException wrapped in GqlException containing
        // "Network error" or connection refused) should NOT log the user out —
        // they'll retry naturally when the network comes back.
        final lower = e.message.toLowerCase();
        final isAuthFailure = lower.contains('authorization') ||
            lower.contains('unauthori') ||
            lower.contains('not authenticated') ||
            lower.contains('jwt');
        if (isAuthFailure) {
          await SecureStorage.clearTokens();
          GraphQLService.clearToken();
          state = const AuthState.unauthenticated();
        } else {
          // Treat as transient — keep the stored token and let the user retry.
          state = const AuthState.authenticated();
        }
      } catch (_) {
        // Unknown error — treat as transient.
        state = const AuthState.authenticated();
      }
    } else {
      state = const AuthState.unauthenticated();
    }
  }

  Future<String> get _deviceId async {
    var id = await SecureStorage.getDeviceId();
    if (id == null) {
      id = await DeviceInfoHelper.getDeviceId();
      await SecureStorage.saveDeviceId(id);
    }
    return id;
  }

  Future<void> validate(String email, String password) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await AuthService.validate(
        email: email,
        password: password,
        deviceId: await _deviceId,
      );
      _handleResponse(response, email: email);
    } catch (e) {
      state = AuthState(
        step: AuthStep.unauthenticated,
        error: _message(e),
        isLoading: false,
      );
    }
  }

  Future<void> signinWithOtp(String email) async {
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await AuthService.signinWithOtp(
        email: email,
        deviceId: await _deviceId,
      );
      _handleResponse(response, email: email);
    } catch (e) {
      state = AuthState(
        step: AuthStep.unauthenticated,
        error: _message(e),
        isLoading: false,
      );
    }
  }

  Future<void> verifyOtp(String code, {bool trustDevice = false}) async {
    final email = state.email;
    if (email == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      if (trustDevice) await SecureStorage.setTrusted(true);
      final response = await AuthService.verifyOtp(
        email: email,
        code: code,
        deviceId: await _deviceId,
        trustDevice: trustDevice,
        sessionToken: state.sessionToken,
      );
      _handleResponse(response, email: email);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _message(e));
    }
  }

  Future<void> selectCompany(String companyId) async {
    final email = state.email;
    final sessionToken = state.sessionToken;
    if (email == null || sessionToken == null) return;
    state = state.copyWith(isLoading: true, clearError: true);
    try {
      final response = await AuthService.selectCompany(
        email: email,
        companyId: companyId,
        sessionToken: sessionToken,
        deviceId: await _deviceId,
      );
      _handleResponse(response, email: email);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: _message(e));
    }
  }

  void _handleResponse(LoginResponse response, {required String email}) {
    if (response.isError) {
      state = state.copyWith(
        isLoading: false,
        error: response.message ?? 'Authentication failed.',
      );
      return;
    }

    if (response.hasToken) {
      final token = response.token!;
      final refresh = response.refreshToken ?? '';
      SecureStorage.saveTokens(token, refresh);
      // Set BOTH tokens and re-register callbacks (clearToken() in logout()
      // nullifies them, so we always re-register after a successful login).
      GraphQLService.setTokens(token, refresh);
      _registerCallbacks();
      // During logout, session providers are invalidated while HomeScreen is
      // still mounted, causing immediate refetches with no token that settle
      // them into error states. Re-invalidate here so they refetch with the
      // new token when HomeScreen remounts after redirect.
      // xmppAutoConnectProvider depends on meProvider, but may be in error
      // state with no active watcher — invalidate it explicitly so XMPP
      // reconnects after re-login.
      _ref.invalidate(meProvider);
      _ref.invalidate(roomsProvider);
      _ref.invalidate(unreadInitProvider);
      _ref.invalidate(xmppAutoConnectProvider);
      state = const AuthState.authenticated();
      return;
    }

    if (response.needsCompany) {
      state = AuthState(
        step: AuthStep.companyPending,
        email: email,
        sessionToken: response.sessionToken,
        companies: response.companies,
        isLoading: false,
      );
      return;
    }

    if (response.needsOtp) {
      state = AuthState(
        step: AuthStep.otpPending,
        email: email,
        sessionToken: response.sessionToken,
        isLoading: false,
      );
      return;
    }

    state = state.copyWith(
      isLoading: false,
      error: 'Unexpected server response.',
    );
  }

  /// Full session teardown — safe for multi-company switching.
  ///
  /// Steps:
  ///   1. Pop all imperative Navigator.push() screens so their autoDispose
  ///      providers are disposed BEFORE GoRouter's redirect fires.
  ///   2. Disconnect XMPP WebSocket cleanly.
  ///   3. Wipe all tokens and cached data from secure storage.
  ///   4. Clear the in-memory GraphQL bearer token (also clears callbacks).
  ///   5. Invalidate every non-autoDispose provider that caches session data.
  ///   6. Reset unread counters.
  ///   7. Flip auth state → unauthenticated → GoRouter redirects to /login.
  Future<void> logout() async {
    // 1. Pop all imperative Navigator.push() routes back to GoRouter's root.
    try {
      _ref
          .read(appNavigatorKeyProvider)
          .currentState
          ?.popUntil((route) => route.isFirst);
    } catch (_) {}

    // 2. Disconnect XMPP before clearing tokens.
    XmppService.instance.disconnect();

    // 3. Persist layer — clears all tokens and device state.
    await SecureStorage.clearAll();

    // 4. Network layer — also nullifies onAuthError and onTokensRefreshed.
    GraphQLService.clearToken();

    // 5. Riverpod cache — invalidate all session-scoped providers.
    _ref.invalidate(meProvider);
    _ref.invalidate(usersMapProvider);
    _ref.invalidate(tasksNotifierProvider);
    _ref.invalidate(roomsProvider);
    _ref.invalidate(unreadInitProvider);
    try { _ref.invalidate(filesNotifierProvider); } catch (_) {}
    try { _ref.invalidate(uploadNotifierProvider); } catch (_) {}

    // 6. Reset unread counters and XMPP-driven previews so the next login starts clean.
    _ref.read(unreadCountsProvider.notifier).resetAll();
    try { _ref.read(roomPreviewNotifierProvider.notifier).clear(); } catch (_) {}

    // 7. Auth state → router guard fires → /login
    state = const AuthState.unauthenticated();
  }

  String _message(Object e) => e.toString().replaceFirst('Exception: ', '');
}
