import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:propcare_track/app.dart';
import 'package:propcare_track/data/db/app_database.dart';
import 'package:propcare_track/services/app_controller.dart';
import 'package:propcare_track/services/tracking/simulated_tracking_platform.dart';

/// Renders the main surfaces at the smallest supported phone and at tablet
/// width. Any RenderFlex overflow or framework exception fails the test.
void main() {
  setUp(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  for (final size in const [Size(320, 568), Size(768, 1024)]) {
    testWidgets('renders at ${size.width.toInt()}x${size.height.toInt()}', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final database = AppDatabase.forTesting();
      final controller = AppController(
        database: database,
        platform: SimulatedTrackingPlatform(batteryProvider: () async => 87),
      );

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

      await tester.ensureVisible(find.text('Sign in to the field'));
      await tester.tap(find.text('Sign in to the field'));
      await waitFor(tester, () => controller.employee != null && !controller.busy, label: 'login');
      await pumpFor(tester, const Duration(milliseconds: 600));

      // Office check-in surface, then a real check-in through the UI.
      await tester.ensureVisible(find.text('Check in for the day'));
      await tester.tap(find.text('Check in for the day'));
      await pumpFor(tester, const Duration(milliseconds: 600));
      final officeButton = find.text('Check in now');
      expect(officeButton, findsOneWidget);
      await tester.ensureVisible(officeButton);
      await tester.tap(officeButton);
      await waitFor(tester, () => controller.isCheckedIn && !controller.busy, label: 'office check-in');

      // Every tab with a live session.
      for (final tab in const ['Sites', 'History', 'Profile', 'Today']) {
        await tester.tap(find.text(tab));
        await pumpFor(tester, const Duration(milliseconds: 500));
      }

      // Site detail.
      await tester.tap(find.text('Sites'));
      await pumpFor(tester, const Duration(milliseconds: 500));
      await tester.ensureVisible(find.text('Casagrand Suncity'));
      await tester.tap(find.text('Casagrand Suncity'));
      await pumpFor(tester, const Duration(milliseconds: 600));
      expect(find.textContaining('Start site visit'), findsOneWidget);
      await popRoute(tester);

      // Close the day and render the cinematic story at this width.
      await tester.runAsync(() => controller.officeCheckOut());
      await waitFor(tester, () => !controller.isCheckedIn && !controller.busy, label: 'office check-out');
      await tester.tap(find.text('History'));
      await pumpFor(tester, const Duration(milliseconds: 700));
      expect(find.text('COMPLETED'), findsWidgets);
      await tester.ensureVisible(find.text('COMPLETED').first);
      await tester.tap(find.text('COMPLETED').first);
      await waitFor(
        tester,
        () => find.textContaining('ROUTE').evaluate().isNotEmpty,
        label: 'day story',
      );
      await popRoute(tester);

      await tester.pumpWidget(const SizedBox.shrink());
      controller.dispose();
      await tester.runAsync(() => database.close());
      debugDefaultTargetPlatformOverride = null;
    });
  }
}

Future<void> pumpFor(WidgetTester tester, Duration duration) async {
  const step = Duration(milliseconds: 50);
  var elapsed = Duration.zero;
  while (elapsed < duration) {
    await tester.pump(step);
    elapsed += step;
  }
}

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
  await pumpFor(tester, const Duration(milliseconds: 450));
}

Future<void> popRoute(WidgetTester tester) async {
  tester.state<NavigatorState>(find.byType(Navigator).first).pop();
  await pumpFor(tester, const Duration(milliseconds: 500));
}
