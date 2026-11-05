import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:propcare_track/app.dart';
import 'package:propcare_track/data/db/app_database.dart';
import 'package:propcare_track/services/app_controller.dart';
import 'package:propcare_track/services/tracking/simulated_tracking_platform.dart';

/// Renders the real app against an in-memory database and a deterministic
/// simulator. Every screen is exercised at phone size, so RenderFlex overflow
/// or a broken provider dependency fails the test.
void main() {
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('field day renders every screen without layout errors', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final database = AppDatabase.forTesting();
    final controller = AppController(
      database: database,
      platform: SimulatedTrackingPlatform(batteryProvider: () async => 87),
    );
    addTearDown(() async {
      await database.close();
    });

    await tester.runAsync(() async {
      await controller.bootstrap();
      await controller.markOnboardingSeen();
    });

    await tester.pumpWidget(
      ChangeNotifierProvider<AppController>.value(
        value: controller,
        child: const PropCareApp(),
      ),
    );
    await pumpFor(tester, const Duration(seconds: 3));

    expect(find.text('Sign in to the field'), findsOneWidget);

    await tester.tap(find.text('Sign in to the field'));
    await waitFor(tester, () => controller.employee != null && !controller.busy, label: 'login');
    expect(controller.employee?.code, 'EMP-1042');

    // Office check-in through the real UI.
    final officeEntry = find.text('Check in for the day');
    await tester.ensureVisible(officeEntry);
    await tester.tap(officeEntry);
    await pumpFor(tester, const Duration(milliseconds: 500));

    final officeCheckIn = find.text('Check in now');
    await tester.ensureVisible(officeCheckIn);
    await tester.tap(officeCheckIn);
    await waitFor(tester, () => controller.isCheckedIn && !controller.busy, label: 'office check-in');
    expect(controller.isTrackingLive, isTrue);

    // The office screen pops itself after a successful check-in. Sites → detail.
    await tester.tap(find.text('Sites'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    await tester.tap(find.text('Casagrand Suncity'));
    await pumpFor(tester, const Duration(milliseconds: 500));

    await tester.runAsync(() => controller.demoJumpToSite(controller.sites.first));
    await pumpFor(tester, const Duration(milliseconds: 400));

    final siteCheckIn = find.text('Start site visit');
    await tester.ensureVisible(siteCheckIn);
    await tester.tap(siteCheckIn);
    await waitFor(tester, () => controller.activeSiteVisit != null && !controller.busy, label: 'site check-in');
    expect(controller.activeSiteVisit?.siteName, 'Casagrand Suncity');

    // Hold-to-confirm site check-out. Tracking must stay live.
    final holdSite = find.text('Hold to check out of site');
    await tester.ensureVisible(holdSite);
    await holdFor(tester, holdSite);
    await waitFor(tester, () => controller.activeSiteVisit == null && !controller.busy, label: 'site check-out');
    expect(controller.isTrackingLive, isTrue);

    // Leave the site detail screen, then office check-out from Today.
    await popRoute(tester);
    await tester.tap(find.text('Today'));
    await pumpFor(tester, const Duration(milliseconds: 500));

    // The live map is now one tap from Today instead of a fifth tab.
    await tester.ensureVisible(find.text('Live map'));
    await tester.tap(find.text('Live map'));
    await pumpFor(tester, const Duration(milliseconds: 600));
    expect(find.text('Route, signal and battery'), findsOneWidget);
    await popRoute(tester);

    await tester.ensureVisible(find.text('Check out'));
    await tester.tap(find.text('Check out'));
    await pumpFor(tester, const Duration(milliseconds: 500));

    final holdOffice = find.text('Hold to check out');
    await tester.ensureVisible(holdOffice);
    await holdFor(tester, holdOffice);
    await waitFor(tester, () => !controller.isCheckedIn && !controller.busy, label: 'office check-out');
    expect(controller.isTrackingLive, isFalse);
    expect(controller.history, isNotEmpty);

    // The office screen pops itself after check-out. History → cinematic day story.
    await tester.tap(find.text('History'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    expect(find.text('COMPLETED'), findsWidgets);
    await tester.ensureVisible(find.text('COMPLETED').first);
    await tester.tap(find.text('COMPLETED').first);
    await waitFor(
      tester,
      () => find.textContaining('ROUTE').evaluate().isNotEmpty,
      label: 'day story',
    );
    await popRoute(tester);

    // Profile renders too.
    await tester.tap(find.text('Profile'));
    await pumpFor(tester, const Duration(milliseconds: 500));

    // Let the check-out snackbar expire so it cannot cover the logout button.
    await pumpFor(tester, const Duration(seconds: 5));

    // Logout through the confirmation sheet. Scroll to the very bottom so the
    // button is not hidden behind the floating navigation rail.
    await tester.ensureVisible(find.text('Log out of PropCare'));
    await tester.drag(find.byType(SingleChildScrollView).last, const Offset(0, -400));
    await pumpFor(tester, const Duration(milliseconds: 400));
    await tester.tap(find.text('Log out of PropCare'));
    await pumpFor(tester, const Duration(milliseconds: 500));
    final holdLogout = find.textContaining('Hold to log out');
    await holdFor(tester, holdLogout.first);
    await waitFor(tester, () => controller.employee == null && !controller.busy, label: 'logout');
    expect(find.text('Sign in to the field'), findsOneWidget);

    // Unmount and dispose before the test body returns: the binding asserts no
    // timers are pending and no debug overrides remain when the body ends.
    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
    await tester.runAsync(() => database.close());
    debugDefaultTargetPlatformOverride = null;
  });
}

/// Pump a fixed span of fake time without waiting for infinite ambient
/// animations to settle.
Future<void> pumpFor(WidgetTester tester, Duration duration) async {
  const step = Duration(milliseconds: 50);
  var elapsed = Duration.zero;
  while (elapsed < duration) {
    await tester.pump(step);
    elapsed += step;
  }
}

/// Give real asynchronous work (sqflite, shared preferences, battery) time to
/// finish while the condition is false. Widget tests run in a fake-async zone,
/// so real I/O only progresses inside [WidgetTester.runAsync].
Future<void> waitFor(
  WidgetTester tester,
  bool Function() condition, {
  Duration timeout = const Duration(seconds: 10),
  String? label,
}) async {
  final deadline = DateTime.now().add(timeout);
  while (!condition()) {
    if (DateTime.now().isAfter(deadline)) {
      fail('Timed out waiting for ${label ?? 'condition'}');
    }
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 25)));
    await tester.pump(const Duration(milliseconds: 25));
  }
  // Let route transitions, snackbars and pop animations finish.
  await pumpFor(tester, const Duration(milliseconds: 450));
}

Future<void> popRoute(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).pop();
  await pumpFor(tester, const Duration(milliseconds: 500));
}

Future<void> holdFor(WidgetTester tester, Finder finder) async {
  final gesture = await tester.startGesture(tester.getCenter(finder));
  // The first pump only establishes the ticker's start time.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 700));
  await gesture.up();
  await tester.pump();
}
