// lib/services/connectivity_service.dart
//
// Wraps connectivity_plus into a simple ValueNotifier so any widget
// can listen to online/offline changes without Provider or BLoC.
//
// Usage anywhere in the widget tree:
//   ConnectivityService.instance.isOnline  → bool
//   ConnectivityService.instance.notifier  → ValueNotifier<bool>
//
// ValueListenableBuilder(
//   valueListenable: ConnectivityService.instance.notifier,
//   builder: (ctx, isOnline, _) => isOnline ? ... : OfflineBanner(),
// )

import 'dart:async';
import 'package:flutter/foundation.dart'; // ← ValueNotifier lives here
import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  static final ConnectivityService instance = ConnectivityService._();
  ConnectivityService._();

  final ValueNotifier<bool> notifier = ValueNotifier<bool>(true);
  StreamSubscription<List<ConnectivityResult>>? _sub;

  bool get isOnline => notifier.value;

  Future<void> init() async {
    // Check current state immediately
    final results = await Connectivity().checkConnectivity();
    notifier.value = _hasConnection(results);

    // Listen for changes
    _sub = Connectivity().onConnectivityChanged.listen((results) {
      notifier.value = _hasConnection(results);
    });
  }

  bool _hasConnection(List<ConnectivityResult> results) {
    return results.any((r) =>
    r == ConnectivityResult.mobile ||
        r == ConnectivityResult.wifi ||
        r == ConnectivityResult.ethernet);
  }

  void dispose() {
    _sub?.cancel();
    notifier.dispose();
  }
}