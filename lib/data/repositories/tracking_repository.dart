import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/day_story.dart';
import '../models/site_attendance.dart';
import '../models/tracking.dart';

class TrackingRepository {
  TrackingRepository(this._db);

  final AppDatabase _db;

  // ── Locations ─────────────────────────────────────────────────────────────

  /// Inserts a location and advances the parent session counters atomically.
  /// Returns false when the record already exists (idempotent drain).
  Future<bool> appendLocation(LocationRecord record, {double deltaMeters = 0}) async {
    final db = await _db.database;
    return db.transaction<bool>((txn) async {
      final id = await txn.insert(
        'location_records',
        record.toMap(),
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
      if (id == 0) return false;
      await txn.rawUpdate(
        'UPDATE tracking_sessions SET '
        'location_count = location_count + 1, '
        'distance_meters = distance_meters + ?, '
        'last_latitude = ?, last_longitude = ?, last_update_at = ? '
        'WHERE id = ?',
        [
          deltaMeters,
          record.latitude,
          record.longitude,
          record.recordedAt.millisecondsSinceEpoch,
          record.sessionId,
        ],
      );
      return true;
    });
  }

  /// Used by the native queue drain. Session counters are recomputed once the
  /// batch is in.
  Future<void> insertLocationsRaw(List<LocationRecord> records) async {
    if (records.isEmpty) return;
    final db = await _db.database;
    final batch = db.batch();
    for (final record in records) {
      batch.insert('location_records', record.toMap(), conflictAlgorithm: ConflictAlgorithm.ignore);
    }
    await batch.commit(noResult: true);
  }

  Future<void> recomputeSessionStats(String sessionId) async {
    final db = await _db.database;
    final rows = await db.query(
      'location_records',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'recorded_at ASC',
    );
    final records = rows.map(LocationRecord.fromMap).toList();
    final distance = computeRouteDistance(records);
    final last = records.isEmpty ? null : records.last;
    await db.rawUpdate(
      'UPDATE tracking_sessions SET location_count = ?, distance_meters = ?, '
      'last_latitude = ?, last_longitude = ?, last_update_at = ? WHERE id = ?',
      [
        records.length,
        distance,
        last?.latitude,
        last?.longitude,
        last?.recordedAt.millisecondsSinceEpoch,
        sessionId,
      ],
    );
  }

  Future<List<LocationRecord>> locationsForSession(String sessionId, {int limit = 2000}) async {
    final db = await _db.database;
    final rows = await db.query(
      'location_records',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'recorded_at ASC',
      limit: limit,
    );
    return rows.map(LocationRecord.fromMap).toList();
  }

  Future<List<LocationRecord>> locationsForDay(
    String employeeId,
    DateTime start,
    DateTime end, {
    int limit = 5000,
  }) async {
    final db = await _db.database;
    final rows = await db.query(
      'location_records',
      where: 'employee_id = ? AND recorded_at BETWEEN ? AND ?',
      whereArgs: [employeeId, start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'recorded_at ASC',
      limit: limit,
    );
    return rows.map(LocationRecord.fromMap).toList();
  }

  Future<LocationRecord?> lastLocation(String sessionId) async {
    final db = await _db.database;
    final rows = await db.query(
      'location_records',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'recorded_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : LocationRecord.fromMap(rows.first);
  }

  Future<int> locationCountForSession(String sessionId) async {
    final db = await _db.database;
    final value = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM location_records WHERE session_id = ?', [sessionId]),
    );
    return value ?? 0;
  }

  // ── Stationary events ─────────────────────────────────────────────────────

  Future<void> upsertStationary(StationaryEvent event) async {
    final db = await _db.database;
    await db.insert('stationary_events', event.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> completeStationary({
    required String id,
    required DateTime endAt,
    required int durationSeconds,
    int? battery,
  }) async {
    final db = await _db.database;
    await db.update(
      'stationary_events',
      {
        'end_at': endAt.millisecondsSinceEpoch,
        'duration_seconds': durationSeconds,
        'battery': battery,
        'status': StationaryStatus.completed.dbValue,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<StationaryEvent?> activeStationary(String sessionId) async {
    final db = await _db.database;
    final rows = await db.query(
      'stationary_events',
      where: 'session_id = ? AND status = ?',
      whereArgs: [sessionId, StationaryStatus.active.dbValue],
      orderBy: 'start_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : StationaryEvent.fromMap(rows.first);
  }

  Future<List<StationaryEvent>> stationaryForSession(String sessionId) async {
    final db = await _db.database;
    final rows = await db.query(
      'stationary_events',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'start_at ASC',
    );
    return rows.map(StationaryEvent.fromMap).toList();
  }

  Future<List<StationaryEvent>> recentStationary(String employeeId, {int limit = 1000}) async {
    final db = await _db.database;
    final rows = await db.query(
      'stationary_events',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      orderBy: 'start_at ASC',
      limit: limit,
    );
    return rows.map(StationaryEvent.fromMap).toList();
  }

  Future<List<StationaryEvent>> stationaryForDay(
    String employeeId,
    DateTime start,
    DateTime end, {
    int limit = 500,
  }) async {
    final db = await _db.database;
    final rows = await db.query(
      'stationary_events',
      where: 'employee_id = ? AND start_at BETWEEN ? AND ?',
      whereArgs: [employeeId, start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'start_at ASC',
      limit: limit,
    );
    return rows.map(StationaryEvent.fromMap).toList();
  }

  Future<Map<String, int>> stationarySecondsBySession(String employeeId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT session_id, SUM(duration_seconds) AS total FROM stationary_events '
      'WHERE employee_id = ? GROUP BY session_id',
      [employeeId],
    );
    return {
      for (final row in rows)
        row['session_id'] as String: ((row['total'] as num?) ?? 0).toInt(),
    };
  }

  // ── Site visits ───────────────────────────────────────────────────────────

  Future<void> insertSiteVisit(SiteAttendance visit) async {
    final db = await _db.database;
    await db.insert('site_attendance', visit.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<void> updateSiteVisit(SiteAttendance visit) async {
    final db = await _db.database;
    await db.update('site_attendance', visit.toMap(), where: 'id = ?', whereArgs: [visit.id]);
  }

  Future<SiteAttendance?> activeSiteVisit(String sessionId) async {
    final db = await _db.database;
    final rows = await db.query(
      'site_attendance',
      where: 'session_id = ? AND status = ?',
      whereArgs: [sessionId, SiteVisitStatus.active.dbValue],
      orderBy: 'check_in_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : SiteAttendance.fromMap(rows.first);
  }

  Future<List<SiteAttendance>> siteVisitsForSession(String sessionId) async {
    final db = await _db.database;
    final rows = await db.query(
      'site_attendance',
      where: 'session_id = ?',
      whereArgs: [sessionId],
      orderBy: 'check_in_at ASC',
    );
    return rows.map(SiteAttendance.fromMap).toList();
  }

  Future<List<SiteAttendance>> siteVisitsForDay(String employeeId, DateTime start, DateTime end) async {
    final db = await _db.database;
    final rows = await db.query(
      'site_attendance',
      where: 'employee_id = ? AND check_in_at BETWEEN ? AND ?',
      whereArgs: [employeeId, start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'check_in_at ASC',
    );
    return rows.map(SiteAttendance.fromMap).toList();
  }

  Future<List<SiteAttendance>> recentSiteVisits(String employeeId, {int limit = 20}) async {
    final db = await _db.database;
    final rows = await db.query(
      'site_attendance',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      orderBy: 'check_in_at DESC',
      limit: limit,
    );
    return rows.map(SiteAttendance.fromMap).toList();
  }

  Future<Map<String, int>> siteVisitCountsBySession(String employeeId) async {
    final db = await _db.database;
    final rows = await db.rawQuery(
      'SELECT session_id, COUNT(*) AS total FROM site_attendance WHERE employee_id = ? GROUP BY session_id',
      [employeeId],
    );
    return {
      for (final row in rows) row['session_id'] as String: ((row['total'] as num?) ?? 0).toInt(),
    };
  }

  // ── Battery ───────────────────────────────────────────────────────────────

  Future<void> insertBatteryLog(BatteryLog log) async {
    final db = await _db.database;
    await db.insert('battery_logs', log.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<List<BatteryLog>> batteryForDay(String employeeId, DateTime start, DateTime end) async {
    final db = await _db.database;
    final rows = await db.query(
      'battery_logs',
      where: 'employee_id = ? AND recorded_at BETWEEN ? AND ?',
      whereArgs: [employeeId, start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'recorded_at ASC',
    );
    return rows.map(BatteryLog.fromMap).toList();
  }

  Future<int?> latestBattery(String employeeId) async {
    final db = await _db.database;
    final rows = await db.query(
      'battery_logs',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      orderBy: 'recorded_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : rows.first['level'] as int?;
  }

  // ── Sync bookkeeping ──────────────────────────────────────────────────────

  Future<int> pendingRecordCount() async {
    final db = await _db.database;
    var total = 0;
    for (final table in [
      'attendance_records',
      'tracking_sessions',
      'location_records',
      'stationary_events',
      'site_attendance',
    ]) {
      final value = Sqflite.firstIntValue(
        await db.rawQuery("SELECT COUNT(*) FROM $table WHERE sync_status = 'pending'"),
      );
      total += value ?? 0;
    }
    return total;
  }
}
