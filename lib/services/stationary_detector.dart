import 'package:uuid/uuid.dart';

import '../core/config/app_config.dart';
import '../core/utils/geo.dart';
import '../data/models/tracking.dart';

class StationaryUpdate {
  const StationaryUpdate({this.started, this.updated, this.completed});

  final StationaryEvent? started;
  final StationaryEvent? updated;
  final StationaryEvent? completed;

  bool get isEmpty => started == null && updated == null && completed == null;
}

/// Pure Dart implementation of the 20-second stationary rule.
///
/// Used on platforms where native detection is unavailable (desktop demo) and
/// as the reference implementation for the Kotlin / Swift services.
class StationaryDetector {
  StationaryDetector({
    required this.employeeId,
    required this.sessionId,
    this.radiusMeters = AppConfig.stationaryRadiusMeters,
    this.threshold = AppConfig.stationaryThreshold,
    this.maxAccuracyMeters = AppConfig.maxAccuracyForStationary,
  });

  final String employeeId;
  final String sessionId;
  final double radiusMeters;
  final Duration threshold;
  final double maxAccuracyMeters;

  final Uuid _uuid = const Uuid();

  StationaryEvent? active;
  GeoPoint? _anchor;
  DateTime? _anchorSince;
  DateTime? _lastInsideAt;

  void restore(StationaryEvent? event) {
    active = event;
    if (event != null) {
      _anchor = event.point;
      _anchorSince = event.startAt;
      _lastInsideAt = event.endAt ?? DateTime.now();
    }
  }

  StationaryUpdate feed(LocationRecord record) {
    if (record.accuracy > maxAccuracyMeters) return const StationaryUpdate();
    final time = record.recordedAt;

    if (_anchor == null) {
      _anchor = record.point;
      _anchorSince = time;
      _lastInsideAt = time;
      return const StationaryUpdate();
    }

    // Out-of-order fix: ignore without disturbing the state machine.
    if (time.isBefore(_anchorSince!)) return const StationaryUpdate();

    final distance = distanceBetween(_anchor!, record.point);
    final breakDistance = radiusMeters * AppConfig.stationaryBreakHysteresis;

    if (distance <= breakDistance) {
      _lastInsideAt = time;
      if (active == null && time.difference(_anchorSince!) >= threshold) {
        active = StationaryEvent(
          id: _uuid.v4(),
          employeeId: employeeId,
          sessionId: sessionId,
          latitude: _anchor!.latitude,
          longitude: _anchor!.longitude,
          startAt: _anchorSince!,
          accuracy: record.accuracy,
          battery: record.battery,
          status: StationaryStatus.active,
          radiusMeters: radiusMeters,
        );
        return StationaryUpdate(started: active);
      }
      if (active != null) {
        active = active!.copyWith(
          endAt: time,
          durationSeconds: time.difference(active!.startAt).inSeconds,
          battery: record.battery,
        );
        return StationaryUpdate(updated: active);
      }
      return const StationaryUpdate();
    }

    final completed = active;
    final lastInside = _lastInsideAt;
    final anchor = _anchor;
    final anchorSince = _anchorSince;

    _anchor = record.point;
    _anchorSince = time;
    _lastInsideAt = time;

    if (completed != null) {
      final end = lastInside ?? completed.startAt;
      active = null;
      return StationaryUpdate(
        completed: completed.copyWith(
          endAt: end,
          durationSeconds: end.difference(completed.startAt).inSeconds.clamp(0, 86400).toInt(),
          battery: record.battery,
          status: StationaryStatus.completed,
        ),
      );
    } else if (anchorSince != null && anchor != null && (lastInside ?? time).difference(anchorSince) >= threshold) {
      final end = lastInside ?? time;
      return StationaryUpdate(
        completed: StationaryEvent(
          id: _uuid.v4(),
          employeeId: employeeId,
          sessionId: sessionId,
          latitude: anchor.latitude,
          longitude: anchor.longitude,
          startAt: anchorSince,
          endAt: end,
          durationSeconds: end.difference(anchorSince).inSeconds.clamp(0, 86400).toInt(),
          accuracy: record.accuracy,
          battery: record.battery,
          status: StationaryStatus.completed,
          radiusMeters: radiusMeters,
        ),
      );
    }
    return const StationaryUpdate();
  }

  /// Periodic heartbeat to verify stationary duration even when no new location arrives.
  StationaryUpdate checkHeartbeat(DateTime now, {int battery = 100, double accuracy = 5}) {
    final anchor = _anchor;
    final anchorSince = _anchorSince;
    if (anchor == null || anchorSince == null) return const StationaryUpdate();
    if (now.difference(anchorSince) >= threshold) {
      if (active == null) {
        active = StationaryEvent(
          id: _uuid.v4(),
          employeeId: employeeId,
          sessionId: sessionId,
          latitude: anchor.latitude,
          longitude: anchor.longitude,
          startAt: anchorSince,
          accuracy: accuracy,
          battery: battery,
          status: StationaryStatus.active,
          radiusMeters: radiusMeters,
        );
        return StationaryUpdate(started: active);
      } else {
        active = active!.copyWith(
          endAt: now,
          durationSeconds: now.difference(active!.startAt).inSeconds,
          battery: battery,
        );
        return StationaryUpdate(updated: active);
      }
    }
    return const StationaryUpdate();
  }

  /// Completes and flushes any active or qualifying stationary hold on checkout.
  StationaryEvent? flush(DateTime now, {int battery = 100, double accuracy = 5}) {
    if (active != null) {
      final ev = active!;
      active = null;
      _anchor = null;
      _anchorSince = null;
      return ev.copyWith(
        endAt: now,
        durationSeconds: now.difference(ev.startAt).inSeconds.clamp(0, 86400).toInt(),
        status: StationaryStatus.completed,
      );
    }
    final anchor = _anchor;
    final anchorSince = _anchorSince;
    if (anchor != null && anchorSince != null && now.difference(anchorSince) >= threshold) {
      _anchor = null;
      _anchorSince = null;
      return StationaryEvent(
        id: _uuid.v4(),
        employeeId: employeeId,
        sessionId: sessionId,
        latitude: anchor.latitude,
        longitude: anchor.longitude,
        startAt: anchorSince,
        endAt: now,
        durationSeconds: now.difference(anchorSince).inSeconds.clamp(0, 86400).toInt(),
        accuracy: accuracy,
        battery: battery,
        status: StationaryStatus.completed,
        radiusMeters: radiusMeters,
      );
    }
    return null;
  }

  /// Closes an event if GPS updates stop arriving while the employee is still.
  StationaryEvent? sweep(DateTime now) {
    final current = active;
    final lastInside = _lastInsideAt;
    if (current == null || lastInside == null) return null;
    if (now.difference(lastInside) < const Duration(seconds: 90)) return null;
    active = null;
    _anchor = null;
    _anchorSince = null;
    _lastInsideAt = null;
    return current.copyWith(
      endAt: lastInside,
      durationSeconds: lastInside.difference(current.startAt).inSeconds.clamp(0, 86400).toInt(),
      status: StationaryStatus.completed,
    );
  }
}
