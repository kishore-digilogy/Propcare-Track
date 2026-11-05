import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'package:propcare_track/main.dart' as app;
import 'package:propcare_track/services/app_controller.dart';
import 'package:propcare_track/ui/screens/home_shell.dart';

/// Drives the real app on Android and captures screenshots of every key
/// surface. Requires location permission and a location fix (the emulator's
/// `adb emu geo fix 80.2588 12.9763` is enough).
///
/// Run with the driver in `test_driver/integration_test.dart`:
///   flutter drive --driver=test_driver/integration_test.dart \
///     --target=integration_test/screenshot_test.dart \
///     -d emulator-5554 --no-enable-impeller
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    final directory = await getDatabasesPath();
    for (final suffix in ['', '-wal', '-shm']) {
      final file = File(p.join(directory, 'propcare_track.db$suffix'));
      if (file.existsSync()) file.deleteSync();
    }
  });

  tearDownAll(() async {
    // Never leave a foreground service running after the capture session.
    await const MethodChannel('propcare/tracking').invokeMethod<void>('stopTracking');
  });

  testWidgets('capture the Paper Atlas screens', (tester) async {
    await app.main();
    await pause(tester, 1200);
    await until(
      tester,
      () =>
          find.text('Get started').evaluate().isNotEmpty ||
          find.text('Sign in to the field').evaluate().isNotEmpty,
      timeoutMs: 30000,
    );

    // Android only: switch the engine surface into an image we can capture.
    await IntegrationTestWidgetsFlutterBinding.instance.convertFlutterSurfaceToImage();
    await pause(tester, 600);

    if (find.text('Get started').evaluate().isNotEmpty) {
      await shot(tester, '01_onboarding');
      await tester.tap(find.text('Get started'));
      await pause(tester, 1400);
    }

    expect(find.text('Sign in to the field'), findsOneWidget);
    await shot(tester, '03_login');

    await tester.tap(find.text('Sign in to the field'));
    await pause(tester, 2200);
    expect(find.byType(HomeShell), findsOneWidget);

    final controller = Provider.of<AppController>(
      tester.element(find.byType(HomeShell)),
      listen: false,
    );
    expect(controller.employee?.code, 'EMP-1042');

    await shot(tester, '04_today_ready');

    // Office check-in screen.
    await tester.ensureVisible(find.text('Check in for the day'));
    await tester.tap(find.text('Check in for the day'));
    await pause(tester, 900);
    await shot(tester, '05_office_attendance');

    await tester.ensureVisible(find.text('Check in now'));
    await tester.tap(find.text('Check in now'));
    await until(tester, () => controller.isCheckedIn, timeoutMs: 25000);
    expect(controller.isCheckedIn, isTrue);
    expect(controller.isTrackingLive, isTrue);
    await pause(tester, 1200);
    await shot(tester, '06_today_tracking_live');

    // Live map, opened from Today.
    await tester.ensureVisible(find.text('Live map'));
    await tester.tap(find.text('Live map'));
    await pause(tester, 1000);
    expect(find.text('Route, signal and battery'), findsOneWidget);
    await shot(tester, '07_live_tracking');
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await pause(tester, 700);

    // Sites + site detail.
    await tester.tap(find.text('Sites'));
    await pause(tester, 900);
    await shot(tester, '08_assigned_sites');

    await tester.tap(find.text('Casagrand Suncity'));
    await pause(tester, 900);
    await shot(tester, '09_site_detail');
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await pause(tester, 700);

    // History + profile.
    await tester.tap(find.text('History'));
    await pause(tester, 900);
    await shot(tester, '10_history');

    await tester.tap(find.text('Profile'));
    await pause(tester, 900);
    await shot(tester, '11_profile');

    // Office check-out → completed history → cinematic day story.
    await tester.tap(find.text('Today'));
    await pause(tester, 800);
    await tester.ensureVisible(find.text('Check out'));
    await tester.tap(find.text('Check out'));
    await pause(tester, 900);
    await shot(tester, '12_checkout_confirm');

    final holdOffice = find.text('Hold to check out');
    await tester.ensureVisible(holdOffice);
    await hold(tester, holdOffice);
    await until(tester, () => !controller.isCheckedIn, timeoutMs: 15000);
    expect(controller.isCheckedIn, isFalse);
    expect(controller.isTrackingLive, isFalse);
    await pause(tester, 1600);

    await tester.tap(find.text('History'));
    await pause(tester, 900);
    await shot(tester, '13_history_completed');

    final completed = find.text('COMPLETED');
    if (completed.evaluate().isNotEmpty) {
      await tester.tap(completed.first);
      await pause(tester, 1400);
      await shot(tester, '14_day_story');
    }
  });
}

Future<void> hold(WidgetTester tester, Finder finder) async {
  final gesture = await tester.startGesture(tester.getCenter(finder));
  // Establish the ticker start, then advance past the 1300 ms hold threshold.
  await tester.pump();
  for (var i = 0; i < 3; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 150));
    await tester.pump(const Duration(milliseconds: 700));
  }
  await gesture.up();
  await tester.pump(const Duration(milliseconds: 120));
}

Future<void> pause(WidgetTester tester, int milliseconds) async {
  await Future<void>.delayed(Duration(milliseconds: milliseconds));
  await tester.pump(const Duration(milliseconds: 80));
}

Future<void> until(
  WidgetTester tester,
  bool Function() predicate, {
  int timeoutMs = 15000,
}) async {
  final watch = Stopwatch()..start();
  while (!predicate() && watch.elapsedMilliseconds < timeoutMs) {
    await Future<void>.delayed(const Duration(milliseconds: 250));
    await tester.pump(const Duration(milliseconds: 40));
  }
}

Future<void> shot(WidgetTester tester, String name) async {
  await tester.pump(const Duration(milliseconds: 250));
  await IntegrationTestWidgetsFlutterBinding.instance.takeScreenshot(name);
}
