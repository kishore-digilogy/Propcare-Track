import 'dart:async';

import '../../core/config/app_config.dart';

class TrackingConfig {
  const TrackingConfig({
    required this.sessionId,
    required this.employeeId,
    required this.platform,
    this.intervalMs = AppConfig.locationIntervalMs,
    this.distanceFilterMeters = AppConfig.distanceFilterMeters,
    this.stationaryRadiusMeters = AppConfig.stationaryRadiusMeters,
    this.stationarySeconds = 20,
  });

  final String sessionId;
  final String employeeId;
  final String platform;
  final int intervalMs;
  final double distanceFilterMeters;
  final double stationaryRadiusMeters;
  final int stationarySeconds;

  Map<String, Object?> toMap() => {
        'sessionId': sessionId,
        'employeeId': employeeId,
        'platform': platform,
        'intervalMs': intervalMs,
        'distanceFilterMeters': distanceFilterMeters,
        'stationaryRadiusMeters': stationaryRadiusMeters,
        'stationarySeconds': stationarySeconds,
      };
}

/// Contract implemented by the Kotlin foreground service bridge, the Swift
/// Core Location bridge and the desktop journey simulator.
abstract class TrackingPlatform {
  String get name;

  /// True when stationary events are produced natively (so Dart must not
  /// duplicate them).
  bool get supportsNativeStationary;

  Stream<Map<String, dynamic>> get events;

  Future<bool> start(TrackingConfig config);
  Future<bool> stop();
  Future<bool> isTracking();
  Future<Map<String, dynamic>> status();
  Future<List<Map<String, dynamic>>> drainQueue();
  Future<void> ackQueue(List<String> ids);
  Future<void> dispose();
}

class TrackingUnavailableException implements Exception {
  TrackingUnavailableException(this.message);
  final String message;
  @override
  String toString() => message;
}
