import '../../core/utils/formatters.dart';
import '../../core/utils/geo.dart';
import 'attendance.dart';
import 'place.dart';
import 'site_attendance.dart';
import 'tracking.dart';

enum StoryEventKind {
  officeCheckIn,
  officeCheckOut,
  siteCheckIn,
  siteCheckOut,
  stationary,
  sessionInterrupted,
  logout,
}

class StoryEvent {
  const StoryEvent({
    required this.id,
    required this.kind,
    required this.title,
    required this.subtitle,
    required this.time,
    this.endTime,
    this.duration,
    this.point,
    this.battery,
  });

  final String id;
  final StoryEventKind kind;
  final String title;
  final String subtitle;
  final DateTime time;
  final DateTime? endTime;
  final Duration? duration;
  final GeoPoint? point;
  final int? battery;

  bool get isStationary => kind == StoryEventKind.stationary;
}

class DayStats {
  const DayStats({
    this.distanceMeters = 0,
    this.stationarySeconds = 0,
    this.movingSeconds = 0,
    this.siteVisits = 0,
    this.locations = 0,
    this.trackingSeconds = 0,
    this.lastBattery,
    this.avgAccuracy,
  });

  final double distanceMeters;
  final int stationarySeconds;
  final int movingSeconds;
  final int siteVisits;
  final int locations;
  final int trackingSeconds;
  final int? lastBattery;
  final double? avgAccuracy;

  Duration get stationary => Duration(seconds: stationarySeconds);
  Duration get moving => Duration(seconds: movingSeconds);
  Duration get tracking => Duration(seconds: trackingSeconds);

  static const DayStats empty = DayStats();
}

/// A single check-in to check-out attendance interval with its tracking data.
class DaySession {
  const DaySession({
    required this.sessionIndex,
    required this.attendance,
    required this.session,
    required this.siteVisits,
    required this.stationaryEvents,
    required this.locations,
    required this.events,
    required this.stats,
  });

  final int sessionIndex;
  final AttendanceRecord attendance;
  final TrackingSession? session;
  final List<SiteAttendance> siteVisits;
  final List<StationaryEvent> stationaryEvents;
  final List<LocationRecord> locations;
  final List<StoryEvent> events;
  final DayStats stats;

  String get label => 'Session $sessionIndex';
  Duration get duration => attendance.workedDuration;
  DateTime get checkInAt => attendance.checkInAt;
  DateTime? get checkOutAt => attendance.checkOutAt;
  AttendanceStatus get status => attendance.status;
  bool get isActive => attendance.status == AttendanceStatus.active;
  bool get isCompleted => attendance.status == AttendanceStatus.completed;
  bool get isInterrupted => attendance.status == AttendanceStatus.interrupted;

  List<GeoPoint> get routePoints => locations.map((l) => l.point).toList(growable: false);

  List<SessionStep> get steps {
    final list = <SessionStep>[];
    final att = attendance;

    list.add(SessionStep(
      time: att.checkInAt,
      type: SessionStepType.checkIn,
      title: 'Clock In',
      subtitle: 'Office attendance started',
      accuracy: att.checkInAccuracy,
      battery: att.checkInBattery,
    ));

    for (final stop in stationaryEvents) {
      if (stop.durationSeconds < 20) continue;
      final locText = '${stop.point.latitude.toStringAsFixed(4)}, ${stop.point.longitude.toStringAsFixed(4)}';
      list.add(SessionStep(
        time: stop.startAt,
        type: SessionStepType.hold,
        title: 'Hold · ${Fmt.durationCompact(stop.duration)}',
        subtitle: locText,
        location: stop.point,
        duration: stop.duration,
      ));
    }

    for (final visit in siteVisits) {
      list.add(SessionStep(
        time: visit.checkInAt,
        type: SessionStepType.siteClockIn,
        title: 'Site Clock In',
        subtitle: visit.siteName,
        siteName: visit.siteName,
        accuracy: visit.checkInAccuracy,
        battery: visit.checkInBattery,
      ));
      if (visit.checkOutAt != null) {
        list.add(SessionStep(
          time: visit.checkOutAt!,
          type: SessionStepType.siteClockOut,
          title: 'Site Clock Out',
          subtitle: '${visit.siteName} (${Fmt.duration(visit.visitDuration)})',
          siteName: visit.siteName,
          duration: visit.visitDuration,
          accuracy: visit.checkOutAccuracy,
          battery: visit.checkOutBattery,
        ));
      }
    }

    if (att.checkOutAt != null) {
      list.add(SessionStep(
        time: att.checkOutAt!,
        type: SessionStepType.checkOut,
        title: 'Clock Out',
        subtitle: 'Duty finished · ${Fmt.duration(att.workedDuration)}',
        accuracy: att.checkOutAccuracy,
        battery: att.checkOutBattery,
      ));
    }

    list.sort((a, b) => a.time.compareTo(b.time));
    return list;
  }
}

class DayStory {
  const DayStory({
    required this.date,
    required this.attendance,
    required this.session,
    required this.siteVisits,
    required this.stationaryEvents,
    required this.locations,
    required this.events,
    required this.stats,
    required this.office,
    required this.sites,
    this.sessions = const [],
  });

  final DateTime date;
  final AttendanceRecord? attendance;
  final TrackingSession? session;
  final List<SiteAttendance> siteVisits;
  final List<StationaryEvent> stationaryEvents;
  final List<LocationRecord> locations;
  final List<StoryEvent> events;
  final DayStats stats;
  final OfficeConfig office;
  final List<Site> sites;
  final List<DaySession> sessions;

  bool get isEmpty =>
      sessions.isEmpty && attendance == null && locations.isEmpty && siteVisits.isEmpty;

  Site? siteById(String id) {
    for (final site in sites) {
      if (site.id == id) return site;
    }
    return null;
  }

  /// Ordered route stops used by the story map.
  List<GeoPoint> get routePoints => locations.map((l) => l.point).toList(growable: false);

  List<SessionStep> get steps {
    final att = attendance;
    if (att == null) return const [];
    final list = <SessionStep>[];

    list.add(SessionStep(
      time: att.checkInAt,
      type: SessionStepType.checkIn,
      title: 'Clock In',
      subtitle: 'Office attendance started',
      accuracy: att.checkInAccuracy,
      battery: att.checkInBattery,
    ));

    for (final stop in stationaryEvents) {
      if (stop.durationSeconds < 20) continue;
      final locText = '${stop.point.latitude.toStringAsFixed(4)}, ${stop.point.longitude.toStringAsFixed(4)}';
      list.add(SessionStep(
        time: stop.startAt,
        type: SessionStepType.hold,
        title: 'Hold · ${Fmt.durationCompact(stop.duration)}',
        subtitle: locText,
        location: stop.point,
        duration: stop.duration,
      ));
    }

    for (final visit in siteVisits) {
      list.add(SessionStep(
        time: visit.checkInAt,
        type: SessionStepType.siteClockIn,
        title: 'Site Clock In',
        subtitle: visit.siteName,
        siteName: visit.siteName,
        accuracy: visit.checkInAccuracy,
        battery: visit.checkInBattery,
      ));
      if (visit.checkOutAt != null) {
        list.add(SessionStep(
          time: visit.checkOutAt!,
          type: SessionStepType.siteClockOut,
          title: 'Site Clock Out',
          subtitle: '${visit.siteName} (${Fmt.duration(visit.visitDuration)})',
          siteName: visit.siteName,
          duration: visit.visitDuration,
          accuracy: visit.checkOutAccuracy,
          battery: visit.checkOutBattery,
        ));
      }
    }

    if (att.checkOutAt != null) {
      list.add(SessionStep(
        time: att.checkOutAt!,
        type: SessionStepType.checkOut,
        title: 'Clock Out',
        subtitle: 'Duty finished · ${Fmt.duration(att.workedDuration)}',
        accuracy: att.checkOutAccuracy,
        battery: att.checkOutBattery,
      ));
    }

    list.sort((a, b) => a.time.compareTo(b.time));
    return list;
  }

  /// Returns a scoped [DayStory] representing only the chosen session.
  DayStory forSession(int index) {
    for (final s in sessions) {
      if (s.sessionIndex == index) {
        final sessionSiteIds = s.siteVisits.map((v) => v.siteId).toSet();
        final sessionSites =
            sites.where((st) => sessionSiteIds.contains(st.id)).toList();
        return DayStory(
          date: date,
          sessions: [s],
          attendance: s.attendance,
          session: s.session,
          siteVisits: s.siteVisits,
          stationaryEvents: s.stationaryEvents,
          locations: s.locations,
          events: s.events,
          stats: s.stats,
          office: office,
          sites: sessionSites,
        );
      }
    }
    return this;
  }

  DaySession? sessionByIndex(int index) {
    for (final s in sessions) {
      if (s.sessionIndex == index) return s;
    }
    return null;
  }
}

/// Lightweight summary of a session for historical list cards.
class DaySessionSummary {
  const DaySessionSummary({
    required this.sessionIndex,
    required this.attendance,
    this.session,
    this.siteVisitCount = 0,
    this.distanceMeters = 0,
    this.siteNames = const [],
    this.siteVisits = const [],
    this.stationaryEvents = const [],
  });

  final int sessionIndex;
  final AttendanceRecord attendance;
  final TrackingSession? session;
  final int siteVisitCount;
  final double distanceMeters;
  final List<String> siteNames;
  final List<SiteAttendance> siteVisits;
  final List<StationaryEvent> stationaryEvents;

  String get label => 'Session $sessionIndex';
  Duration get duration => attendance.workedDuration;
  DateTime get checkInAt => attendance.checkInAt;
  DateTime? get checkOutAt => attendance.checkOutAt;
  AttendanceStatus get status => attendance.status;

  /// Ordered step-by-step history events for this session:
  /// check-in -> hold(Location-time) -> site clock in -> site clock out -> hold -> clock out
  List<SessionStep> get steps {
    final list = <SessionStep>[];
    // 1. Clock in
    list.add(SessionStep(
      time: checkInAt,
      type: SessionStepType.checkIn,
      title: 'Clock In',
      subtitle: 'Office attendance started',
      location: attendance.checkInPoint,
      accuracy: attendance.checkInAccuracy,
      battery: attendance.checkInBattery,
    ));

    // 2. Holds (Stationary events)
    for (final stop in stationaryEvents) {
      if (stop.durationSeconds < 20) continue;
      final locText = '${stop.point.latitude.toStringAsFixed(4)}, ${stop.point.longitude.toStringAsFixed(4)}';
      list.add(SessionStep(
        time: stop.startAt,
        type: SessionStepType.hold,
        title: 'Hold · ${Fmt.durationCompact(stop.duration)}',
        subtitle: locText,
        location: stop.point,
        duration: stop.duration,
      ));
    }

    // 3. Site visits
    for (final visit in siteVisits) {
      list.add(SessionStep(
        time: visit.checkInAt,
        type: SessionStepType.siteClockIn,
        title: 'Site Clock In',
        subtitle: visit.siteName,
        siteName: visit.siteName,
        location: visit.checkInPoint,
        accuracy: visit.checkInAccuracy,
        battery: visit.checkInBattery,
      ));
      if (visit.checkOutAt != null) {
        list.add(SessionStep(
          time: visit.checkOutAt!,
          type: SessionStepType.siteClockOut,
          title: 'Site Clock Out',
          subtitle: '${visit.siteName} (${Fmt.duration(visit.visitDuration)})',
          siteName: visit.siteName,
          location: visit.checkInPoint,
          duration: visit.visitDuration,
          accuracy: visit.checkOutAccuracy,
          battery: visit.checkOutBattery,
        ));
      }
    }

    // 4. Clock out
    if (checkOutAt != null) {
      list.add(SessionStep(
        time: checkOutAt!,
        type: SessionStepType.checkOut,
        title: 'Clock Out',
        subtitle: 'Duty finished · ${Fmt.duration(duration)}',
        location: attendance.checkOutPoint,
        accuracy: attendance.checkOutAccuracy,
        battery: attendance.checkOutBattery,
      ));
    }

    list.sort((a, b) => a.time.compareTo(b.time));
    return list;
  }
}

enum SessionStepType {
  checkIn,
  hold,
  siteClockIn,
  siteClockOut,
  checkOut,
}

class SessionStep {
  const SessionStep({
    required this.time,
    required this.type,
    required this.title,
    required this.subtitle,
    this.location,
    this.siteName,
    this.duration,
    this.accuracy,
    this.battery,
  });

  final DateTime time;
  final SessionStepType type;
  final String title;
  final String subtitle;
  final GeoPoint? location;
  final String? siteName;
  final Duration? duration;
  final double? accuracy;
  final int? battery;
}

/// Aggregated row used by the history list.
class DaySummary {
  const DaySummary({
    required this.date,
    required this.attendance,
    required this.stats,
    required this.siteVisitCount,
    required this.stationaryCount,
    required this.siteNames,
    this.sessions = const [],
  });

  final DateTime date;
  final AttendanceRecord attendance;
  final DayStats stats;
  final int siteVisitCount;
  final int stationaryCount;
  final List<String> siteNames;
  final List<DaySessionSummary> sessions;

  bool get completed => attendance.status == AttendanceStatus.completed;
  int get sessionCount => sessions.isNotEmpty ? sessions.length : 1;
}

/// Utility that turns raw location breadcrumbs into a distance figure while
/// rejecting obvious GPS teleports.
double computeRouteDistance(List<LocationRecord> ordered) {
  if (ordered.length < 2) return 0;
  var total = 0.0;
  LocationRecord? previous;
  for (final record in ordered) {
    if (record.accuracy > 100) continue;
    if (previous != null) {
      final d = distanceBetween(previous.point, record.point);
      final seconds = record.recordedAt.difference(previous.recordedAt).inSeconds.abs();
      final impliedSpeed = seconds == 0 ? double.infinity : d / seconds; // m/s
      final isPlausible = seconds == 0 ? (d < 50) : (impliedSpeed < 65);
      if (d < 100000 && (isPlausible || d < 25000)) total += d;
    }
    previous = record;
  }
  return total;
}

/// Total seconds covered by stationary events (clipped to the day window).
int totalStationarySeconds(List<StationaryEvent> events) {
  var seconds = 0;
  for (final event in events) {
    var dur = event.durationSeconds;
    if (dur <= 0 && event.endAt != null && event.startAt.year >= 2020) {
      dur = event.endAt!.difference(event.startAt).inSeconds;
    }
    seconds += dur.clamp(0, 86400);
  }
  return seconds.clamp(0, 86400 * 2);
}

DayStats buildDayStats({
  required List<LocationRecord> locations,
  required List<StationaryEvent> stationaryEvents,
  required List<SiteAttendance> siteVisits,
  AttendanceRecord? attendance,
  TrackingSession? session,
}) {
  final ordered = [...locations]..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
  final trackingSeconds = session?.liveDuration.inSeconds ??
      (attendance != null ? attendance.workedDuration.inSeconds : 0);
  final stationary = totalStationarySeconds(stationaryEvents)
      .clamp(0, trackingSeconds > 0 ? trackingSeconds : 86400);
  final avgAccuracy = ordered.isEmpty
      ? null
      : ordered.map((l) => l.accuracy).reduce((a, b) => a + b) / ordered.length;
  return DayStats(
    distanceMeters: computeRouteDistance(ordered),
    stationarySeconds: stationary,
    movingSeconds: (trackingSeconds - stationary).clamp(0, 86400).toInt(),
    siteVisits: siteVisits.length,
    locations: ordered.length,
    trackingSeconds: trackingSeconds,
    lastBattery: ordered.isNotEmpty ? ordered.last.battery : session?.endBattery,
    avgAccuracy: avgAccuracy,
  );
}
