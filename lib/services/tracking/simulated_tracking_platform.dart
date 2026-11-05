import 'dart:async';
import 'dart:math' as math;

import 'package:uuid/uuid.dart';

import '../../core/config/app_config.dart';
import '../../core/utils/geo.dart';
import 'demo_location.dart';
import 'tracking_platform.dart';

/// Deterministic "day in the field" simulator used on desktop and web builds.
/// It drives the exact same event contract as the native services, so every
/// screen, the stationary detector and the local database are exercised.
class SimulatedTrackingPlatform implements TrackingPlatform {
  SimulatedTrackingPlatform({required Future<int> Function() batteryProvider})
      : _batteryProvider = batteryProvider;

  final Future<int> Function() _batteryProvider;
  final StreamController<Map<String, dynamic>> _controller = StreamController.broadcast();
  final Uuid _uuid = const Uuid();

  Timer? _timer;
  TrackingConfig? _config;
  DateTime? _startedAt;
  List<_Leg> _legs = const [];
  bool _tracking = false;
  int _tickCount = 0;
  int _jumpOffsetMs = 0;
  int _battery = 88;

  @override
  String get name => 'simulated';

  @override
  bool get supportsNativeStationary => false;

  @override
  Stream<Map<String, dynamic>> get events => _controller.stream;

  bool get isSimulation => true;

  @override
  Future<bool> start(TrackingConfig config) async {
    _config = config;
    _tracking = true;
    _startedAt = DateTime.now();
    _jumpOffsetMs = 0;
    _tickCount = 0;
    _legs = _buildLegs();
    _battery = await _batteryProvider().catchError((_) => 88);
    DemoLocationProvider.instance.moveTo(AppConfig.office.point, accuracy: 8);
    _emitLocation(AppConfig.office.point, speed: 0, accuracy: 8);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 3), (_) => _tick());
    _controller.add({
      'type': 'status',
      'tracking': true,
      'sessionId': config.sessionId,
      'source': 'simulated',
    });
    return true;
  }

  @override
  Future<bool> stop() async {
    _timer?.cancel();
    _timer = null;
    _tracking = false;
    _controller.add({'type': 'status', 'tracking': false, 'sessionId': _config?.sessionId});
    return true;
  }

  @override
  Future<bool> isTracking() async => _tracking;

  @override
  Future<Map<String, dynamic>> status() async => {
        'tracking': _tracking,
        'sessionId': _config?.sessionId,
        'source': 'simulated',
        'battery': _battery,
        'latitude': DemoLocationProvider.instance.position.latitude,
        'longitude': DemoLocationProvider.instance.position.longitude,
      };

  @override
  Future<List<Map<String, dynamic>>> drainQueue() async => [];

  @override
  Future<void> ackQueue(List<String> ids) async {}

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    await _controller.close();
  }

  /// Teleport the demo to the nearest stop (office or a project site).
  Future<void> jumpTo(GeoPoint target) async {
    if (!_tracking || _startedAt == null) {
      DemoLocationProvider.instance.moveTo(target, accuracy: 7);
      return;
    }
    var bestStart = 0;
    var bestDistance = double.infinity;
    var running = 0;
    for (final leg in _legs) {
      if (leg.dwell) {
        final d = distanceBetween(leg.from, target);
        if (d < bestDistance) {
          bestDistance = d;
          bestStart = running;
        }
      }
      running += leg.duration.inMilliseconds;
    }
    final base = DateTime.now().difference(_startedAt!).inMilliseconds;
    _jumpOffsetMs = bestStart - base + 1500;
    final point = _pointAt(DateTime.now());
    DemoLocationProvider.instance.moveTo(point, accuracy: 7);
    _emitLocation(point, speed: 0, accuracy: 7);
  }

  Future<void> jumpToOffice() => jumpTo(AppConfig.office.point);

  Future<void> jumpToSite(int index) {
    final site = AppConfig.sites[index.clamp(0, AppConfig.sites.length - 1)];
    return jumpTo(GeoPoint(site.latitude, site.longitude));
  }

  void _tick() {
    if (!_tracking || _startedAt == null) return;
    _tickCount++;
    if (_tickCount % 8 == 0) {
      _batteryProvider().then((value) {
        if (value > 0) _battery = value;
      }).catchError((_) {});
    }
    final now = DateTime.now();
    final point = _pointAt(now);
    final leg = _legAt(now);
    final speed = leg == null || leg.dwell ? 0.0 : distanceBetween(leg.from, leg.to) / leg.duration.inSeconds;
    final accuracy = 6 + (math.sin(_tickCount / 3).abs() * 5) + (math.Random().nextDouble() * 3);
    DemoLocationProvider.instance.moveTo(point, accuracy: accuracy);
    _emitLocation(point, speed: speed, accuracy: accuracy);
  }

  GeoPoint _pointAt(DateTime now) {
    final elapsed = _elapsedMs(now);
    var remaining = elapsed % _totalMs;
    for (final leg in _legs) {
      final legMs = leg.duration.inMilliseconds;
      if (remaining <= legMs) {
        if (leg.dwell) return leg.from;
        final t = remaining / legMs;
        final eased = t < 0.5 ? 2 * t * t : 1 - math.pow(-2 * t + 2, 2) / 2;
        return interpolate(leg.from, leg.to, eased.toDouble());
      }
      remaining -= legMs;
    }
    return _legs.isEmpty ? AppConfig.office.point : _legs.last.to;
  }

  _Leg? _legAt(DateTime now) {
    final elapsed = _elapsedMs(now);
    var remaining = elapsed % _totalMs;
    for (final leg in _legs) {
      final legMs = leg.duration.inMilliseconds;
      if (remaining <= legMs) return leg;
      remaining -= legMs;
    }
    return null;
  }

  int _elapsedMs(DateTime now) => now.difference(_startedAt!).inMilliseconds + _jumpOffsetMs;

  int get _totalMs => _legs.fold(0, (sum, leg) => sum + leg.duration.inMilliseconds);

  void _emitLocation(GeoPoint point, {required double speed, required double accuracy}) {
    final config = _config;
    if (config == null) return;
    final now = DateTime.now();
    _controller.add({
      'type': 'location',
      'id': _uuid.v4(),
      'employeeId': config.employeeId,
      'sessionId': config.sessionId,
      'latitude': point.latitude,
      'longitude': point.longitude,
      'accuracy': double.parse(accuracy.toStringAsFixed(1)),
      'speed': double.parse(speed.toStringAsFixed(2)),
      'bearing': 0,
      'battery': _battery,
      'platform': 'simulated',
      'movementStatus': speed < 0.7 ? 'stationary' : 'moving',
      'recordedAt': now.millisecondsSinceEpoch,
      'source': 'simulated',
    });
  }

  List<_Leg> _buildLegs() {
    final office = AppConfig.office.point;
    final site1 = GeoPoint(AppConfig.sites[0].latitude, AppConfig.sites[0].longitude);
    final site2 = GeoPoint(AppConfig.sites[1].latitude, AppConfig.sites[1].longitude);
    return [
      _Leg(office, office, const Duration(seconds: 26), dwell: true, label: 'BAID Hi-Tech Park'),
      _Leg(office, site1, const Duration(seconds: 30), label: 'En route · Suncity'),
      _Leg(site1, site1, const Duration(seconds: 40), dwell: true, label: 'Casagrand Suncity'),
      _Leg(site1, site2, const Duration(seconds: 24), label: 'En route · First City'),
      _Leg(site2, site2, const Duration(seconds: 40), dwell: true, label: 'Casagrand First City'),
      _Leg(site2, office, const Duration(seconds: 30), label: 'Return to office'),
      _Leg(office, office, const Duration(seconds: 24), dwell: true, label: 'BAID Hi-Tech Park'),
    ];
  }
}

class _Leg {
  const _Leg(this.from, this.to, this.duration, {this.dwell = false, this.label = ''});

  final GeoPoint from;
  final GeoPoint to;
  final Duration duration;
  final bool dwell;
  final String label;
}
