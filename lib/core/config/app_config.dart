import 'package:flutter/foundation.dart';

import '../utils/geo.dart';

/// Central, compile-time configuration for the Phase 1 build.
///
/// Everything in here is intentionally local. When the backend arrives these
/// values can be hydrated from the API without touching the tracking engine.
class AppConfig {
  const AppConfig._();

  static const String appName = 'PropCare Track';
  static const String appTagline = 'Every stop, accounted for.';
  static const String version = '1.0.0 (Phase 1)';

  // ── Office ────────────────────────────────────────────────────────────────
  static const OfficeSeed office = OfficeSeed(
    id: 'office-baid',
    name: 'BAID Hi-Tech Park',
    address: 'East Coast Road, Thiruvanmiyur, Chennai',
    latitude: 12.9763,
    longitude: 80.2588,
    radiusMeters: 200,
  );

  // ── Assigned sites ────────────────────────────────────────────────────────
  static const List<SiteSeed> sites = [
    SiteSeed(
      id: 'site-suncity',
      code: 'SITE-01',
      name: 'Casagrand Suncity',
      address: 'Vandalur – Kelambakkam Road, Chennai',
      latitude: 12.84018,
      longitude: 80.14907,
      radiusMeters: 250,
    ),
    SiteSeed(
      id: 'site-firstcity',
      code: 'SITE-02',
      name: 'Casagrand First City',
      address: 'Perumbakkam / Sholinganallur, Chennai',
      latitude: 12.895398,
      longitude: 80.208018,
      radiusMeters: 250,
    ),
  ];

  // ── Tracking engine ───────────────────────────────────────────────────────
  static const int locationIntervalMs = 12000; // 12 s target cadence
  static const double distanceFilterMeters = 5;
  static const Duration stationaryThreshold = Duration(seconds: 20);
  static const double stationaryRadiusMeters = 30;
  static const double stationaryBreakHysteresis = 1.6; // 30 m → 48 m break
  static const double maxAccuracyForStationary = 80;
  static const double poorAccuracyMeters = 35;
  static const Duration batteryLogInterval = Duration(minutes: 5);
  static const int maxPendingDrainBatch = 500;

  // ── Demo / local auth ─────────────────────────────────────────────────────
  static const String demoPassword = 'track@123';

  static const List<DemoEmployee> demoEmployees = [
    DemoEmployee(
      id: 'emp-1042',
      code: 'EMP-1042',
      name: 'Arjun Mehta',
      email: 'arjun.mehta@propcare.in',
      phone: '+91 98400 22114',
      department: 'Field Operations',
      designation: 'Field Operations Executive',
      joinedAt: '2023-04-17',
    ),
    DemoEmployee(
      id: 'emp-2087',
      code: 'EMP-2087',
      name: 'Priya Nair',
      email: 'priya.nair@propcare.in',
      phone: '+91 98840 55207',
      department: 'Project Delivery',
      designation: 'Site Supervisor',
      joinedAt: '2022-11-02',
    ),
  ];

  /// Platforms that have a native background tracking implementation.
  static bool get hasNativeTracking =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// Desktop / web builds run the deterministic journey simulator so the whole
  /// workflow can be demonstrated without a device.
  static bool get isSimulationEnvironment => !hasNativeTracking;
}

class OfficeSeed {
  const OfficeSeed({
    required this.id,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  final String id;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  GeoPoint get point => GeoPoint(latitude, longitude);

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'radius_meters': radiusMeters,
      };
}

class SiteSeed {
  const SiteSeed({
    required this.id,
    required this.code,
    required this.name,
    required this.address,
    required this.latitude,
    required this.longitude,
    required this.radiusMeters,
  });

  final String id;
  final String code;
  final String name;
  final String address;
  final double latitude;
  final double longitude;
  final double radiusMeters;

  GeoPoint get point => GeoPoint(latitude, longitude);

  Map<String, Object?> toMap() => {
        'id': id,
        'code': code,
        'name': name,
        'address': address,
        'latitude': latitude,
        'longitude': longitude,
        'radius_meters': radiusMeters,
      };
}

class DemoEmployee {
  const DemoEmployee({
    required this.id,
    required this.code,
    required this.name,
    required this.email,
    required this.phone,
    required this.department,
    required this.designation,
    required this.joinedAt,
  });

  final String id;
  final String code;
  final String name;
  final String email;
  final String phone;
  final String department;
  final String designation;
  final String joinedAt;
}
