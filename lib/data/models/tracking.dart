import '../../core/utils/geo.dart';

enum MovementStatus {
  moving,
  stationary,
  unknown;

  static MovementStatus parse(String? value) => switch (value) {
        'moving' => MovementStatus.moving,
        'stationary' => MovementStatus.stationary,
        _ => MovementStatus.unknown,
      };

  String get dbValue => name;

  String get label => switch (this) {
        MovementStatus.moving => 'Moving',
        MovementStatus.stationary => 'Stationary',
        MovementStatus.unknown => 'Unknown',
      };
}

class LocationRecord {
  const LocationRecord({
    required this.id,
    required this.employeeId,
    required this.sessionId,
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.battery,
    required this.platform,
    required this.movementStatus,
    required this.recordedAt,
    this.speed,
    this.bearing,
    this.source = 'native',
    this.syncStatus = 'pending',
  });

  final String id;
  final String employeeId;
  final String sessionId;
  final double latitude;
  final double longitude;
  final double accuracy;
  final double? speed;
  final double? bearing;
  final int battery;
  final String platform;
  final MovementStatus movementStatus;
  final DateTime recordedAt;
  final String source;
  final String syncStatus;

  GeoPoint get point => GeoPoint(latitude, longitude);

  Map<String, Object?> toMap() => {
        'id': id,
        'employee_id': employeeId,
        'session_id': sessionId,
        'latitude': latitude,
        'longitude': longitude,
        'accuracy': accuracy,
        'speed': speed,
        'bearing': bearing,
        'battery': battery,
        'platform': platform,
        'movement_status': movementStatus.dbValue,
        'recorded_at': recordedAt.millisecondsSinceEpoch,
        'source': source,
        'sync_status': syncStatus,
      };

  factory LocationRecord.fromMap(Map<String, Object?> map) => LocationRecord(
        id: map['id'] as String,
        employeeId: map['employee_id'] as String,
        sessionId: map['session_id'] as String,
        latitude: (map['latitude'] as num).toDouble(),
        longitude: (map['longitude'] as num).toDouble(),
        accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0,
        speed: (map['speed'] as num?)?.toDouble(),
        bearing: (map['bearing'] as num?)?.toDouble(),
        battery: (map['battery'] as int?) ?? 0,
        platform: (map['platform'] as String?) ?? 'unknown',
        movementStatus: MovementStatus.parse(map['movement_status'] as String?),
        recordedAt: DateTime.fromMillisecondsSinceEpoch(map['recorded_at'] as int),
        source: (map['source'] as String?) ?? 'native',
        syncStatus: (map['sync_status'] as String?) ?? 'pending',
      );
}

enum StationaryStatus {
  active,
  completed;

  static StationaryStatus parse(String? value) => value == 'completed' ? StationaryStatus.completed : StationaryStatus.active;

  String get dbValue => name;
  bool get isActive => this == StationaryStatus.active;
}

class StationaryEvent {
  const StationaryEvent({
    required this.id,
    required this.employeeId,
    required this.sessionId,
    required this.latitude,
    required this.longitude,
    required this.startAt,
    required this.accuracy,
    required this.status,
    this.endAt,
    this.durationSeconds = 0,
    this.battery,
    this.radiusMeters = 30,
    this.syncStatus = 'pending',
  });

  final String id;
  final String employeeId;
  final String sessionId;
  final double latitude;
  final double longitude;
  final DateTime startAt;
  final DateTime? endAt;
  final int durationSeconds;
  final double accuracy;
  final int? battery;
  final StationaryStatus status;
  final double radiusMeters;
  final String syncStatus;

  GeoPoint get point => GeoPoint(latitude, longitude);

  Duration get duration => Duration(seconds: durationSeconds);
  bool get isActive => status.isActive;

  StationaryEvent copyWith({
    DateTime? endAt,
    int? durationSeconds,
    int? battery,
    StationaryStatus? status,
  }) =>
      StationaryEvent(
        id: id,
        employeeId: employeeId,
        sessionId: sessionId,
        latitude: latitude,
        longitude: longitude,
        startAt: startAt,
        accuracy: accuracy,
        status: status ?? this.status,
        endAt: endAt ?? this.endAt,
        durationSeconds: durationSeconds ?? this.durationSeconds,
        battery: battery ?? this.battery,
        radiusMeters: radiusMeters,
        syncStatus: syncStatus,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'employee_id': employeeId,
        'session_id': sessionId,
        'latitude': latitude,
        'longitude': longitude,
        'start_at': startAt.millisecondsSinceEpoch,
        'end_at': endAt?.millisecondsSinceEpoch,
        'duration_seconds': durationSeconds,
        'accuracy': accuracy,
        'battery': battery,
        'status': status.dbValue,
        'radius_meters': radiusMeters,
        'sync_status': syncStatus,
      };

  factory StationaryEvent.fromMap(Map<String, Object?> map) {
    final rawStart = (map['start_at'] as int?) ?? 0;
    // Guard against epoch 0 or timestamps in seconds
    final startAt = rawStart <= 0
        ? DateTime.now()
        : rawStart < 10000000000
            ? DateTime.fromMillisecondsSinceEpoch(rawStart * 1000)
            : DateTime.fromMillisecondsSinceEpoch(rawStart);

    final rawEnd = map['end_at'] as int?;
    final endAt = rawEnd == null
        ? null
        : rawEnd < 10000000000
            ? DateTime.fromMillisecondsSinceEpoch(rawEnd * 1000)
            : DateTime.fromMillisecondsSinceEpoch(rawEnd);

    final rawDuration = (map['duration_seconds'] as int?) ?? 0;
    final durationSeconds = rawDuration.clamp(0, 86400);

    return StationaryEvent(
      id: map['id'] as String,
      employeeId: map['employee_id'] as String,
      sessionId: map['session_id'] as String,
      latitude: (map['latitude'] as num).toDouble(),
      longitude: (map['longitude'] as num).toDouble(),
      startAt: startAt,
      endAt: endAt,
      durationSeconds: durationSeconds,
      accuracy: (map['accuracy'] as num?)?.toDouble() ?? 0,
      battery: map['battery'] as int?,
      status: StationaryStatus.parse(map['status'] as String?),
      radiusMeters: (map['radius_meters'] as num?)?.toDouble() ?? 30,
      syncStatus: (map['sync_status'] as String?) ?? 'pending',
    );
  }
}
