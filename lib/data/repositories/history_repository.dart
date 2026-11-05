import 'package:sqflite/sqflite.dart';

import '../../core/utils/formatters.dart';
import '../../core/utils/geo.dart';
import '../db/app_database.dart';
import '../models/attendance.dart';
import '../models/day_story.dart';
import '../models/site_attendance.dart';
import '../models/tracking.dart';
import 'attendance_repository.dart';
import 'config_repository.dart';
import 'tracking_repository.dart';

class HistoryRepository {
  HistoryRepository(this._db)
      : _attendance = AttendanceRepository(_db),
        _tracking = TrackingRepository(_db),
        _config = ConfigRepository(_db);

  final AppDatabase _db;
  final AttendanceRepository _attendance;
  final TrackingRepository _tracking;
  final ConfigRepository _config;

  Future<DayStory> dayStory(String employeeId, DateTime date) async {
    final start = Fmt.startOfDay(date);
    final end = Fmt.endOfDay(date);
    final database = await _db.database;

    final attendanceRows = await database.query(
      'attendance_records',
      where: 'employee_id = ? AND check_in_at BETWEEN ? AND ?',
      whereArgs: [employeeId, start.millisecondsSinceEpoch, end.millisecondsSinceEpoch],
      orderBy: 'check_in_at ASC',
    );
    final attendances = attendanceRows.map(AttendanceRecord.fromMap).toList();

    final office = await _config.office();
    final sites = await _config.sites();

    final sessions = <DaySession>[];
    final allLocations = <LocationRecord>[];
    final allVisits = <SiteAttendance>[];
    final allStationary = <StationaryEvent>[];
    final allEvents = <StoryEvent>[];

    for (var i = 0; i < attendances.length; i++) {
      final att = attendances[i];
      final sessionIndex = i + 1;
      final session = await _attendance.sessionById(att.sessionId);
      final sLocations = await _tracking.locationsForSession(att.sessionId);
      final sVisits = await _tracking.siteVisitsForSession(att.sessionId);
      final sStationary = await _tracking.stationaryForSession(att.sessionId);

      final sStats = buildDayStats(
        locations: sLocations,
        stationaryEvents: sStationary,
        siteVisits: sVisits,
        attendance: att,
        session: session,
      );

      final sEvents = _buildEvents(
        attendance: att,
        session: session,
        visits: sVisits,
        stationary: sStationary,
        sessionPrefix: attendances.length > 1 ? 'Session $sessionIndex · ' : null,
      );

      final daySession = DaySession(
        sessionIndex: sessionIndex,
        attendance: att,
        session: session,
        siteVisits: sVisits,
        stationaryEvents: sStationary,
        locations: sLocations,
        events: sEvents,
        stats: sStats,
      );

      sessions.add(daySession);
      allLocations.addAll(sLocations);
      allVisits.addAll(sVisits);
      allStationary.addAll(sStationary);
      allEvents.addAll(sEvents);
    }

    allLocations.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    allVisits.sort((a, b) => a.checkInAt.compareTo(b.checkInAt));
    allStationary.sort((a, b) => a.startAt.compareTo(b.startAt));
    allEvents.sort((a, b) => a.time.compareTo(b.time));

    final latestAttendance = attendances.isEmpty ? null : attendances.last;
    final latestSession = sessions.isEmpty ? null : sessions.last.session;

    final overallStats = buildDayStats(
      locations: allLocations,
      stationaryEvents: allStationary,
      siteVisits: allVisits,
      attendance: latestAttendance,
      session: latestSession,
    );

    return DayStory(
      date: start,
      sessions: sessions,
      attendance: latestAttendance,
      session: latestSession,
      siteVisits: allVisits,
      stationaryEvents: allStationary,
      locations: allLocations,
      events: allEvents,
      stats: overallStats,
      office: office,
      sites: sites,
    );
  }

  List<StoryEvent> _buildEvents({
    required AttendanceRecord? attendance,
    required TrackingSession? session,
    required List<SiteAttendance> visits,
    required List<StationaryEvent> stationary,
    String? sessionPrefix,
  }) {
    final events = <StoryEvent>[];
    final prefix = sessionPrefix ?? '';

    if (attendance != null) {
      events.add(StoryEvent(
        id: '${attendance.id}-in',
        kind: StoryEventKind.officeCheckIn,
        title: '${prefix}Office check-in',
        subtitle: '${attendance.checkInAccuracy.round()} m accuracy',
        time: attendance.checkInAt,
        point: GeoPoint(attendance.checkInLatitude, attendance.checkInLongitude),
        battery: attendance.checkInBattery,
      ));
    }

    for (final visit in visits) {
      events.add(StoryEvent(
        id: '${visit.id}-in',
        kind: StoryEventKind.siteCheckIn,
        title: '${prefix}Reached ${visit.siteName}',
        subtitle: 'Site check-in · ${visit.checkInAccuracy.round()} m accuracy',
        time: visit.checkInAt,
        point: visit.checkInPoint,
        battery: visit.checkInBattery,
      ));
      if (visit.checkOutAt != null) {
        events.add(StoryEvent(
          id: '${visit.id}-out',
          kind: StoryEventKind.siteCheckOut,
          title: '${prefix}Left ${visit.siteName}',
          subtitle: 'Visit ${Fmt.duration(visit.visitDuration)}',
          time: visit.checkOutAt!,
          point: visit.checkInPoint,
          battery: visit.checkOutBattery,
          duration: visit.visitDuration,
        ));
      }
    }

    for (final event in stationary) {
      var dSeconds = event.durationSeconds;
      if (dSeconds <= 0 && event.endAt != null && event.startAt.year >= 2020) {
        dSeconds = event.endAt!.difference(event.startAt).inSeconds;
      }
      dSeconds = dSeconds.clamp(0, 86400);
      if (dSeconds < 20) continue;
      final duration = Duration(seconds: dSeconds);
      events.add(StoryEvent(
        id: event.id,
        kind: StoryEventKind.stationary,
        title: '${prefix}Stayed for ${Fmt.duration(duration)}',
        subtitle: 'Stationary · ${event.latitude.toStringAsFixed(4)}, ${event.longitude.toStringAsFixed(4)} · ${event.radiusMeters.round()} m radius',
        time: event.startAt,
        endTime: event.endAt,
        duration: duration,
        point: event.point,
        battery: event.battery,
      ));
    }

    if (attendance?.checkOutAt != null) {
      events.add(StoryEvent(
        id: '${attendance!.id}-out',
        kind: StoryEventKind.officeCheckOut,
        title: '${prefix}Office check-out',
        subtitle: 'Total ${Fmt.duration(attendance.workedDuration)}',
        time: attendance.checkOutAt!,
        point: attendance.checkOutLatitude != null
            ? GeoPoint(attendance.checkOutLatitude!, attendance.checkOutLongitude!)
            : null,
        battery: attendance.checkOutBattery,
        duration: attendance.workedDuration,
      ));
    } else if (attendance != null && attendance.status == AttendanceStatus.interrupted) {
      final at = session?.endedAt ?? attendance.checkInAt;
      events.add(StoryEvent(
        id: '${attendance.id}-interrupted',
        kind: StoryEventKind.sessionInterrupted,
        title: '${prefix}Session interrupted',
        subtitle: 'Logged out before office check-out',
        time: at,
      ));
    }

    events.sort((a, b) => a.time.compareTo(b.time));
    return events;
  }

  Future<List<DaySummary>> daySummaries(String employeeId, {int limit = 30}) async {
    final attendance = await _attendance.history(employeeId, limit: limit * 4);
    if (attendance.isEmpty) return [];

    final sessionIds = attendance.map((a) => a.sessionId).toSet().toList();
    final sessions = await _attendance.sessionsByIds(sessionIds);
    final stationaryTotals = await _tracking.stationarySecondsBySession(employeeId);
    final visitCounts = await _tracking.siteVisitCountsBySession(employeeId);
    final visits = await _tracking.recentSiteVisits(employeeId, limit: 1000);
    final stationaryEvents = await _tracking.recentStationary(employeeId, limit: 1000);

    final visitsBySession = <String, List<SiteAttendance>>{};
    for (final visit in visits) {
      visitsBySession.putIfAbsent(visit.sessionId, () => []).add(visit);
    }

    final stationaryBySession = <String, List<StationaryEvent>>{};
    for (final s in stationaryEvents) {
      stationaryBySession.putIfAbsent(s.sessionId, () => []).add(s);
    }

    final recordsByDay = <String, List<AttendanceRecord>>{};
    for (final record in attendance) {
      recordsByDay.putIfAbsent(Fmt.dayKey(record.checkInAt), () => []).add(record);
    }

    final result = <DaySummary>[];

    for (final entry in recordsByDay.entries) {
      final dayRecords = entry.value;
      dayRecords.sort((a, b) => a.checkInAt.compareTo(b.checkInAt));

      final daySessionSummaries = <DaySessionSummary>[];
      var totalDistance = 0.0;
      var totalStationary = 0;
      var totalTrackingSeconds = 0;
      var totalVisits = 0;
      var totalLocations = 0;
      final daySiteNames = <String>{};
      int? lastBattery;

      for (var i = 0; i < dayRecords.length; i++) {
        final rec = dayRecords[i];
        final sess = sessions[rec.sessionId];
        final sVisits = visitsBySession[rec.sessionId] ?? const <SiteAttendance>[];
        final sStops = stationaryBySession[rec.sessionId] ?? const <StationaryEvent>[];
        final sSiteNames = sVisits.map((v) => v.siteName).toSet().toList();
        var sDistance = sess?.distanceMeters ?? 0.0;
        if (sDistance <= 0) {
          final sLocs = await _tracking.locationsForSession(rec.sessionId);
          sDistance = computeRouteDistance(sLocs);
        }
        final sStationary = stationaryTotals[rec.sessionId] ?? 0;
        final sTracking = sess?.liveDuration.inSeconds ?? rec.workedDuration.inSeconds;

        daySiteNames.addAll(sSiteNames);
        totalDistance += sDistance;
        totalStationary += sStationary;
        totalTrackingSeconds += sTracking;
        totalVisits += visitCounts[rec.sessionId] ?? sVisits.length;
        totalLocations += sess?.locationCount ?? 0;
        lastBattery = rec.checkOutBattery ?? sess?.endBattery ?? rec.checkInBattery;

        daySessionSummaries.add(DaySessionSummary(
          sessionIndex: i + 1,
          attendance: rec,
          session: sess,
          siteVisitCount: visitCounts[rec.sessionId] ?? sVisits.length,
          distanceMeters: sDistance,
          siteNames: sSiteNames,
          siteVisits: sVisits,
          stationaryEvents: sStops,
        ));
      }

      final latestRec = dayRecords.last;

      result.add(DaySummary(
        date: Fmt.startOfDay(dayRecords.first.checkInAt),
        attendance: latestRec,
        sessions: daySessionSummaries,
        stats: DayStats(
          distanceMeters: totalDistance,
          stationarySeconds: totalStationary,
          movingSeconds: (totalTrackingSeconds - totalStationary).clamp(0, 86400 * 2).toInt(),
          siteVisits: totalVisits,
          locations: totalLocations,
          trackingSeconds: totalTrackingSeconds,
          lastBattery: lastBattery,
        ),
        siteVisitCount: totalVisits,
        stationaryCount: 0,
        siteNames: daySiteNames.toList(),
      ));
    }

    result.sort((a, b) => b.date.compareTo(a.date));
    return result.take(limit).toList();
  }

  Future<Map<String, Object?>> storageStats(String employeeId) async {
    final db = await _db.database;
    Future<int> count(String table) async {
      final value = Sqflite.firstIntValue(
        await db.rawQuery('SELECT COUNT(*) FROM $table WHERE employee_id = ?', [employeeId]),
      );
      return value ?? 0;
    }

    return {
      'attendance': await count('attendance_records'),
      'locations': await count('location_records'),
      'stationary': await count('stationary_events'),
      'visits': await count('site_attendance'),
      'battery': await count('battery_logs'),
    };
  }
}
