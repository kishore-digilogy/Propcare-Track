import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';

import '../core/utils/geo.dart';
import '../data/models/place.dart';

/// Service that translates GPS coordinates (latitude, longitude) into readable addresses
/// using native geocoding with intelligent caching and fallback to known site/office landmarks.
class GeoAddressService {
  GeoAddressService._();
  static final GeoAddressService instance = GeoAddressService._();

  Geocoding? _geocoding;
  bool _geocodingUnavailable = false;
  final Map<String, String> _cache = {};
  final Set<String> _inFlight = {};

  Geocoding? _getGeocoding() {
    if (_geocodingUnavailable) return null;
    if (_geocoding != null) return _geocoding;
    try {
      _geocoding = Geocoding();
      return _geocoding;
    } catch (_) {
      _geocodingUnavailable = true;
      return null;
    }
  }

  /// Pre-known places (office, sites) for instant local resolution without network.
  final List<({String name, String address, GeoPoint point, double radiusMeters})> _knownPlaces = [];

  void registerPlace({
    required String name,
    required String address,
    required double latitude,
    required double longitude,
    double radiusMeters = 300,
  }) {
    _knownPlaces.add((
      name: name,
      address: address,
      point: GeoPoint(latitude, longitude),
      radiusMeters: radiusMeters,
    ));
  }

  void registerSites(List<Site> sites) {
    for (final s in sites) {
      registerPlace(
        name: s.name,
        address: s.address,
        latitude: s.latitude,
        longitude: s.longitude,
        radiusMeters: s.radiusMeters > 0 ? s.radiusMeters : 250,
      );
    }
  }

  void registerOffice(OfficeConfig office) {
    registerPlace(
      name: office.name,
      address: office.address,
      latitude: office.latitude,
      longitude: office.longitude,
      radiusMeters: office.radiusMeters > 0 ? office.radiusMeters : 250,
    );
  }

  String _cacheKey(double lat, double lng) {
    // 3 decimal places is ~110m precision, ideal for street/neighborhood caching.
    return '${lat.toStringAsFixed(3)},${lng.toStringAsFixed(3)}';
  }

  /// Returns cached address synchronously if available, or null.
  String? getCached(double lat, double lng) {
    final key = _cacheKey(lat, lng);
    if (_cache.containsKey(key)) {
      return _cache[key];
    }
    // Check known places
    final pt = GeoPoint(lat, lng);
    for (final p in _knownPlaces) {
      if (distanceBetween(pt, p.point) <= p.radiusMeters) {
        final label = p.address.isNotEmpty ? '${p.name}, ${p.address}' : p.name;
        _cache[key] = label;
        return label;
      }
    }
    return null;
  }

  /// Asynchronously resolves coordinates to a readable street/neighborhood address.
  Future<String?> resolve(double lat, double lng) async {
    final cached = getCached(lat, lng);
    if (cached != null) return cached;

    final key = _cacheKey(lat, lng);
    if (_inFlight.contains(key)) {
      // Avoid duplicate concurrent lookups for the same grid
      return _cache[key];
    }

    _inFlight.add(key);
    try {
      final geo = _getGeocoding();
      if (geo != null) {
        final placemarks = await geo
            .placemarkFromCoordinates(lat, lng)
            .timeout(const Duration(seconds: 4));

        if (placemarks.isNotEmpty) {
          final formatted = formatPlacemark(placemarks.first);
          if (formatted.isNotEmpty) {
            _cache[key] = formatted;
            return formatted;
          }
        }
      }
    } catch (e) {
      // In simulation, offline mode, or when geocoding rate-limits, fallback gracefully.
      debugPrint('GeoAddressService reverse geocode error: $e');
    } finally {
      _inFlight.remove(key);
    }

    // Fallback: check closest known place within 1 km
    final pt = GeoPoint(lat, lng);
    double minDistance = double.infinity;
    String? closestLabel;
    for (final p in _knownPlaces) {
      final d = distanceBetween(pt, p.point);
      if (d < minDistance && d <= 1200) {
        minDistance = d;
        closestLabel = 'Near ${p.name}';
      }
    }

    if (closestLabel != null) {
      _cache[key] = closestLabel;
      return closestLabel;
    }

    return null;
  }

  /// Formats a [Placemark] into a human-friendly address:
  /// e.g. "Kottivakkam, Chennai" or "OMR Road, Sholinganallur, Chennai 600119"
  static String formatPlacemark(Placemark p) {
    final parts = <String>[];

    // Street / Name
    if (p.street != null && p.street!.isNotEmpty && p.street != p.name) {
      parts.add(p.street!);
    } else if (p.name != null && p.name!.isNotEmpty && !RegExp(r'^\d+$').hasMatch(p.name!)) {
      parts.add(p.name!);
    }

    // Sublocality (Neighborhood / Area)
    if (p.subLocality != null && p.subLocality!.isNotEmpty) {
      if (!parts.contains(p.subLocality!)) {
        parts.add(p.subLocality!);
      }
    }

    // Locality (City / Town)
    if (p.locality != null && p.locality!.isNotEmpty) {
      if (!parts.contains(p.locality!)) {
        parts.add(p.locality!);
      }
    } else if (p.subAdministrativeArea != null && p.subAdministrativeArea!.isNotEmpty) {
      if (!parts.contains(p.subAdministrativeArea!)) {
        parts.add(p.subAdministrativeArea!);
      }
    }

    return parts.join(', ');
  }
}
