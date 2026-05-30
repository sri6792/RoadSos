// lib/services/cache_service.dart
//
// Saves Google Places API results to Hive so the app works offline.
// Call saveFromPlacesResults() after a successful API fetch.
// Call getServices() anywhere — returns cached data when offline.

import 'package:hive_flutter/hive_flutter.dart';
import '../models/hive_adapters.dart';
import '../models/models.dart';

class CacheService {
  static const _boxName = 'nearby_services';
  static const _metaBoxName = 'cache_meta';
  static const _cacheValidHours = 24;

  static final CacheService instance = CacheService._();
  CacheService._();

  Box<CachedService>? _box;
  Box<dynamic>? _metaBox;

  // ── Init ───────────────────────────────────────────────────────────────────

  Future<void> init() async {
    _box = await Hive.openBox<CachedService>(_boxName);
    _metaBox = await Hive.openBox(_metaBoxName);
  }

  // ── Save ───────────────────────────────────────────────────────────────────

  Future<void> saveFromPlacesResults(
      List<dynamic> results,
      ServiceType type,
      ) async {
    final box = _box;
    if (box == null) return;

    // Remove stale entries of this type
    final keysToDelete = box.keys.where((k) {
      final item = box.get(k);
      return item != null && item.type == type;
    }).toList();
    await box.deleteAll(keysToDelete);

    // Write new entries
    for (final result in results) {
      final service = CachedService.fromPlacesResult(
        Map<String, dynamic>.from(result as Map),
        type,
      );
      await box.put(service.id, service);
    }

    _metaBox?.put(
      'last_updated_${type.name}',
      DateTime.now().toIso8601String(),
    );
  }

  Future<void> saveNearbyServices(List<NearbyService> services) async {
    final box = _box;
    if (box == null) return;
    for (final s in services) {
      await box.put(s.id, CachedService.fromNearbyService(s));
    }
  }

  // ── Read ───────────────────────────────────────────────────────────────────

  List<CachedService> getServices(ServiceType type) {
    final box = _box;
    if (box == null) return [];
    // box.values returns Iterable<CachedService> — always non-null elements
    return box.values.where((s) => s.type == type).toList();
  }

  List<NearbyService> getNearbyServices(ServiceType type) {
    return getServices(type).map((s) => s.toNearbyService()).toList();
  }

  // ── Metadata ───────────────────────────────────────────────────────────────

  DateTime? lastUpdated(ServiceType type) {
    final raw = _metaBox?.get('last_updated_${type.name}') as String?;
    if (raw == null) return null;
    return DateTime.tryParse(raw);
  }

  bool isFresh(ServiceType type) {
    final updated = lastUpdated(type);
    if (updated == null) return false;
    return DateTime.now().difference(updated).inHours < _cacheValidHours;
  }

  String lastUpdatedLabel(ServiceType type) {
    final updated = lastUpdated(type);
    if (updated == null) return 'Never cached';
    final diff = DateTime.now().difference(updated);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  bool hasCache(ServiceType type) => getServices(type).isNotEmpty;

  // ── Clear ──────────────────────────────────────────────────────────────────

  Future<void> clearAll() async {
    await _box?.clear();
    await _metaBox?.clear();
  }
}