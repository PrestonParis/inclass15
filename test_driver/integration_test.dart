import 'dart:io';

import 'package:integration_test/integration_test_driver_extended.dart';

/// Saves screenshots taken by the integration test into evidence/.
Future<void> main() => integrationDriver(
  onScreenshot: (name, bytes, [args]) async {
    await File('evidence/$name.png').writeAsBytes(bytes);
    return true;
  },
);
