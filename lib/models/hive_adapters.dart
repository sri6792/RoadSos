// lib/models/hive_adapters.dart
//
// Manual Hive adapters — no build_runner / hive_generator needed.
// Type IDs:
//   0 → ServiceTypeAdapter
//   1 → CachedServiceAdapter

import 'package:hive/hive.dart';
import 'models.dart';

// ─── ServiceType adapter ──────────────────────────────────────────────────────

class ServiceTypeAdapter extends TypeAdapter<ServiceType> {
  @override
  final int typeId = 0;

  @override
  ServiceType read(BinaryReader reader) {
    final index = reader.readByte();
    return ServiceType.values[index.clamp(0, ServiceType.values.length - 1)];
  }

  @override
  void write(BinaryWriter writer, ServiceType obj) {
    writer.writeByte(obj.index);
  }
}

// ─── CachedService ────────────────────────────────────────────────────────────

class CachedService extends HiveObject {
  String id;
  String name;
  String address;
  double distance;
  String phone;
  double rating;
  bool isOpen;
  ServiceType type;
  double lat;
  double lng;
  DateTime cachedAt;

  CachedService({
    required this.id,
    required this.name,
    required this.address,
    required this.distance,
    required this.phone,
    required this.rating,
    required this.isOpen,
    required this.type,
    required this.lat,
    required this.lng,
    required this.cachedAt,
  });

  /// Convert a Google Places API result map → CachedService
  factory CachedService.fromPlacesResult(
      Map<String, dynamic> result, ServiceType type) {
    final loc = result['geometry']?['location'];
    // Use place_id or timestamp as fallback key — no Flutter dependency here
    final fallbackId = DateTime.now().millisecondsSinceEpoch.toString();
    return CachedService(
      id: (result['place_id'] as String?) ?? (result['id'] as String?) ?? fallbackId,
      name: (result['name'] as String?) ?? 'Unknown',
      address: (result['vicinity'] as String?) ??
          (result['formatted_address'] as String?) ??
          '',
      distance: 0.0,
      phone: (result['formatted_phone_number'] as String?) ?? '',
      rating: (result['rating'] as num?)?.toDouble() ?? 0.0,
      isOpen: (result['opening_hours']?['open_now'] as bool?) ?? true,
      type: type,
      lat: (loc?['lat'] as num?)?.toDouble() ?? 0.0,
      lng: (loc?['lng'] as num?)?.toDouble() ?? 0.0,
      cachedAt: DateTime.now(),
    );
  }

  /// Convert back to the app's NearbyService model
  NearbyService toNearbyService() {
    return NearbyService(
      id: id,
      name: name,
      address: address,
      distance: distance,
      phone: phone,
      rating: rating,
      isOpen: isOpen,
      type: type,
    );
  }

  /// Convert from NearbyService (for seeding with SampleData)
  factory CachedService.fromNearbyService(NearbyService s,
      {double lat = 0, double lng = 0}) {
    return CachedService(
      id: s.id,
      name: s.name,
      address: s.address,
      distance: s.distance,
      phone: s.phone,
      rating: s.rating,
      isOpen: s.isOpen,
      type: s.type,
      lat: lat,
      lng: lng,
      cachedAt: DateTime.now(),
    );
  }
}

class CachedServiceAdapter extends TypeAdapter<CachedService> {
  @override
  final int typeId = 1;

  @override
  CachedService read(BinaryReader reader) {
    return CachedService(
      id: reader.readString(),
      name: reader.readString(),
      address: reader.readString(),
      distance: reader.readDouble(),
      phone: reader.readString(),
      rating: reader.readDouble(),
      isOpen: reader.readBool(),
      type: ServiceType.values[
      reader.readByte().clamp(0, ServiceType.values.length - 1)],
      lat: reader.readDouble(),
      lng: reader.readDouble(),
      cachedAt: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
    );
  }

  @override
  void write(BinaryWriter writer, CachedService obj) {
    writer.writeString(obj.id);
    writer.writeString(obj.name);
    writer.writeString(obj.address);
    writer.writeDouble(obj.distance);
    writer.writeString(obj.phone);
    writer.writeDouble(obj.rating);
    writer.writeBool(obj.isOpen);
    writer.writeByte(obj.type.index);
    writer.writeDouble(obj.lat);
    writer.writeDouble(obj.lng);
    writer.writeInt(obj.cachedAt.millisecondsSinceEpoch);
  }
}