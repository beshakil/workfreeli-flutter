import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'router/app_router.dart';
import 'services/call_notification_service.dart';
import 'services/fcm_service.dart';
import 'theme/app_theme.dart';

// ── Background FCM handler ────────────────────────────────────────────────────

/// Fires in a separate Dart isolate when the app is in the background or
/// terminated. Must be a top-level function.
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  // Re-init local notifications in this isolate so we can show the
  // full-screen call notification even when the main isolate isn't running.
  await CallNotificationService.init();
  await CallNotificationService.handleBackgroundFcmMessage(message);
}

// ── App entry point ───────────────────────────────────────────────────────────

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase must be initialised before any Firebase API calls.
  await Firebase.initializeApp();

  // Register the background message handler before the app widget tree runs.
  FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

  // Initialise local notifications + create the call notification channel.
  // Also detects if this launch was triggered by tapping a local notification.
  await CallNotificationService.init();

  // Start listening for foreground FCM messages (no-op until user is logged in;
  // the stream simply has no consumers yet).
  FcmService.startForegroundListener();

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: AppTheme.bgCard,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  runApp(const ProviderScope(child: FreeliApp()));
}

class FreeliApp extends ConsumerWidget {
  const FreeliApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Workfreeli',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routerConfig: router,
    );
  }
}
