import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Driver used by `integration_test/screenshot_test.dart`.
///
/// ```bash
/// flutter drive \
///   --driver=test_driver/integration_test.dart \
///   --target=integration_test/screenshot_test.dart \
///   -d <android-device> --no-enable-impeller
/// ```
Future<void> main() async {
  await integrationDriver(
    onScreenshot: (String name, List<int> bytes, [Map<String, Object?>? args]) async {
      final file = File('screenshots/$name.png');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);
      // ignore: avoid_print
      print('Saved ${file.path} (${bytes.length} bytes)');
      return true;
    },
  );
}
