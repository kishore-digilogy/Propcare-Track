import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';

import 'package:propcare_track/main.dart' as app;
import 'package:propcare_track/services/app_controller.dart';
import 'package:propcare_track/ui/screens/home_shell.dart';

/// End-to-end field day on the desktop simulator.
///
/// Run with:
///   flutter test integration_test/app_test.dart -d macos
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

  testWidgets('onboarding → login → office → site → checkout → logout', (tester) async {
    await app.main();
    await wait(tester, const Duration(seconds: 4));

    // Onboarding (skipped when a previous run already marked it seen).
    if (find.text('Get started').evaluate().isNotEmpty) {
      await tester.tap(find.text('Get started'));
      await wait(tester, const Duration(seconds: 1));
    }

    if (find.text('Sign in to the field').evaluate().isEmpty) {
      final texts = find
          .byType(Text)
          .evaluate()
          .map((element) => (element.widget as Text).data)
          .whereType<String>()
          .toList();
      fail('Expected the login screen. Visible text: $texts');
    }

    // Login (demo credentials are prefilled)
    await tester.tap(find.text('Sign in to the field'));
    await wait(tester, const Duration(seconds: 2));

    final controller = Provider.of<AppController>(
      tester.element(find.byType(HomeShell)),
      listen: false,
    );
    expect(controller.employee?.code, 'EMP-1042');
    expect(controller.isCheckedIn, isFalse);

    // Office check-in
    final checkIn = find.text('Check in for the day');
    await tester.ensureVisible(checkIn);
    await tester.tap(checkIn);
    await wait(tester, const Duration(seconds: 1));

    final officeButton = find.text('Check in now');
    await tester.ensureVisible(officeButton);
    await tester.tap(officeButton);
    await wait(tester, const Duration(seconds: 2));

    expect(controller.isCheckedIn, isTrue);
    expect(controller.isTrackingLive, isTrue);

    // The simulator dwells at the office for 26 s. Let the native-style
    // 20-second stationary rule fire.
    await wait(tester, const Duration(seconds: 23));
    expect(controller.todayStationary, isNotEmpty);
    expect(controller.stationaryTodayCount, greaterThan(0));

    // Back to the tab shell
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await wait(tester, const Duration(seconds: 1));

    // Site check-in
    await tester.tap(find.text('Sites'));
    await wait(tester, const Duration(milliseconds: 700));
    await tester.tap(find.text('Casagrand Suncity'));
    await wait(tester, const Duration(milliseconds: 700));

    await tester.ensureVisible(find.text('Jump to site'));
    await tester.tap(find.text('Jump to site'));
    await wait(tester, const Duration(milliseconds: 800));

    final siteCheckIn = find.text('Start site visit');
    await tester.ensureVisible(siteCheckIn);
    await tester.tap(siteCheckIn);
    await wait(tester, const Duration(seconds: 2));

    expect(controller.activeSiteVisit?.siteName, 'Casagrand Suncity');

    // Hold to check out of the site; tracking must remain live.
    final holdSite = find.text('Hold to check out of site');
    await tester.ensureVisible(holdSite);
    await hold(tester, holdSite);
    await wait(tester, const Duration(seconds: 2));

    expect(controller.activeSiteVisit, isNull);
    expect(controller.isTrackingLive, isTrue);

    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await wait(tester, const Duration(seconds: 1));

    // Office check-out
    await tester.tap(find.text('Today'));
    await wait(tester, const Duration(milliseconds: 700));
    await tester.ensureVisible(find.text('Check out'));
    await tester.tap(find.text('Check out'));
    await wait(tester, const Duration(seconds: 1));

    final holdOffice = find.text('Hold to check out');
    await tester.ensureVisible(holdOffice);
    await hold(tester, holdOffice);
    await wait(tester, const Duration(seconds: 2));

    expect(controller.isCheckedIn, isFalse);
    expect(controller.isTrackingLive, isFalse);
    expect(controller.history, isNotEmpty);

    // History → cinematic day story
    await tester.tap(find.byIcon(Icons.arrow_back_rounded));
    await wait(tester, const Duration(seconds: 1));
    await tester.tap(find.text('History'));
    await wait(tester, const Duration(milliseconds: 800));

    final dayCard = find.text('COMPLETED');
    if (dayCard.evaluate().isNotEmpty) {
      await tester.tap(dayCard.first);
      await wait(tester, const Duration(seconds: 1));
      expect(find.textContaining('ROUTE'), findsWidgets);
      await tester.tap(find.byIcon(Icons.arrow_back_rounded));
      await wait(tester, const Duration(seconds: 1));
    }

    // Profile → logout
    await tester.tap(find.text('Profile'));
    await wait(tester, const Duration(milliseconds: 800));
    await tester.ensureVisible(find.text('Log out of PropCare'));
    await tester.tap(find.text('Log out of PropCare'));
    await wait(tester, const Duration(seconds: 1));

    final holdLogout = find.textContaining('Hold to log out');
    await hold(tester, holdLogout.first);
    await wait(tester, const Duration(seconds: 2));

    expect(controller.employee, isNull);
    expect(find.text('Sign in to the field'), findsOneWidget);
  });
}

Future<void> wait(WidgetTester tester, Duration duration) async {
  await Future<void>.delayed(duration);
  await tester.pumpAndSettle(const Duration(milliseconds: 120));
}

Future<void> hold(WidgetTester tester, Finder finder) async {
  final center = tester.getCenter(finder);
  final gesture = await tester.startGesture(center);
  await Future<void>.delayed(const Duration(milliseconds: 1700));
  await gesture.up();
  await tester.pumpAndSettle();
}
