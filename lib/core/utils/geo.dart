import 'dart:math' as math;

/// Minimal immutable coordinate type so the domain layer does not depend on a
/// particular location plugin.
class GeoPoint {
  const GeoPoint(this.latitude, this.longitude);

  final double latitude;
  final double longitude;

  @override
  String toString() => '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}';

  @override
  bool operator ==(Object other) =>
      other is GeoPoint && other.latitude == latitude && other.longitude == longitude;

  @override
  int get hashCode => Object.hash(latitude, longitude);
}

const double earthRadiusMeters = 6371000;

/// Great-circle distance in metres.
double distanceBetween(GeoPoint a, GeoPoint b) {
  final lat1 = _rad(a.latitude);
  final lat2 = _rad(b.latitude);
  final dLat = lat2 - lat1;
  final dLng = _rad(b.longitude) - _rad(a.longitude);
  final h = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.cos(lat1) * math.cos(lat2) * math.sin(dLng / 2) * math.sin(dLng / 2);
  return 2 * earthRadiusMeters * math.asin(math.min(1, math.sqrt(h)));
}

/// Initial bearing in degrees (0 = north) from [a] to [b].
double bearingBetween(GeoPoint a, GeoPoint b) {
  final lat1 = _rad(a.latitude);
  final lat2 = _rad(b.latitude);
  final dLng = _rad(b.longitude - a.longitude);
  final y = math.sin(dLng) * math.cos(lat2);
  final x = math.cos(lat1) * math.sin(lat2) - math.sin(lat1) * math.cos(lat2) * math.cos(dLng);
  return (_deg(math.atan2(y, x)) + 360) % 360;
}

/// Point [distanceMeters] away from [origin] along [bearingDegrees].
GeoPoint offsetPoint(GeoPoint origin, double distanceMeters, double bearingDegrees) {
  final angular = distanceMeters / earthRadiusMeters;
  final bearing = _rad(bearingDegrees);
  final lat1 = _rad(origin.latitude);
  final lng1 = _rad(origin.longitude);
  final lat2 = math.asin(math.sin(lat1) * math.cos(angular) +
      math.cos(lat1) * math.sin(angular) * math.cos(bearing));
  final lng2 = lng1 +
      math.atan2(math.sin(bearing) * math.sin(angular) * math.cos(lat1),
          math.cos(angular) - math.sin(lat1) * math.sin(lat2));
  return GeoPoint(_deg(lat2), _deg(lng2));
}

/// Interpolate between two coordinates (linear in lat/lng is fine at city scale).
GeoPoint interpolate(GeoPoint a, GeoPoint b, double t) {
  final clamped = t.clamp(0.0, 1.0);
  return GeoPoint(
    a.latitude + (b.latitude - a.latitude) * clamped,
    a.longitude + (b.longitude - a.longitude) * clamped,
  );
}

double _rad(double degrees) => degrees * math.pi / 180;
double _deg(double radians) => radians * 180 / math.pi;

/// Geofence check that accounts for GPS accuracy.
///
/// We allow the reported accuracy to widen the fence (capped at 50 m) so a
/// fix that is "200 m ± 18 m" from a 200 m fence still validates, while a fix
/// 900 m away never will.
bool withinGeofence({
  required double distanceMeters,
  required double radiusMeters,
  required double accuracyMeters,
}) {
  final tolerance = accuracyMeters.isFinite ? accuracyMeters.clamp(0, 50).toDouble() : 0;
  return distanceMeters <= radiusMeters + tolerance;
}

/// 0.0 at the centre → 1.0 at the edge of the fence (clamped).
double geofenceProgress(double distanceMeters, double radiusMeters) {
  if (radiusMeters <= 0) return 1;
  return (distanceMeters / radiusMeters).clamp(0.0, 1.0);
}
