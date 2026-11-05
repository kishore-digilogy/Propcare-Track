import 'package:sqflite/sqflite.dart';

import '../db/app_database.dart';
import '../models/attendance.dart';
import '../models/site_attendance.dart';

class AttendanceRepository {
  AttendanceRepository(this._db);

  final AppDatabase _db;

  Future<AttendanceRecord?> activeAttendance(String employeeId) async {
    final db = await _db.database;
    final rows = await db.query(
      'attendance_records',
      where: 'employee_id = ? AND status = ?',
      whereArgs: [employeeId, AttendanceStatus.active.dbValue],
      orderBy: 'check_in_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : AttendanceRecord.fromMap(rows.first);
  }

  Future<AttendanceRecord?> latestInterrupted(String employeeId) async {
    final db = await _db.database;
    final rows = await db.query(
      'attendance_records',
      where: 'employee_id = ? AND status = ?',
      whereArgs: [employeeId, AttendanceStatus.interrupted.dbValue],
      orderBy: 'check_in_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : AttendanceRecord.fromMap(rows.first);
  }

  Future<AttendanceRecord?> openAttendance(String employeeId) async {
    final db = await _db.database;
    final rows = await db.query(
      'attendance_records',
      where: 'employee_id = ? AND status IN (?, ?)',
      whereArgs: [employeeId, AttendanceStatus.active.dbValue, AttendanceStatus.interrupted.dbValue],
      orderBy: 'check_in_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : AttendanceRecord.fromMap(rows.first);
  }

  Future<AttendanceRecord?> byId(String id) async {
    final db = await _db.database;
    final rows = await db.query('attendance_records', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : AttendanceRecord.fromMap(rows.first);
  }

  Future<TrackingSession?> sessionById(String id) async {
    final db = await _db.database;
    final rows = await db.query('tracking_sessions', where: 'id = ?', whereArgs: [id], limit: 1);
    return rows.isEmpty ? null : TrackingSession.fromMap(rows.first);
  }

  Future<TrackingSession?> activeSession(String employeeId) async {
    final db = await _db.database;
    final rows = await db.query(
      'tracking_sessions',
      where: 'employee_id = ? AND status = ?',
      whereArgs: [employeeId, SessionStatus.active.dbValue],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    return rows.isEmpty ? null : TrackingSession.fromMap(rows.first);
  }

  Future<TrackingSession?> latestOpenSession(String employeeId) async {
    final db = await _db.database;
    final rows = await db.query(
      'tracking_sessions',
      where: 'employee_id = ? AND status = ?',
      whereArgs: [employeeId, SessionStatus.active.dbValue],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    if (rows.isNotEmpty) return TrackingSession.fromMap(rows.first);
    final interrupted = await db.query(
      'tracking_sessions',
      where: 'employee_id = ? AND status = ?',
      whereArgs: [employeeId, SessionStatus.interrupted.dbValue],
      orderBy: 'started_at DESC',
      limit: 1,
    );
    return interrupted.isEmpty ? null : TrackingSession.fromMap(interrupted.first);
  }

  Future<List<AttendanceRecord>> history(String employeeId, {int limit = 60}) async {
    final db = await _db.database;
    final rows = await db.query(
      'attendance_records',
      where: 'employee_id = ?',
      whereArgs: [employeeId],
      orderBy: 'check_in_at DESC',
      limit: limit,
    );
    return rows.map(AttendanceRecord.fromMap).toList();
  }

  Future<Map<String, TrackingSession>> sessionsByIds(List<String> ids) async {
    if (ids.isEmpty) return {};
    final db = await _db.database;
    final placeholders = List.filled(ids.length, '?').join(',');
    final rows = await db.query('tracking_sessions', where: 'id IN ($placeholders)', whereArgs: ids);
    return {for (final row in rows) row['id'] as String: TrackingSession.fromMap(row)};
  }

  Future<void> startSession({
    required AttendanceRecord attendance,
    required TrackingSession session,
    required BatteryLog batteryLog,
  }) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.insert('attendance_records', attendance.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('tracking_sessions', session.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      await txn.insert('battery_logs', batteryLog.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
    });
  }

  Future<void> updateAttendance(AttendanceRecord attendance) async {
    final db = await _db.database;
    await db.update('attendance_records', attendance.toMap(), where: 'id = ?', whereArgs: [attendance.id]);
  }

  Future<void> updateSession(TrackingSession session) async {
    final db = await _db.database;
    await db.update('tracking_sessions', session.toMap(), where: 'id = ?', whereArgs: [session.id]);
  }

  Future<void> closeSession({
    required AttendanceRecord attendance,
    required TrackingSession session,
    BatteryLog? batteryLog,
  }) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.update('attendance_records', attendance.toMap(), where: 'id = ?', whereArgs: [attendance.id]);
      await txn.update('tracking_sessions', session.toMap(), where: 'id = ?', whereArgs: [session.id]);
      if (batteryLog != null) {
        await txn.insert('battery_logs', batteryLog.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> markSessionInterrupted({
    required AttendanceRecord attendance,
    required TrackingSession session,
    BatteryLog? batteryLog,
  }) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      await txn.update('attendance_records', attendance.toMap(), where: 'id = ?', whereArgs: [attendance.id]);
      await txn.update('tracking_sessions', session.toMap(), where: 'id = ?', whereArgs: [session.id]);
      if (batteryLog != null) {
        await txn.insert('battery_logs', batteryLog.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
      }
    });
  }

  Future<void> deleteAllForEmployee(String employeeId) async {
    final db = await _db.database;
    await db.transaction((txn) async {
      for (final table in [
        'location_records',
        'stationary_events',
        'site_attendance',
        'battery_logs',
        'tracking_sessions',
        'attendance_records',
      ]) {
        await txn.delete(table, where: 'employee_id = ?', whereArgs: [employeeId]);
      }
    });
  }
}
