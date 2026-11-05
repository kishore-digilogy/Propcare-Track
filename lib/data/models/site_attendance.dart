import '../../core/utils/geo.dart';

enum SiteVisitStatus {
  active,
  completed;

  static SiteVisitStatus parse(String? value) => value == 'completed' ? SiteVisitStatus.completed : SiteVisitStatus.active;

  String get dbValue => name;
  bool get isActive => this == SiteVisitStatus.active;
  String get label => isActive ? 'On site' : 'Completed';
}

class SiteAttendance {
  const SiteAttendance({
    required this.id,
    required this.employeeId,
    required this.sessionId,
    required this.siteId,
    required this.siteName,
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
    this.durationSeconds,
    this.syncStatus = 'pending',
  });

  final String id;
  final String employeeId;
  final String sessionId;
  final String siteId;
  final String siteName;
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
  final int? durationSeconds;
  final SiteVisitStatus status;
  final String syncStatus;

  bool get isActive => status.isActive;
  GeoPoint get checkInPoint => GeoPoint(checkInLatitude, checkInLongitude);
  Duration get visitDuration =>
      durationSeconds != null ? Duration(seconds: durationSeconds!) : DateTime.now().difference(checkInAt);

  SiteAttendance copyWith({
    DateTime? checkOutAt,
    double? checkOutLatitude,
    double? checkOutLongitude,
    double? checkOutAccuracy,
    int? checkOutBattery,
    int? durationSeconds,
    SiteVisitStatus? status,
  }) =>
      SiteAttendance(
        id: id,
        employeeId: employeeId,
        sessionId: sessionId,
        siteId: siteId,
        siteName: siteName,
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
        durationSeconds: durationSeconds ?? this.durationSeconds,
        syncStatus: syncStatus,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'employee_id': employeeId,
        'session_id': sessionId,
        'site_id': siteId,
        'site_name': siteName,
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
        'duration_seconds': durationSeconds,
        'status': status.dbValue,
        'sync_status': syncStatus,
      };

  factory SiteAttendance.fromMap(Map<String, Object?> map) => SiteAttendance(
        id: map['id'] as String,
        employeeId: map['employee_id'] as String,
        sessionId: map['session_id'] as String,
        siteId: map['site_id'] as String,
        siteName: map['site_name'] as String,
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
        durationSeconds: map['duration_seconds'] as int?,
        status: SiteVisitStatus.parse(map['status'] as String?),
        syncStatus: (map['sync_status'] as String?) ?? 'pending',
      );
}

class BatteryLog {
  const BatteryLog({
    required this.id,
    required this.employeeId,
    required this.level,
    required this.recordedAt,
    required this.context,
    this.sessionId,
  });

  final String id;
  final String employeeId;
  final String? sessionId;
  final int level;
  final DateTime recordedAt;
  final String context;

  Map<String, Object?> toMap() => {
        'id': id,
        'employee_id': employeeId,
        'session_id': sessionId,
        'level': level,
        'recorded_at': recordedAt.millisecondsSinceEpoch,
        'context': context,
      };

  factory BatteryLog.fromMap(Map<String, Object?> map) => BatteryLog(
        id: map['id'] as String,
        employeeId: map['employee_id'] as String,
        sessionId: map['session_id'] as String?,
        level: (map['level'] as int?) ?? 0,
        recordedAt: DateTime.fromMillisecondsSinceEpoch(map['recorded_at'] as int),
        context: (map['context'] as String?) ?? 'tracking',
      );
}
