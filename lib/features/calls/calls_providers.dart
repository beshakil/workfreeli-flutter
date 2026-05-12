import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'call_models.dart';
import 'calls_service.dart';

export 'incoming_call_state.dart';

// Not autoDispose — cached for the session; invalidate explicitly after calls end.
final callHistoryProvider = FutureProvider<List<CallHistoryEntry>>(
  (_) => CallsService.getCallHistory(),
);
