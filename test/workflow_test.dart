import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:propcare_track/data/db/app_database.dart';
import 'package:propcare_track/services/app_controller.dart';
import 'package:propcare_track/services/tracking/simulated_tracking_platform.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('office check-in starts a session', () async {
    final database = AppDatabase.forTesting();
    final controller = AppController(
      database: database,
      platform: SimulatedTrackingPlatform(batteryProvider: () async => 87),
    );
    addTearDown(() async {
      controller.dispose();
      await database.close();
    });

    await controller.bootstrap();
    await controller.login('EMP-1042', 'track@123');
    expect(controller.employee, isNotNull);
    await controller.officeCheckIn();
    expect(controller.isCheckedIn, isTrue);
    expect(controller.isTrackingLive, isTrue);
  });

  test('check-in works away from the office and sites', () async {
    final database = AppDatabase.forTesting();
    final controller = AppController(
      database: database,
      platform: SimulatedTrackingPlatform(batteryProvider: () async => 87),
    );
    addTearDown(() async {
      controller.dispose();
      await database.close();
    });

    await controller.bootstrap();
    await controller.login('EMP-1042', 'track@123');

    // Sit at a site that is well outside the office geofence.
    final office = controller.office!;
    final site = controller.sites.first;
    await controller.demoJumpToSite(site);
    expect(controller.distanceToOffice!, greaterThan(office.radiusMeters));

    await controller.officeCheckIn();
    expect(controller.isCheckedIn, isTrue);
    expect(controller.isTrackingLive, isTrue);
    expect(controller.attendance?.checkInLatitude, site.latitude);

    // Jump inside the site geofence to check in to that site.
    final other = controller.sites[1];
    await controller.demoJumpToSite(other);
    expect(controller.distanceToSite(other)!, lessThanOrEqualTo(other.radiusMeters));
    await controller.siteCheckIn(other);
    expect(controller.activeSiteVisit?.siteId, other.id);
  });
}
