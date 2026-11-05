import '../../core/utils/geo.dart';

enum AttendanceStatus {
  active,
  completed,
  interrupted,
  closedManually;

  static AttendanceStatus parse(String? value) => switch (value) {
        'completed' => AttendanceStatus.completed,
        'interrupted' => AttendanceStatus.interrupted,
        'closed_manually' => AttendanceStatus.closedManually,
        _ => AttendanceStatus.active,
      };

  String get dbValue => switch (this) {
        AttendanceStatus.active => 'active',
        AttendanceStatus.completed => 'completed',
        AttendanceStatus.interrupted => 'interrupted',
        AttendanceStatus.closedManually => 'closed_manually',
      };

  bool get isOpen => this == AttendanceStatus.active;
  String get label => switch (this) {
        AttendanceStatus.active => 'On duty',
        AttendanceStatus.completed => 'Completed',
        AttendanceStatus.interrupted => 'Interrupted',
        AttendanceStatus.closedManually => 'Closed manually',
      };
}

class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.employeeId,
    required this.sessionId,
    required this.officeId,
    required this.checkInAt,
    required this.checkInLatitude,
    required this.checkInLongitude,
    required this.checkInAccuracy,
    required this.checkInBattery,
    required this.status,
    this.checkOutAt,
    this.checkOutLatitude,
    this.checkOutLongitude,
    this.checkOutAccuracy,
    this.checkOutBattery,
    this.totalDurationSeconds,
    this.syncStatus = 'pending',
    required this.createdAt,
  });

  final String id;
  final String employeeId;
  final String sessionId;
  final String officeId;
  final DateTime checkInAt;
  final DateTime? checkOutAt;
  final double checkInLatitude;
  final double checkInLongitude;
  final double checkInAccuracy;
  final int checkInBattery;
  final double? checkOutLatitude;
  final double? checkOutLongitude;
  final double? checkOutAccuracy;
  final int? checkOutBattery;
  final AttendanceStatus status;
  final int? totalDurationSeconds;
  final String syncStatus;
  final DateTime createdAt;

  bool get isActive => status.isOpen;

  GeoPoint get checkInPoint => GeoPoint(checkInLatitude, checkInLongitude);
  GeoPoint? get checkOutPoint => checkOutLatitude != null && checkOutLongitude != null
      ? GeoPoint(checkOutLatitude!, checkOutLongitude!)
      : null;

  Duration get workedDuration {
    final end = checkOutAt ?? DateTime.now();
    final diff = end.difference(checkInAt);
    return diff.isNegative ? Duration.zero : diff;
  }

  AttendanceRecord copyWith({
    DateTime? checkOutAt,
    double? checkOutLatitude,
    double? checkOutLongitude,
    double? checkOutAccuracy,
    int? checkOutBattery,
    AttendanceStatus? status,
    int? totalDurationSeconds,
  }) =>
      AttendanceRecord(
        id: id,
        employeeId: employeeId,
        sessionId: sessionId,
        officeId: officeId,
        checkInAt: checkInAt,
        checkInLatitude: checkInLatitude,
        checkInLongitude: checkInLongitude,
        checkInAccuracy: checkInAccuracy,
        checkInBattery: checkInBattery,
        status: status ?? this.status,
        checkOutAt: checkOutAt ?? this.checkOutAt,
        checkOutLatitude: checkOutLatitude ?? this.checkOutLatitude,
        checkOutLongitude: checkOutLongitude ?? this.checkOutLongitude,
        checkOutAccuracy: checkOutAccuracy ?? this.checkOutAccuracy,
        checkOutBattery: checkOutBattery ?? this.checkOutBattery,
        totalDurationSeconds: totalDurationSeconds ?? this.totalDurationSeconds,
        syncStatus: syncStatus,
        createdAt: createdAt,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'employee_id': employeeId,
        'session_id': sessionId,
        'office_id': officeId,
        'check_in_at': checkInAt.millisecondsSinceEpoch,
        'check_out_at': checkOutAt?.millisecondsSinceEpoch,
        'check_in_lat': checkInLatitude,
        'check_in_lng': checkInLongitude,
        'check_in_accuracy': checkInAccuracy,
        'check_in_battery': checkInBattery,
        'check_out_lat': checkOutLatitude,
        'check_out_lng': checkOutLongitude,
        'check_out_accuracy': checkOutAccuracy,
        'check_out_battery': checkOutBattery,
        'status': status.dbValue,
        'total_duration_seconds': totalDurationSeconds,
        'sync_status': syncStatus,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory AttendanceRecord.fromMap(Map<String, Object?> map) => AttendanceRecord(
        id: map['id'] as String,
        employeeId: map['employee_id'] as String,
        sessionId: map['session_id'] as String,
        officeId: map['office_id'] as String,
        checkInAt: DateTime.fromMillisecondsSinceEpoch(map['check_in_at'] as int),
        checkOutAt: map['check_out_at'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(map['check_out_at'] as int),
        checkInLatitude: (map['check_in_lat'] as num).toDouble(),
        checkInLongitude: (map['check_in_lng'] as num).toDouble(),
        checkInAccuracy: (map['check_in_accuracy'] as num?)?.toDouble() ?? 0,
        checkInBattery: (map['check_in_battery'] as int?) ?? 0,
        checkOutLatitude: (map['check_out_lat'] as num?)?.toDouble(),
        checkOutLongitude: (map['check_out_lng'] as num?)?.toDouble(),
        checkOutAccuracy: (map['check_out_accuracy'] as num?)?.toDouble(),
        checkOutBattery: map['check_out_battery'] as int?,
        status: AttendanceStatus.parse(map['status'] as String?),
        totalDurationSeconds: map['total_duration_seconds'] as int?,
        syncStatus: (map['sync_status'] as String?) ?? 'pending',
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );
}

enum SessionStatus {
  active,
  completed,
  interrupted;

  static SessionStatus parse(String? value) => switch (value) {
        'completed' => SessionStatus.completed,
        'interrupted' => SessionStatus.interrupted,
        _ => SessionStatus.active,
      };

  String get dbValue => switch (this) {
        SessionStatus.active => 'active',
        SessionStatus.completed => 'completed',
        SessionStatus.interrupted => 'interrupted',
      };

  bool get isActive => this == SessionStatus.active;
  String get label => switch (this) {
        SessionStatus.active => 'Tracking live',
        SessionStatus.completed => 'Completed',
        SessionStatus.interrupted => 'Interrupted',
      };
}

class TrackingSession {
  const TrackingSession({
    required this.id,
    required this.employeeId,
    required this.attendanceId,
    required this.officeId,
    required this.startedAt,
    required this.status,
    required this.platform,
    required this.startBattery,
    this.endedAt,
    this.endBattery,
    this.lastLatitude,
    this.lastLongitude,
    this.lastUpdateAt,
    this.distanceMeters = 0,
    this.locationCount = 0,
    this.syncStatus = 'pending',
    required this.createdAt,
  });

  final String id;
  final String employeeId;
  final String attendanceId;
  final String officeId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final SessionStatus status;
  final String platform;
  final int startBattery;
  final int? endBattery;
  final double? lastLatitude;
  final double? lastLongitude;
  final DateTime? lastUpdateAt;
  final double distanceMeters;
  final int locationCount;
  final String syncStatus;
  final DateTime createdAt;

  bool get isActive => status.isActive;

  Duration get liveDuration => (endedAt ?? DateTime.now()).difference(startedAt);

  TrackingSession copyWith({
    DateTime? endedAt,
    SessionStatus? status,
    int? endBattery,
    double? lastLatitude,
    double? lastLongitude,
    DateTime? lastUpdateAt,
    double? distanceMeters,
    int? locationCount,
    bool clearEndedAt = false,
  }) =>
      TrackingSession(
        id: id,
        employeeId: employeeId,
        attendanceId: attendanceId,
        officeId: officeId,
        startedAt: startedAt,
        status: status ?? this.status,
        platform: platform,
        startBattery: startBattery,
        endBattery: endBattery ?? this.endBattery,
        lastLatitude: lastLatitude ?? this.lastLatitude,
        lastLongitude: lastLongitude ?? this.lastLongitude,
        lastUpdateAt: lastUpdateAt ?? this.lastUpdateAt,
        distanceMeters: distanceMeters ?? this.distanceMeters,
        locationCount: locationCount ?? this.locationCount,
        syncStatus: syncStatus,
        createdAt: createdAt,
        endedAt: clearEndedAt ? null : (endedAt ?? this.endedAt),
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'employee_id': employeeId,
        'attendance_id': attendanceId,
        'office_id': officeId,
        'started_at': startedAt.millisecondsSinceEpoch,
        'ended_at': endedAt?.millisecondsSinceEpoch,
        'status': status.dbValue,
        'platform': platform,
        'start_battery': startBattery,
        'end_battery': endBattery,
        'last_latitude': lastLatitude,
        'last_longitude': lastLongitude,
        'last_update_at': lastUpdateAt?.millisecondsSinceEpoch,
        'distance_meters': distanceMeters,
        'location_count': locationCount,
        'sync_status': syncStatus,
        'created_at': createdAt.millisecondsSinceEpoch,
      };

  factory TrackingSession.fromMap(Map<String, Object?> map) => TrackingSession(
        id: map['id'] as String,
        employeeId: map['employee_id'] as String,
        attendanceId: map['attendance_id'] as String,
        officeId: map['office_id'] as String,
        startedAt: DateTime.fromMillisecondsSinceEpoch(map['started_at'] as int),
        endedAt: map['ended_at'] == null ? null : DateTime.fromMillisecondsSinceEpoch(map['ended_at'] as int),
        status: SessionStatus.parse(map['status'] as String?),
        platform: (map['platform'] as String?) ?? 'unknown',
        startBattery: (map['start_battery'] as int?) ?? 0,
        endBattery: map['end_battery'] as int?,
        lastLatitude: (map['last_latitude'] as num?)?.toDouble(),
        lastLongitude: (map['last_longitude'] as num?)?.toDouble(),
        lastUpdateAt:
            map['last_update_at'] == null ? null : DateTime.fromMillisecondsSinceEpoch(map['last_update_at'] as int),
        distanceMeters: (map['distance_meters'] as num?)?.toDouble() ?? 0,
        locationCount: (map['location_count'] as int?) ?? 0,
        syncStatus: (map['sync_status'] as String?) ?? 'pending',
        createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
      );
}
