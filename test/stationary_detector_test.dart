import 'package:flutter_test/flutter_test.dart';
import 'package:propcare_track/core/utils/geo.dart';
import 'package:propcare_track/data/models/tracking.dart';
import 'package:propcare_track/services/stationary_detector.dart';

LocationRecord _record(DateTime at, {double latitude = 12.9763, double accuracy = 8}) {
  return LocationRecord(
    id: 'loc-${at.millisecondsSinceEpoch}',
    employeeId: 'emp-1042',
    sessionId: 'session-1',
    latitude: latitude,
    longitude: 80.2588,
    accuracy: accuracy,
    battery: 80,
    platform: 'test',
    movementStatus: MovementStatus.stationary,
    recordedAt: at,
  );
}

void main() {
  group('StationaryDetector', () {
    test('starts an event after the threshold while inside the radius', () {
      final start = DateTime(2026, 1, 1, 9);
      final detector = StationaryDetector(
        employeeId: 'emp-1042',
        sessionId: 'session-1',
        threshold: const Duration(seconds: 20),
      );

      expect(detector.feed(_record(start)).started, isNull);
      expect(
        detector.feed(_record(start.add(const Duration(seconds: 10)))).started,
        isNull,
      );
      final update = detector.feed(_record(start.add(const Duration(seconds: 21))));
      expect(update.started, isNotNull);
      expect(detector.active, isNotNull);
    });

    test('ignores poor accuracy fixes', () {
      final start = DateTime(2026, 1, 1, 9);
      final detector = StationaryDetector(
        employeeId: 'emp-1042',
        sessionId: 'session-1',
        threshold: const Duration(seconds: 20),
      );

      detector.feed(_record(start));
      detector.feed(_record(start.add(const Duration(seconds: 10)), accuracy: 200));
      final update = detector.feed(_record(start.add(const Duration(seconds: 25)), accuracy: 200));
      expect(update.started, isNull);
    });

    test('completes an active event after moving beyond the break radius', () {
      final start = DateTime(2026, 1, 1, 9);
      final detector = StationaryDetector(
        employeeId: 'emp-1042',
        sessionId: 'session-1',
        threshold: const Duration(seconds: 20),
      );

      detector.feed(_record(start));
      detector.feed(_record(start.add(const Duration(seconds: 21))));
      expect(detector.active, isNotNull);

      final moved = offsetPoint(
        const GeoPoint(12.9763, 80.2588),
        120,
        90,
      );
      final update = detector.feed(
        LocationRecord(
          id: 'moved',
          employeeId: 'emp-1042',
          sessionId: 'session-1',
          latitude: moved.latitude,
          longitude: moved.longitude,
          accuracy: 8,
          battery: 79,
          platform: 'test',
          movementStatus: MovementStatus.moving,
          recordedAt: start.add(const Duration(seconds: 40)),
        ),
      );

      expect(update.completed, isNotNull);
      expect(update.completed!.durationSeconds, greaterThanOrEqualTo(20));
      expect(detector.active, isNull);
    });
  });
}
