import 'package:flutter_test/flutter_test.dart';
import 'package:propcare_track/core/config/app_config.dart';
import 'package:propcare_track/core/utils/geo.dart';

void main() {
  group('geo utilities', () {
    test('distance between identical points is zero', () {
      const point = GeoPoint(12.9763, 80.2588);
      expect(distanceBetween(point, point), closeTo(0, 0.001));
    });

    test('offsetPoint round-trips through distanceBetween', () {
      final origin = AppConfig.office.point;
      final moved = offsetPoint(origin, 120, 45);
      expect(distanceBetween(origin, moved), closeTo(120, 1));
    });

    test('bearingBetween points east for a positive longitude delta', () {
      const a = GeoPoint(12.9, 80.1);
      const b = GeoPoint(12.9, 80.2);
      expect(bearingBetween(a, b), closeTo(90, 1));
    });

    test('geofence widens by accuracy but caps at 50 m', () {
      expect(
        withinGeofence(distanceMeters: 205, radiusMeters: 200, accuracyMeters: 10),
        isTrue,
      );
      expect(
        withinGeofence(distanceMeters: 260, radiusMeters: 200, accuracyMeters: 10),
        isFalse,
      );
      expect(
        withinGeofence(distanceMeters: 250, radiusMeters: 200, accuracyMeters: 500),
        isTrue,
      );
      expect(
        withinGeofence(distanceMeters: 260, radiusMeters: 200, accuracyMeters: 500),
        isFalse,
      );
    });

    test('interpolate clamps outside the 0..1 range', () {
      const a = GeoPoint(0, 0);
      const b = GeoPoint(10, 10);
      expect(interpolate(a, b, -1), a);
      expect(interpolate(a, b, 2), b);
      expect(interpolate(a, b, 0.5).latitude, 5);
    });
  });
}
