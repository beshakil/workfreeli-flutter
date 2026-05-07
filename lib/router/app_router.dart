import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/navigation/navigator_key.dart';
import '../features/auth/auth_providers.dart';
import '../features/auth/auth_state.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/otp_screen.dart';
import '../screens/company_select_screen.dart';
import '../screens/home_screen.dart';

final routerProvider = Provider<GoRouter>((ref) {
  // Shared navigator key — used by auth logout to pop imperative routes
  // before GoRouter's redirect fires (prevents stale screens/providers).
  final navigatorKey = ref.read(appNavigatorKeyProvider);
  final listenable = _AuthListenable(ref);
  ref.onDispose(listenable.dispose);

  return GoRouter(
    navigatorKey: navigatorKey,
    initialLocation: '/splash',
    refreshListenable: listenable,
    redirect: (BuildContext context, GoRouterState state) {
      final authState = ref.read(authNotifierProvider);
      final loc = state.matchedLocation;

      switch (authState.step) {
        case AuthStep.loading:
          return loc == '/splash' ? null : '/splash';
        case AuthStep.unauthenticated:
          return loc == '/login' ? null : '/login';
        case AuthStep.otpPending:
          return loc == '/otp' ? null : '/otp';
        case AuthStep.companyPending:
          return loc == '/company' ? null : '/company';
        case AuthStep.authenticated:
          if (loc == '/home') return null;
          if (loc == '/splash' || loc == '/login' || loc == '/otp' ||
              loc == '/company') {
            return '/home';
          }
          return null;
      }
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, __) => const SplashScreen()),
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(path: '/otp', builder: (_, __) => const OtpScreen()),
      GoRoute(
          path: '/company',
          builder: (_, __) => const CompanySelectScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
    ],
  );
});

class _AuthListenable extends ChangeNotifier {
  _AuthListenable(Ref ref) {
    _sub = ref.listen<AuthState>(authNotifierProvider, (_, __) {
      notifyListeners();
    });
  }

  late final ProviderSubscription<AuthState> _sub;

  @override
  void dispose() {
    _sub.close();
    super.dispose();
  }
}
