import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Single shared NavigatorKey so GoRouter and AuthNotifier share the same
// Navigator stack. Auth logout calls popUntil(isFirst) to clear any
// Navigator.push() screens (MessageScreen, TaskDetailScreen) before
// GoRouter's redirect fires — preventing stale providers from staying alive.
final appNavigatorKeyProvider = Provider<GlobalKey<NavigatorState>>(
  (ref) => GlobalKey<NavigatorState>(),
);
