// lib/services/accident_detection_service.dart
//
// Listens to the accelerometer and detects sudden spikes that indicate
// a crash. When detected, calls the onCrashDetected callback so the UI
// can show the countdown alert.
//
// Tuning:
//   _threshold  → G-force spike needed to trigger (18.0 ≈ hard crash)
//   _cooldown   → minimum gap between two triggers (avoid double-fire)

import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:sensors_plus/sensors_plus.dart';

class AccidentDetectionService {
  // ── Singleton ──────────────────────────────────────────────────────────────
  static final AccidentDetectionService instance =
  AccidentDetectionService._();
  AccidentDetectionService._();

  // ── Config ─────────────────────────────────────────────────────────────────
  // Total acceleration magnitude threshold in m/s².
  // Normal driving ≈ 9.8 (gravity). Hard brake ≈ 14. Crash ≈ 18–30.
  static const double _threshold = 18.0;
  static const Duration _cooldown = Duration(seconds: 30);

  // ── State ──────────────────────────────────────────────────────────────────
  StreamSubscription<AccelerometerEvent>? _sub;
  DateTime? _lastTriggered;
  bool _isRunning = false;

  /// Called when a crash is detected. Set this before calling start().
  VoidCallback? onCrashDetected;

  // ── Public API ─────────────────────────────────────────────────────────────

  void start() {
    if (_isRunning) return;
    _isRunning = true;

    _sub = accelerometerEventStream(
      samplingPeriod: SensorInterval.normalInterval,
    ).listen(_onAccelerometer, onError: (_) {});
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
    _isRunning = false;
  }

  bool get isRunning => _isRunning;

  // ── Internal ───────────────────────────────────────────────────────────────

  void _onAccelerometer(AccelerometerEvent event) {
    // Total magnitude of acceleration vector
    final magnitude = sqrt(
      event.x * event.x + event.y * event.y + event.z * event.z,
    );

    if (magnitude >= _threshold) {
      final now = DateTime.now();

      // Respect cooldown to avoid double-firing
      if (_lastTriggered != null &&
          now.difference(_lastTriggered!) < _cooldown) {
        return;
      }

      _lastTriggered = now;
      debugPrint(
          'AccidentDetection: spike detected — magnitude ${magnitude.toStringAsFixed(1)} m/s²');
      onCrashDetected?.call();
    }
  }
}