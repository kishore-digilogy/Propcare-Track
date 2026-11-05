import 'dart:async';

import 'package:flutter/services.dart';

import 'tracking_platform.dart';

/// Bridges Flutter to the Kotlin `TrackingService` and the Swift
/// `LocationTrackingManager`.
class NativeTrackingPlatform implements TrackingPlatform {
  NativeTrackingPlatform() {
    _subscription = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is Map) {
          _events.add(Map<String, dynamic>.from(event));
        }
      },
      onError: (Object error) {
        _events.add({'type': 'error', 'message': error.toString()});
      },
      cancelOnError: false,
    );
  }

  static const MethodChannel _channel = MethodChannel('propcare/tracking');
  static const EventChannel _eventChannel = EventChannel('propcare/tracking_events');

  final StreamController<Map<String, dynamic>> _events = StreamController.broadcast();
  StreamSubscription<dynamic>? _subscription;

  @override
  String get name => 'native';

  @override
  bool get supportsNativeStationary => true;

  @override
  Stream<Map<String, dynamic>> get events => _events.stream;

  @override
  Future<bool> start(TrackingConfig config) async {
    try {
      final result = await _channel.invokeMethod<bool>('startTracking', config.toMap());
      return result ?? false;
    } on PlatformException catch (error) {
      _events.add({'type': 'error', 'message': error.message ?? 'Unable to start background tracking'});
      return false;
    }
  }

  @override
  Future<bool> stop() async {
    try {
      final result = await _channel.invokeMethod<bool>('stopTracking');
      return result ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<bool> isTracking() async {
    try {
      return await _channel.invokeMethod<bool>('isTracking') ?? false;
    } on PlatformException {
      return false;
    }
  }

  @override
  Future<Map<String, dynamic>> status() async {
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>('getStatus');
      return result ?? {};
    } on PlatformException {
      return {};
    }
  }

  @override
  Future<List<Map<String, dynamic>>> drainQueue() async {
    try {
      final result = await _channel.invokeListMethod<dynamic>('getPendingRecords');
      if (result == null) return [];
      return result.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
    } on PlatformException {
      return [];
    }
  }

  @override
  Future<void> ackQueue(List<String> ids) async {
    if (ids.isEmpty) return;
    try {
      await _channel.invokeMethod<bool>('ackPendingRecords', {'ids': ids});
    } on PlatformException {
      // Records stay queued; the unique ids make the retry idempotent.
    }
  }

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _events.close();
  }
}
