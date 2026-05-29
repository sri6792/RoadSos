// lib/services/responder_service.dart
// Handles Golden Hour first-responder logic:
// • Saves user as an available responder in Firestore
// • Listens for nearby SOS alerts (bounding-box ~500 m)
// • Lets the victim track who responded

import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'app_state.dart';

class ResponderService {
  ResponderService._();
  static final ResponderService instance = ResponderService._();

  final _db = FirebaseFirestore.instance;

  StreamSubscription<QuerySnapshot>? _alertSub;
  StreamSubscription<DocumentSnapshot>? _responseSub;

  // Callback fired on the victim's side when a responder accepts
  void Function(String responderName, double etaMinutes)? onResponderFound;

  // Callback fired on the responder's side when a nearby SOS arrives
  void Function(Map<String, dynamic> alertData)? onNearbySOSAlert;

  // ── Responder: save availability to Firestore ────────────────────────────

  Future<void> registerAsResponder({
    required double lat,
    required double lng,
    required String name,
    required bool available,
  }) async {
    final uid = AppState.instance.userId.isNotEmpty
        ? AppState.instance.userId
        : 'user_${DateTime.now().millisecondsSinceEpoch}';
    AppState.instance.userId = uid;

    try {
      await _db.collection('responders').doc(uid).set({
        'userId': uid,
        'name': name.isNotEmpty ? name : 'Anonymous Helper',
        'lat': lat,
        'lng': lng,
        'isAvailable': available,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Responder register error (offline?): $e');
    }
  }

  // ── Responder: listen for SOS alerts within ~500 m ───────────────────────
  // Uses a simple lat/lng bounding box (±0.0045° ≈ 500 m).

  void startListeningForAlerts({
    required double lat,
    required double lng,
  }) {
    stopListeningForAlerts();

    const delta = 0.0045; // ~500 m

    // KEY FIX: only listen for alerts created AFTER the responder turned on.
    // This prevents old waiting alerts from firing immediately on toggle.
    final listenStartTime = Timestamp.now();

    _alertSub = _db
        .collection('responder_requests')
        .where('status', isEqualTo: 'waiting')
        .where('lat', isGreaterThan: lat - delta)
        .where('lat', isLessThan: lat + delta)
        .where('createdAt', isGreaterThan: listenStartTime)
        .snapshots()
        .listen((snap) {
      for (final change in snap.docChanges) {
        // Only react to truly NEW documents, not existing ones on first load
        if (change.type == DocumentChangeType.added) {
          final data = change.doc.data()!;

          // Extra lng check — Firestore only allows one range filter per query
          final alertLng = (data['lng'] as num?)?.toDouble() ?? 0;
          if ((alertLng - lng).abs() > delta) continue;

          // Skip if already being responded to
          final status = data['status'] as String? ?? '';
          if (status != 'waiting') continue;

          onNearbySOSAlert?.call({...data, 'docId': change.doc.id});
        }
      }
    }, onError: (e) => debugPrint('Alert listener error: $e'));
  }

  void stopListeningForAlerts() {
    _alertSub?.cancel();
    _alertSub = null;
  }

  // ── Victim: broadcast SOS + listen for a responder accepting ────────────

  Future<String?> broadcastSOS({
    required double lat,
    required double lng,
    required String address,
    required String victimName,
    required String bloodGroup,
  }) async {
    try {
      final doc = await _db.collection('responder_requests').add({
        'victimName': victimName.isNotEmpty ? victimName : 'Unknown',
        'bloodGroup': bloodGroup,
        'lat': lat,
        'lng': lng,
        'address': address,
        'status': 'waiting',    // waiting → responding → resolved
        'responderName': '',
        'responderLat': null,
        'responderLng': null,
        'createdAt': FieldValue.serverTimestamp(),
        // TTL marker — Cloud Function or next open can auto-resolve after 10 min
        'expiresAfterMinutes': 10,
      });
      return doc.id;
    } catch (e) {
      debugPrint('SOS broadcast error (offline?): $e');
      return null;
    }
  }

  void listenForResponder(String docId) {
    _responseSub?.cancel();
    _responseSub = _db
        .collection('responder_requests')
        .doc(docId)
        .snapshots()
        .listen((snap) {
      if (!snap.exists) return;
      final data = snap.data()!;
      if (data['status'] == 'responding') {
        final name = data['responderName'] as String? ?? 'A volunteer';
        final rLat = (data['responderLat'] as num?)?.toDouble();
        final rLng = (data['responderLng'] as num?)?.toDouble();
        double eta = 2.0;
        if (rLat != null && rLng != null) {
          eta = _estimateEtaMinutes(
            rLat, rLng,
            (data['lat'] as num).toDouble(),
            (data['lng'] as num).toDouble(),
          );
        }
        onResponderFound?.call(name, eta);
      }
    }, onError: (e) => debugPrint('Responder listener error: $e'));
  }

  // ── Responder: accept an SOS ────────────────────────────────────────────

  Future<void> acceptSOS({
    required String docId,
    required double myLat,
    required double myLng,
    required String myName,
  }) async {
    try {
      await _db.collection('responder_requests').doc(docId).update({
        'status': 'responding',
        'responderName': myName.isNotEmpty ? myName : 'A volunteer',
        'responderLat': myLat,
        'responderLng': myLng,
        'respondedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Accept SOS error: $e');
    }
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  /// Rough walking/driving ETA in minutes using Haversine distance ÷ 30 km/h
  double _estimateEtaMinutes(double lat1, double lng1, double lat2, double lng2) {
    const r = 6371.0; // earth radius km
    final dLat = _rad(lat2 - lat1);
    final dLng = _rad(lng2 - lng1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_rad(lat1)) * cos(_rad(lat2)) * sin(dLng / 2) * sin(dLng / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    final distKm = r * c;
    // Assume ~30 km/h average speed on city roads
    return (distKm / 30.0 * 60).clamp(1.0, 30.0);
  }

  double _rad(double deg) => deg * pi / 180;

  void dispose() {
    stopListeningForAlerts();
    _responseSub?.cancel();
  }
}