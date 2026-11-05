import '../../core/utils/geo.dart';

class OfficeConfig {
  const OfficeConfig({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  GeoPoint get point => GeoPoint(latitude, longitude);

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'radius_meters': radiusMeters,
      };

  factory OfficeConfig.fromMap(Map<String, Object?> map) => OfficeConfig(
        id: map['id'] as String,
        name: map['name'] as String,
        address: map['address'] as String,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        radiusMeters: (map['radius_meters'] as num).toDouble(),
      );
}

class Site {
  const Site({
    required this.id,
    required this.code,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
    this.isActive = true,
    this.sortOrder = 0,
  });

  final String id;
  final String code;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double radiusMeters;
  final bool isActive;
  final int sortOrder;

  GeoPoint get point => GeoPoint(latitude, longitude);

  double distanceFrom(GeoPoint? point) => point == null ? double.nan : distanceBetween(point, this.point);

  Map<String, Object?> toMap() => {
        'id': id,
        'code': code,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'radius_meters': radiusMeters,
        'is_active': isActive ? 1 : 0,
        'sort_order': sortOrder,
      };

  factory Site.fromMap(Map<String, Object?> map) => Site(
        id: map['id'] as String,
        code: (map['code'] as String?) ?? '',
        name: map['name'] as String,
        address: (map['address'] as String?) ?? '',
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        radiusMeters: (map['radius_meters'] as num?)?.toDouble() ?? 200,
        isActive: (map['is_active'] as int? ?? 1) == 1,
        sortOrder: (map['sort_order'] as int?) ?? 0,
      );
}
