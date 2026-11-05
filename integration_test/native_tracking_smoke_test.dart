import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:propcare_track/services/tracking/native_tracking_platform.dart';
import 'package:propcare_track/services/tracking/tracking_platform.dart';

/// Manual smoke test for the real Kotlin/Swift tracking bridge.
///
/// Run on a device or simulator with location permission already granted:
///
/// ```bash
/// flutter test integration_test/native_tracking_smoke_test.dart -d <device>
/// ```
///
/// It starts a short tracking session, waits for a location fix and status
/// event, checks the durable queue, then stops tracking. It deliberately does
/// not touch the app database.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('native tracking starts, streams, queues and stops', (tester) async {
    final platform = NativeTrackingPlatform();
    final events = <Map<String, dynamic>>[];
    final subscription = platform.events.listen(events.add);
    addTearDown(() async {
      await platform.stop();
      await subscription.cancel();
      await platform.dispose();
    });

    final started = await platform.start(
      TrackingConfig(
        sessionId: 'smoke-${DateTime.now().millisecondsSinceEpoch}',
        employeeId: 'EMP-1042',
        platform: platform.name,
        intervalMs: 2000,
      ),
    );
    expect(started, isTrue, reason: 'Native tracking should accept a valid config.');

    expect(await platform.isTracking(), isTrue);
    final status = await platform.status();
    expect(status['tracking'], isTrue);
    expect(status['queueSize'], isA<int>());

    // Give Core Location / LocationManager a few seconds to deliver a fix.
    for (var i = 0; i < 20 && events.isEmpty; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 500)));
      await tester.pump();
    }

    expect(
      events.where((event) => event['type'] == 'location').isNotEmpty ||
          events.where((event) => event['type'] == 'status').isNotEmpty,
      isTrue,
      reason: 'Expected at least one location or status event from the native bridge.',
    );

    final stopped = await platform.stop();
    expect(stopped, isTrue);
    expect(await platform.isTracking(), isFalse);
  });
}
