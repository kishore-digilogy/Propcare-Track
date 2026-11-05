import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/config/app_config.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/geo.dart';
import 'tracking/demo_location.dart';

class LocationFix {
  const LocationFix({
    required this.point,
    required this.accuracy,
    required this.timestamp,
    this.speed,
    this.simulated = false,
  });

  final GeoPoint point;
  final double accuracy;
  final DateTime timestamp;
  final double? speed;
  final bool simulated;
}

class PermissionReport {
  const PermissionReport({
    required this.locationServiceEnabled,
    required this.foreground,
    required this.background,
    required this.notifications,
    required this.precise,
    this.simulated = false,
  });

  final bool locationServiceEnabled;
  final bool foreground;
  final bool background;
  final bool notifications;
  final bool precise;
  final bool simulated;

  bool get canTrack => locationServiceEnabled && foreground && (background || simulated);
  bool get isReady => canTrack && notifications;

  List<String> get issues {
    if (simulated) return const [];
    final list = <String>[];
    if (!locationServiceEnabled) list.add('Location services are switched off');
    if (!foreground) list.add('Location permission is required');
    if (!background) list.add('"Always allow" is required for background tracking');
    if (!notifications) list.add('Notifications are required for the tracking service');
    if (!precise) list.add('Precise location improves geofence accuracy');
    return list;
  }

  static const PermissionReport demo = PermissionReport(
    locationServiceEnabled: true,
    foreground: true,
    background: true,
    notifications: true,
    precise: true,
    simulated: true,
  );
}

class LocationService {
  bool get isMobile =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  Future<PermissionReport> checkPermissions({bool request = false}) async {
    if (!isMobile) return PermissionReport.demo;

    var serviceEnabled = await Geolocator.isLocationServiceEnabled();
    var foreground = await Permission.location.status;
    var background = await Permission.locationAlways.status;
    var notifications = await Permission.notification.status;

    if (request) {
      if (notifications.isDenied) {
        await Permission.notification.request();
      }
      if (foreground.isDenied) {
        await Permission.location.request();
        foreground = await Permission.location.status;
      }
      if (foreground.isGranted && !background.isGranted) {
        await Permission.locationAlways.request();
        background = await Permission.locationAlways.status;
      }
      notifications = await Permission.notification.status;
      serviceEnabled = await Geolocator.isLocationServiceEnabled();
    }

    var precise = true;
    try {
      final accuracy = await Geolocator.getLocationAccuracy();
      precise = accuracy != LocationAccuracyStatus.reduced;
    } catch (_) {
      // Not supported on every OEM build — assume precise.
    }

    return PermissionReport(
      locationServiceEnabled: serviceEnabled,
      foreground: foreground.isGranted,
      background: background.isGranted,
      notifications: notifications.isGranted,
      precise: precise,
    );
  }

  Future<PermissionReport> requestPermissions() => checkPermissions(request: true);

  Future<LocationFix> currentFix({bool allowSimulatedFallback = true}) async {
    if (!isMobile) {
      return LocationFix(
        point: DemoLocationProvider.instance.position,
        accuracy: DemoLocationProvider.instance.accuracy,
        timestamp: DateTime.now(),
        speed: 0,
        simulated: true,
      );
    }

    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw AppException('Location services are switched off. Turn on GPS to continue.', code: 'gps_off');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }
    if (permission == LocationPermission.denied || permission == LocationPermission.deniedForever) {
      throw AppException(
        'Location permission is required to verify your attendance.',
        code: 'permission_denied',
      );
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 18),
        ),
      );
      return LocationFix(
        point: GeoPoint(position.latitude, position.longitude),
        accuracy: position.accuracy,
        timestamp: position.timestamp,
        speed: position.speed,
      );
    } on TimeoutException {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null && DateTime.now().difference(last.timestamp).inMinutes < 10) {
        return LocationFix(
          point: GeoPoint(last.latitude, last.longitude),
          accuracy: last.accuracy,
          timestamp: last.timestamp,
          speed: last.speed,
        );
      }
      throw AppException(
        'Could not get a GPS fix. Move to an open area and try again.',
        code: 'gps_timeout',
      );
    } on LocationServiceDisabledException {
      throw AppException('Location services are switched off. Turn on GPS to continue.', code: 'gps_off');
    } on PermissionDeniedException {
      throw AppException('Location permission was denied.', code: 'permission_denied');
    } catch (error) {
      if (allowSimulatedFallback && AppConfig.isSimulationEnvironment) {
        return LocationFix(
          point: DemoLocationProvider.instance.position,
          accuracy: DemoLocationProvider.instance.accuracy,
          timestamp: DateTime.now(),
          simulated: true,
        );
      }
      throw AppException('Unable to read your location right now. Please retry.', detail: error.toString());
    }
  }

  Future<void> openAppSettingsPage() => openAppSettings();

  Future<void> openLocationSettingsPage() => Geolocator.openLocationSettings();
}
