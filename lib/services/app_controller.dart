import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../core/config/app_config.dart';
import '../core/errors/app_exception.dart';
import '../core/utils/formatters.dart';
import '../core/utils/geo.dart';
import '../data/db/app_database.dart';
import '../data/models/attendance.dart';
import '../data/models/day_story.dart';
import '../data/models/employee.dart';
import '../data/models/place.dart';
import '../data/models/site_attendance.dart';
import '../data/models/tracking.dart';
import '../data/repositories/attendance_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/config_repository.dart';
import '../data/repositories/history_repository.dart';
import '../data/repositories/tracking_repository.dart';
import 'battery_service.dart';
import 'geo_address_service.dart';
import 'location_service.dart';
import 'session_store.dart';
import 'stationary_detector.dart';
import 'tracking/demo_location.dart';
import 'tracking/native_tracking_platform.dart';
import 'tracking/simulated_tracking_platform.dart';
import 'tracking/tracking_platform.dart';

/// The single source of truth for the signed-in employee's day.
///
/// It owns the attendance state machine, the tracking platform, stationary
/// detection, battery sampling and local persistence.
class AppController extends ChangeNotifier {
  AppController({
    AppDatabase? database,
    TrackingPlatform? platform,
    LocationService? locationService,
    BatteryService? batteryService,
  })  : _db = database ?? AppDatabase.instance,
        _location = locationService ?? LocationService(),
        _batteryService = batteryService ?? BatteryService() {
    _authRepo = AuthRepository(_db);
    _configRepo = ConfigRepository(_db);
    _attendanceRepo = AttendanceRepository(_db);
    _trackingRepo = TrackingRepository(_db);
    _historyRepo = HistoryRepository(_db);
    _platform = platform ??
        (AppConfig.hasNativeTracking
            ? NativeTrackingPlatform()
            : SimulatedTrackingPlatform(batteryProvider: () => _batteryService.currentLevel()));
    _eventSub = _platform.events.listen(_onPlatformEvent);
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => _onTick());
  }

  final AppDatabase _db;
  final LocationService _location;
  final BatteryService _batteryService;
  final SessionStore _store = SessionStore();
  final Uuid _uuid = const Uuid();

  late final AuthRepository _authRepo;
  late final ConfigRepository _configRepo;
  late final AttendanceRepository _attendanceRepo;
  late final TrackingRepository _trackingRepo;
  late final HistoryRepository _historyRepo;
  late final TrackingPlatform _platform;

  StreamSubscription<Map<String, dynamic>>? _eventSub;
  Timer? _ticker;

  // ── Observable state ─────────────────────────────────────────────────────
  bool booting = true;
  bool busy = false;
  bool onboardingSeen = false;
  Employee? employee;
  OfficeConfig? office;
  List<Site> sites = const [];
  AttendanceRecord? attendance; // open session (active or interrupted)
  AttendanceRecord? todayAttendance; // latest record for today
  List<DaySession> todaySessions = const []; // all sessions today in chronological order
  DayStory? todayStory;
  TrackingSession? session;
  bool tracking = false;
  bool interrupted = false;
  String? notice;
  String? error;
  int battery = 87;
  GeoPoint? position;
  double accuracy = 0;
  DateTime? positionAt;
  bool positionSimulated = false;
  String? currentAddress;
  PermissionReport? permissions;
  List<SiteAttendance> siteVisits = const [];
  List<SiteAttendance> todayVisits = const [];
  SiteAttendance? activeSiteVisit;
  List<StationaryEvent> stationaryEvents = const [];
  List<StationaryEvent> todayStationary = const [];
  List<LocationRecord> recentLocations = const [];
  List<BatteryLog> batteryLogs = const [];
  DayStats todayStats = DayStats.empty;
  List<DaySummary> history = const [];
  int pendingSync = 0;

  // ── Internals ────────────────────────────────────────────────────────────
  LocationRecord? _lastLocation;
  StationaryDetector? _detector;
  DateTime? _lastBatteryLogAt;
  DateTime? _lastTodayRefresh;
  DateTime? _lastDrain;
  DateTime? _lastBatteryRefresh;
  DateTime? _lastKeepAlive;
  int _lastLoggedBattery = -1;
  bool _draining = false;
  bool _refreshingToday = false;
  bool _disposed = false;

  // ── Getters ──────────────────────────────────────────────────────────────
  bool get isMobile => _location.isMobile;
  bool get simulation => !AppConfig.hasNativeTracking;
  bool get isCheckedIn => attendance?.status == AttendanceStatus.active;
  bool get hasOpenAttendance => attendance != null;
  bool get isTrackingLive => tracking && session != null && session!.status.isActive;
  bool get canTrack => permissions?.canTrack ?? !isMobile;
  bool get hasActiveSiteVisit => activeSiteVisit != null;

  Site? get activeSite {
    final visit = activeSiteVisit;
    if (visit == null) return null;
    for (final site in sites) {
      if (site.id == visit.siteId) return site;
    }
    return null;
  }

  double? get distanceToOffice {
    final point = position;
    final off = office;
    if (point == null || off == null) return null;
    return distanceBetween(point, off.point);
  }

  double? distanceToSite(Site site) {
    final point = position;
    if (point == null) return null;
    return distanceBetween(point, site.point);
  }

  bool isInsideOffice(double distance) => withinGeofence(
        distanceMeters: distance,
        radiusMeters: office?.radiusMeters ?? 0,
        accuracyMeters: accuracy,
      );

  bool isInsideSite(Site site, double distance) => withinGeofence(
        distanceMeters: distance,
        radiusMeters: site.radiusMeters,
        accuracyMeters: accuracy,
      );

  int get stationaryTodayCount => todayStationary.where((e) => e.durationSeconds >= 20).length;

  // ── Boot ─────────────────────────────────────────────────────────────────
  Future<void> bootstrap() async {
    try {
      onboardingSeen = await _store.onboardingSeen();
      office = await _configRepo.office();
      sites = await _configRepo.sites();
      if (office != null) {
        GeoAddressService.instance.registerOffice(office!);
      }
      GeoAddressService.instance.registerSites(sites);
      battery = await _batteryService.refresh();
      permissions = await _location.checkPermissions();

      final storedId = await _store.employeeId();
      if (storedId != null) {
        final emp = await _authRepo.byId(storedId);
        if (emp != null) {
          employee = emp;
          await _loadEmployeeContext(emp);
        } else {
          await _store.clearEmployeeId();
        }
      }

      if (employee == null) {
        if (!isMobile) {
          await refreshCurrentPosition(silent: true);
        }
        await refreshToday();
      }

      await _drainQueue();
    } catch (e) {
      error = 'We could not restore your session. $e';
    } finally {
      booting = false;
      _safeNotify();
    }
  }

  Future<void> _loadEmployeeContext(Employee emp) async {
    employee = emp;
    final open = await _attendanceRepo.openAttendance(emp.id);
    attendance = open;
    interrupted = open?.status == AttendanceStatus.interrupted;
    if (open != null) {
      session = await _attendanceRepo.sessionById(open.sessionId);
      _lastLocation = await _trackingRepo.lastLocation(open.sessionId);
      if (_lastLocation != null) {
        position = _lastLocation!.point;
        accuracy = _lastLocation!.accuracy;
        positionAt = _lastLocation!.recordedAt;
        positionSimulated = _lastLocation!.source == 'simulated';
      }
      if (session != null && session!.status.isActive) {
        final running = await _platform.isTracking();
        tracking = running || await _platform.start(_configFor(session!));
        if (!tracking) {
          notice = 'Background tracking is paused. Resume it from the attendance screen.';
        }
        await _attachDetector();
      }
    } else {
      session = null;
      _lastLocation = null;
      tracking = false;
      _detector = null;
    }
    await _refreshSessionCollections();
    await refreshToday();
  }

  Future<void> login(String identifier, String password) async {
    _setBusy(true);
    try {
      final emp = await _authRepo.login(identifier, password);
      if (emp == null) {
        throw AppException('Invalid employee ID or password. Demo password is ${AppConfig.demoPassword}.');
      }
      employee = emp;
      await _store.saveEmployeeId(emp.id);
      await _loadEmployeeContext(emp);
      notice = null;
      error = null;
    } finally {
      _setBusy(false);
    }
  }

  Future<void> logout() async {
    _setBusy(true);
    try {
      LocationFix? fix;
      try {
        fix = await _location.currentFix();
      } catch (_) {}
      final level = await _batteryService.refresh();
      battery = level;
      final open = session;
      if (open != null) {
        if (activeSiteVisit != null) {
          await _finalizeSiteVisit(activeSiteVisit!, context: 'logout', fix: fix);
        }
        await _closeActiveStationary();
        await _platform.stop();
        tracking = false;
        final now = DateTime.now();
        final a = attendance;
        final s = session;
        if (a != null && s != null) {
          final interruptedAttendance = a.copyWith(status: AttendanceStatus.interrupted);
          final interruptedSession = s.copyWith(
            endedAt: now,
            status: SessionStatus.interrupted,
            endBattery: level,
            lastLatitude: fix?.point.latitude,
            lastLongitude: fix?.point.longitude,
            lastUpdateAt: fix?.timestamp,
          );
          await _attendanceRepo.markSessionInterrupted(
            attendance: interruptedAttendance,
            session: interruptedSession,
            batteryLog: BatteryLog(
              id: _uuid.v4(),
              employeeId: employee!.id,
              sessionId: s.id,
              level: level,
              recordedAt: now,
              context: 'logout',
            ),
          );
        }
      }
      await _store.clearEmployeeId();
      _resetSessionState();
      employee = null;
      attendance = null;
      todayAttendance = null;
      todaySessions = const [];
      todayStory = null;
      todayVisits = const [];
      todayStationary = const [];
      recentLocations = const [];
      todayStats = DayStats.empty;
      history = const [];
      batteryLogs = const [];
      notice = null;
      _safeNotify();
    } finally {
      _setBusy(false);
    }
  }

  // ── Attendance workflow ──────────────────────────────────────────────────
  Future<void> officeCheckIn() async {
    final emp = employee;
    final off = office;
    if (emp == null || off == null) throw AppException('Sign in before checking in.');
    if (attendance != null) {
      if (attendance!.status == AttendanceStatus.active) {
        throw AppException('You are already checked in.');
      }
      throw AppException(
        'Your previous session was interrupted. Resume or close it before starting a new day.',
        code: 'interrupted_session',
      );
    }

    _setBusy(true);
    try {
      await _ensureTrackingPermissions();
      // Attendance is not location-locked: stamp whatever fix the employee has,
      // whether they are at the office, at home or on the road.
      final fix = await _location.currentFix();
      final level = await _batteryService.refresh();
      battery = level;

      final now = DateTime.now();
      final attendanceId = _uuid.v4();
      final sessionId = _uuid.v4();
      final platform = isMobile ? defaultTargetPlatform.name : 'simulated';
      final record = AttendanceRecord(
        id: attendanceId,
        employeeId: emp.id,
        sessionId: sessionId,
        officeId: off.id,
        checkInAt: now,
        checkInLatitude: fix.point.latitude,
        checkInLongitude: fix.point.longitude,
        checkInAccuracy: fix.accuracy,
        checkInBattery: level,
        status: AttendanceStatus.active,
        createdAt: now,
      );
      final track = TrackingSession(
        id: sessionId,
        employeeId: emp.id,
        attendanceId: attendanceId,
        officeId: off.id,
        startedAt: now,
        status: SessionStatus.active,
        platform: platform,
        startBattery: level,
        createdAt: now,
      );

      final started = await _platform.start(_configFor(track));
      if (!started) {
        throw AppException(
          'Check-in could not start background tracking. Verify permissions and try again.',
          code: 'tracking_start_failed',
        );
      }
      try {
        await _attendanceRepo.startSession(
          attendance: record,
          session: track,
          batteryLog: BatteryLog(
            id: _uuid.v4(),
            employeeId: emp.id,
            sessionId: sessionId,
            level: level,
            recordedAt: now,
            context: 'check_in',
          ),
        );
      } catch (e) {
        await _platform.stop();
        rethrow;
      }

      attendance = record;
      session = track;
      tracking = true;
      interrupted = false;
      position = fix.point;
      accuracy = fix.accuracy;
      positionAt = fix.timestamp;
      positionSimulated = fix.simulated;
      _lastLocation = null;
      _lastBatteryLogAt = now;
      _lastLoggedBattery = level;
      await _attachDetector();
      notice = 'Check-in recorded. Background tracking is live.';
      await refreshToday();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> officeCheckOut() async {
    final a = attendance;
    final s = session;
    if (a == null || s == null) throw AppException('No active attendance session.');
    if (a.status == AttendanceStatus.interrupted) {
      throw AppException('This session is interrupted. Resume it before checking out.');
    }

    _setBusy(true);
    try {
      LocationFix? fix;
      try {
        fix = await _location.currentFix();
      } catch (_) {}
      if (activeSiteVisit != null) {
        await _finalizeSiteVisit(activeSiteVisit!, context: 'office_check_out', fix: fix);
      }
      await _closeActiveStationary();
      final level = await _batteryService.refresh();
      battery = level;
      await _platform.stop();
      tracking = false;

      final now = DateTime.now();
      final duration = now.difference(a.checkInAt).inSeconds.clamp(0, 86400 * 2).toInt();
      final closed = a.copyWith(
        checkOutAt: now,
        checkOutLatitude: fix?.point.latitude,
        checkOutLongitude: fix?.point.longitude,
        checkOutAccuracy: fix?.accuracy,
        checkOutBattery: level,
        status: AttendanceStatus.completed,
        totalDurationSeconds: duration,
      );
      final closedSession = s.copyWith(
        endedAt: now,
        status: SessionStatus.completed,
        endBattery: level,
        lastLatitude: fix?.point.latitude,
        lastLongitude: fix?.point.longitude,
        lastUpdateAt: fix?.timestamp ?? s.lastUpdateAt,
      );
      await _attendanceRepo.closeSession(
        attendance: closed,
        session: closedSession,
        batteryLog: BatteryLog(
          id: _uuid.v4(),
          employeeId: a.employeeId,
          sessionId: s.id,
          level: level,
          recordedAt: now,
          context: 'check_out',
        ),
      );

      _resetSessionState();
      notice = 'Check-out complete. Background tracking stopped.';
      await refreshToday();
    } finally {
      _setBusy(false);
    }
  }

  /// Finds which assigned site (if any) the user is currently inside.
  Site? findSiteUserIsInside() {
    final p = position;
    if (p == null) return null;
    for (final s in sites) {
      final d = distanceToSite(s);
      if (d != null && isInsideSite(s, d)) {
        return s;
      }
    }
    return null;
  }

  /// Finds the closest site to the user, with its distance.
  ({Site site, double distance})? findClosestSite() {
    final p = position;
    if (p == null || sites.isEmpty) return null;
    Site? closest;
    var minDistance = double.infinity;
    for (final s in sites) {
      final d = distanceToSite(s);
      if (d != null && d < minDistance) {
        minDistance = d;
        closest = s;
      }
    }
    if (closest == null) return null;
    return (site: closest, distance: minDistance);
  }

  Future<void> siteCheckIn(Site site) async {
    final emp = employee;
    final s = session;
    if (emp == null || s == null) throw AppException('Check in for the day before visiting a site.');
    if (attendance?.status != AttendanceStatus.active) {
      throw AppException('Your attendance session is not active.');
    }
    if (activeSiteVisit != null) {
      throw AppException('You are still checked in at ${activeSiteVisit!.siteName}. Check out first.');
    }

    _setBusy(true);
    try {
      final fix = await _location.currentFix();
      final distance = distanceBetween(fix.point, site.point);
      if (!isInsideSite(site, distance)) {
        throw AppException(
          'You are not inside ${site.name}. You are ${Fmt.distance(distance)} away. Site check-in is only allowed when inside the site geofence (${site.radiusMeters.round()} m).',
        );
      }
      final level = await _batteryService.refresh();
      battery = level;
      final now = DateTime.now();
      final visit = SiteAttendance(
        id: _uuid.v4(),
        employeeId: emp.id,
        sessionId: s.id,
        siteId: site.id,
        siteName: site.name,
        checkInAt: now,
        checkInLatitude: fix.point.latitude,
        checkInLongitude: fix.point.longitude,
        checkInAccuracy: fix.accuracy,
        checkInBattery: level,
        status: SiteVisitStatus.active,
      );
      await _trackingRepo.insertSiteVisit(visit);
      await _trackingRepo.insertBatteryLog(BatteryLog(
        id: _uuid.v4(),
        employeeId: emp.id,
        sessionId: s.id,
        level: level,
        recordedAt: now,
        context: 'site_check_in',
      ));
      activeSiteVisit = visit;
      siteVisits = [...siteVisits, visit];
      position = fix.point;
      accuracy = fix.accuracy;
      positionAt = fix.timestamp;
      positionSimulated = fix.simulated;
      notice = 'Site check-in recorded at ${site.name}. Tracking continues.';
      await refreshToday();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> siteCheckOut() async {
    final visit = activeSiteVisit;
    if (visit == null) throw AppException('There is no active site visit to check out from.');
    _setBusy(true);
    try {
      LocationFix? fix;
      try {
        fix = await _location.currentFix();
      } catch (_) {}
      await _finalizeSiteVisit(visit, context: 'site_check_out', fix: fix);
      notice = 'Site check-out recorded. Overall tracking is still running.';
      await refreshToday();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> _finalizeSiteVisit(SiteAttendance visit, {required String context, LocationFix? fix}) async {
    final level = await _batteryService.refresh();
    battery = level;
    final now = DateTime.now();
    final updated = visit.copyWith(
      checkOutAt: now,
      checkOutLatitude: fix?.point.latitude,
      checkOutLongitude: fix?.point.longitude,
      checkOutAccuracy: fix?.accuracy,
      checkOutBattery: level,
      durationSeconds: now.difference(visit.checkInAt).inSeconds.clamp(0, 86400 * 2).toInt(),
      status: SiteVisitStatus.completed,
    );
    await _trackingRepo.updateSiteVisit(updated);
    await _trackingRepo.insertBatteryLog(BatteryLog(
      id: _uuid.v4(),
      employeeId: visit.employeeId,
      sessionId: visit.sessionId,
      level: level,
      recordedAt: now,
      context: context,
    ));
    activeSiteVisit = null;
    siteVisits = [
      for (final item in siteVisits) item.id == updated.id ? updated : item,
    ];
  }

  // ── Interrupted session recovery ─────────────────────────────────────────
  Future<void> resumeInterruptedSession() async {
    final a = attendance;
    final s = session;
    if (a == null || s == null) throw AppException('No interrupted session found.');
    _setBusy(true);
    try {
      final resumedAttendance = a.copyWith(status: AttendanceStatus.active);
      final resumedSession = s.copyWith(status: SessionStatus.active, clearEndedAt: true);
      await _attendanceRepo.updateAttendance(resumedAttendance);
      await _attendanceRepo.updateSession(resumedSession);
      attendance = resumedAttendance;
      session = resumedSession;
      interrupted = false;
      final started = await _platform.start(_configFor(resumedSession));
      tracking = started;
      if (!started) {
        throw AppException('Tracking could not be resumed. Check permissions and try again.');
      }
      await _attachDetector();
      notice = 'Session resumed. Tracking is live again.';
      await refreshToday();
    } finally {
      _setBusy(false);
    }
  }

  Future<void> closeInterruptedSession() async {
    final a = attendance;
    final s = session;
    if (a == null || s == null) throw AppException('No interrupted session found.');
    _setBusy(true);
    try {
      final level = await _batteryService.refresh();
      final now = DateTime.now();
      final closed = a.copyWith(
        checkOutAt: now,
        status: AttendanceStatus.closedManually,
        checkOutBattery: level,
        totalDurationSeconds: now.difference(a.checkInAt).inSeconds.clamp(0, 86400 * 2).toInt(),
      );
      final closedSession = s.copyWith(endedAt: now, status: SessionStatus.completed, endBattery: level);
      await _attendanceRepo.closeSession(
        attendance: closed,
        session: closedSession,
        batteryLog: BatteryLog(
          id: _uuid.v4(),
          employeeId: a.employeeId,
          sessionId: s.id,
          level: level,
          recordedAt: now,
          context: 'session_closed',
        ),
      );
      _resetSessionState();
      notice = 'Interrupted session closed. Its records are preserved locally.';
      await refreshToday();
    } finally {
      _setBusy(false);
    }
  }

  // ── Location + permissions ───────────────────────────────────────────────
  Future<PermissionReport> requestPermissions() async {
    final report = await _location.requestPermissions();
    permissions = report;
    _safeNotify();
    return report;
  }

  Future<void> refreshPermissions() async {
    permissions = await _location.checkPermissions();
    _safeNotify();
  }

  Future<void> openAppSettingsPage() => _location.openAppSettingsPage();
  Future<void> openLocationSettingsPage() => _location.openLocationSettingsPage();

  Future<void> refreshCurrentPosition({bool silent = false}) async {
    try {
      final fix = await _location.currentFix();
      position = fix.point;
      accuracy = fix.accuracy;
      positionAt = fix.timestamp;
      positionSimulated = fix.simulated;
      _resolveCurrentAddress();
      _safeNotify();
    } on AppException {
      if (!silent) rethrow;
    }
  }

  Future<void> _ensureTrackingPermissions() async {
    final report = await _location.requestPermissions();
    permissions = report;
    if (!report.locationServiceEnabled) {
      throw AppException('Turn on location services (GPS) to check in.', code: 'gps_off');
    }
    if (!report.foreground) {
      throw AppException('Location permission is required to verify your attendance.', code: 'permission_denied');
    }
    if (!report.canTrack) {
      throw AppException(
        'Background location ("Always allow") is required so tracking continues when the app is minimized.',
        code: 'background_denied',
      );
    }
    _safeNotify();
  }

  // ── History ──────────────────────────────────────────────────────────────
  Future<void> refreshToday() async {
    final emp = employee;
    if (emp == null) {
      _safeNotify();
      return;
    }
    if (_refreshingToday) return;
    _refreshingToday = true;
    try {
      final story = await _historyRepo.dayStory(emp.id, DateTime.now());
      todayStory = story;
      todaySessions = story.sessions;
      todayAttendance = story.attendance;
      todayStats = story.stats;
      todayVisits = story.siteVisits;
      todayStationary = story.stationaryEvents;
      final all = story.locations;
      recentLocations = all.length <= 12 ? all.reversed.toList() : all.sublist(all.length - 12).reversed.toList();
      batteryLogs = await _trackingRepo.batteryForDay(emp.id, Fmt.startOfDay(DateTime.now()), Fmt.endOfDay(DateTime.now()));
      history = await _historyRepo.daySummaries(emp.id, limit: 30);
      pendingSync = await _trackingRepo.pendingRecordCount();
      _lastTodayRefresh = DateTime.now();
      _safeNotify();
    } finally {
      _refreshingToday = false;
    }
  }

  Future<DayStory> storyFor(DateTime date) async {
    final emp = employee;
    if (emp == null) throw AppException('Not signed in.');
    return _historyRepo.dayStory(emp.id, date);
  }

  Future<Map<String, Object?>> storageStats() async {
    final emp = employee;
    if (emp == null) return {};
    return _historyRepo.storageStats(emp.id);
  }

  Future<void> markOnboardingSeen() async {
    await _store.markOnboardingSeen();
    onboardingSeen = true;
    _safeNotify();
  }

  void dismissNotice() {
    if (notice == null) return;
    notice = null;
    _safeNotify();
  }

  void dismissError() {
    if (error == null) return;
    error = null;
    _safeNotify();
  }

  Future<void> onAppResume() async {
    if (booting) return;
    try {
      battery = await _batteryService.refresh();
      permissions = await _location.checkPermissions();
      await _drainQueue();
      await refreshToday();
      await _ensureTrackingAlive();
    } catch (_) {}
    _safeNotify();
  }

  // ── Demo controls ────────────────────────────────────────────────────────
  Future<void> demoJumpToOffice() async {
    final off = office;
    if (off == null) return;
    final platform = _platform;
    if (platform is SimulatedTrackingPlatform) {
      await platform.jumpToOffice();
    } else {
      DemoLocationProvider.instance.moveTo(off.point);
    }
    position = off.point;
    accuracy = 7;
    positionAt = DateTime.now();
    positionSimulated = true;
    _safeNotify();
  }

  Future<void> demoJumpToSite(Site site) async {
    final platform = _platform;
    if (platform is SimulatedTrackingPlatform) {
      await platform.jumpTo(site.point);
    } else {
      DemoLocationProvider.instance.moveTo(site.point);
    }
    position = site.point;
    accuracy = 7;
    positionAt = DateTime.now();
    positionSimulated = true;
    _safeNotify();
  }

  // ── Platform events ──────────────────────────────────────────────────────
  void _onPlatformEvent(Map<String, dynamic> event) {
    if (_disposed) return;
    final type = event['type']?.toString();
    if (type == 'location' || (type == null && event.containsKey('recordedAt'))) {
      unawaited(_ingestLocation(_locationFromMap(event)));
      return;
    }
    if (type == 'stationary_started' || type == 'stationary_updated' || type == 'stationary_completed') {
      unawaited(_applyStationary(_stationaryFromMap(event)));
      return;
    }
    if (type == 'battery') {
      final level = _asInt(event['level'], battery);
      if (level > 0) {
        battery = level;
        _safeNotify();
      }
      return;
    }
    if (type == 'status') {
      tracking = event['tracking'] == true;
      _safeNotify();
      return;
    }
    if (type == 'error') {
      notice = event['message']?.toString() ?? 'Tracking reported an error.';
      _safeNotify();
    }
  }

  Future<void> _ingestLocation(LocationRecord record) async {
    final current = session;
    if (current == null || record.sessionId != current.id) return;

    var delta = 0.0;
    final previous = _lastLocation;
    if (previous != null && !record.recordedAt.isBefore(previous.recordedAt)) {
      final distance = distanceBetween(previous.point, record.point);
      final seconds = record.recordedAt.difference(previous.recordedAt).inSeconds.abs();
      final speed = seconds == 0 ? double.infinity : distance / seconds;
      // Accept plausible movement up to 100 km, or up to 65 m/s (~234 km/h)
      final isPlausibleSpeed = seconds == 0 ? (distance < 50) : (speed < 65);
      if (distance < 100000 && (isPlausibleSpeed || distance < 25000)) delta = distance;
    }

    final inserted = await _trackingRepo.appendLocation(record, deltaMeters: delta);
    if (!inserted) return;

    final isNewest = _lastLocation == null || !record.recordedAt.isBefore(_lastLocation!.recordedAt);
    if (isNewest) {
      _lastLocation = record;
      position = record.point;
      accuracy = record.accuracy;
      positionAt = record.recordedAt;
      positionSimulated = record.source == 'simulated';
      _resolveCurrentAddress();
      session = current.copyWith(
        locationCount: current.locationCount + 1,
        distanceMeters: current.distanceMeters + delta,
        lastLatitude: record.latitude,
        lastLongitude: record.longitude,
        lastUpdateAt: record.recordedAt,
      );
      if (record.battery > 0) battery = record.battery;
    }

    final update = _detector?.feed(record);
    if (update != null && !update.isEmpty && !_platform.supportsNativeStationary) {
      if (update.started != null) await _applyStationary(update.started!);
      if (update.updated != null) await _applyStationary(update.updated!);
      if (update.completed != null) await _applyStationary(update.completed!);
    }

    await _maybeLogBattery(record.battery, record.recordedAt, 'tracking');
    _safeNotify();

    if (_lastTodayRefresh == null || DateTime.now().difference(_lastTodayRefresh!) > const Duration(seconds: 25)) {
      unawaited(refreshToday());
    }
  }

  Future<void> _applyStationary(StationaryEvent event) async {
    // Reject events with uninitialized coordinates — try to repair first.
    var ev = event;
    if (ev.latitude.abs() < 0.0001 && ev.longitude.abs() < 0.0001) {
      final pos = position;
      if (pos != null) {
        ev = StationaryEvent(
          id: ev.id,
          employeeId: ev.employeeId,
          sessionId: ev.sessionId,
          latitude: pos.latitude,
          longitude: pos.longitude,
          startAt: ev.startAt,
          endAt: ev.endAt,
          durationSeconds: ev.durationSeconds,
          accuracy: ev.accuracy,
          battery: ev.battery,
          status: ev.status,
          radiusMeters: ev.radiusMeters,
        );
      } else {
        // No position available to repair — discard entirely.
        return;
      }
    }

    if (ev.status == StationaryStatus.completed) {
      await _trackingRepo.upsertStationary(ev);
    } else {
      await _trackingRepo.upsertStationary(ev);
    }
    final list = [...stationaryEvents];
    final index = list.indexWhere((e) => e.id == ev.id);
    if (index >= 0) {
      list[index] = ev;
    } else {
      list.add(ev);
    }
    list.sort((a, b) => a.startAt.compareTo(b.startAt));
    stationaryEvents = list;
    _safeNotify();
  }

  Future<void> _maybeLogBattery(int level, DateTime at, String context) async {
    if (level <= 0) return;
    final due = _lastBatteryLogAt == null ||
        at.difference(_lastBatteryLogAt!) >= AppConfig.batteryLogInterval ||
        (level - _lastLoggedBattery).abs() >= 5;
    if (!due) return;
    _lastBatteryLogAt = at;
    _lastLoggedBattery = level;
    final emp = employee;
    final s = session;
    if (emp == null) return;
    await _trackingRepo.insertBatteryLog(BatteryLog(
      id: _uuid.v4(),
      employeeId: emp.id,
      sessionId: s?.id,
      level: level,
      recordedAt: at,
      context: context,
    ));
  }

  // ── Native queue drain ───────────────────────────────────────────────────
  Future<void> _drainQueue() async {
    if (_draining) return;
    _draining = true;
    try {
      final records = await _platform.drainQueue();
      if (records.isEmpty) return;
      final acked = <String>[];
      final locations = <LocationRecord>[];
      final stationary = <StationaryEvent>[];
      for (final map in records) {
        try {
          final type = map['type']?.toString();
          if (type == 'stationary_started' ||
              type == 'stationary_updated' ||
              type == 'stationary_completed' ||
              (type == null && map.containsKey('startAt'))) {
            stationary.add(_stationaryFromMap(map));
          } else if (map.containsKey('latitude') && map.containsKey('recordedAt')) {
            locations.add(_locationFromMap(map));
          }
          final id = map['id']?.toString();
          if (id != null && id.isNotEmpty) acked.add(id);
        } catch (_) {
          // Skip malformed record, keep the rest.
        }
      }
      locations.sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
      await _trackingRepo.insertLocationsRaw(locations);
      for (final event in stationary) {
        await _trackingRepo.upsertStationary(event);
      }
      await _platform.ackQueue(acked);

      final sessionIds = locations.map((l) => l.sessionId).toSet();
      for (final id in sessionIds) {
        await _trackingRepo.recomputeSessionStats(id);
      }

      final current = session;
      if (current != null) {
        _lastLocation = await _trackingRepo.lastLocation(current.id);
        final last = _lastLocation;
        if (last != null) {
          position = last.point;
          accuracy = last.accuracy;
          positionAt = last.recordedAt;
          positionSimulated = last.source == 'simulated';
        }
        await _refreshSessionCollections();
      }
      _lastDrain = DateTime.now();
      if (!booting) await refreshToday();
    } catch (_) {
      // Never surface a drain failure to the employee; records remain queued.
    } finally {
      _draining = false;
    }
  }

  // ── Internals ────────────────────────────────────────────────────────────
  Future<void> _attachDetector() async {
    final s = session;
    final emp = employee;
    if (s == null || emp == null) {
      _detector = null;
      return;
    }
    final detector = StationaryDetector(employeeId: emp.id, sessionId: s.id);
    final active = await _trackingRepo.activeStationary(s.id);
    detector.restore(active);
    _detector = detector;
  }

  Future<void> _refreshSessionCollections() async {
    final s = session;
    if (s == null) {
      siteVisits = const [];
      activeSiteVisit = null;
      stationaryEvents = const [];
      return;
    }
    siteVisits = await _trackingRepo.siteVisitsForSession(s.id);
    activeSiteVisit = null;
    for (final visit in siteVisits) {
      if (visit.isActive) {
        activeSiteVisit = visit;
        break;
      }
    }
    stationaryEvents = await _trackingRepo.stationaryForSession(s.id);
  }

  Future<void> _closeActiveStationary() async {
    final s = session;
    if (s == null) return;
    final flushed = _detector?.flush(DateTime.now(), battery: battery, accuracy: accuracy);
    if (flushed != null) {
      await _applyStationary(flushed);
    }
    final active = await _trackingRepo.activeStationary(s.id);
    if (active == null) return;
    final now = DateTime.now();
    final end = now.isBefore(active.startAt) ? active.startAt : now;
    await _trackingRepo.completeStationary(
      id: active.id,
      endAt: end,
      durationSeconds: end.difference(active.startAt).inSeconds.clamp(0, 86400).toInt(),
      battery: battery,
    );
  }

  Future<void> _ensureTrackingAlive() async {
    final s = session;
    if (s == null || !s.status.isActive) return;
    final running = await _platform.isTracking();
    tracking = running;
    if (!running) {
      final started = await _platform.start(_configFor(s));
      tracking = started;
      if (started) {
        notice = 'Tracking was restarted automatically.';
        _safeNotify();
      }
    }
  }

  TrackingConfig _configFor(TrackingSession s) => TrackingConfig(
        sessionId: s.id,
        employeeId: s.employeeId,
        platform: isMobile ? defaultTargetPlatform.name : 'simulated',
      );

  void _resetSessionState() {
    attendance = null;
    session = null;
    tracking = false;
    interrupted = false;
    activeSiteVisit = null;
    siteVisits = const [];
    stationaryEvents = const [];
    _detector = null;
    _lastLocation = null;
  }

  void _onTick() {
    if (_disposed || booting) return;
    final now = DateTime.now();
    if (_lastBatteryRefresh == null || now.difference(_lastBatteryRefresh!) > const Duration(seconds: 30)) {
      _lastBatteryRefresh = now;
      unawaited(_batteryService.refresh().then((level) {
        if (level != battery) {
          battery = level;
          _safeNotify();
        }
      }));
    }

    final swept = _detector?.sweep(now);
    if (swept != null && !_platform.supportsNativeStationary) {
      unawaited(_applyStationary(swept));
    }

    final isActive = isCheckedIn || (session != null && session!.status.isActive);
    if (isActive) {
      if (_detector != null && !_platform.supportsNativeStationary) {
        final hb = _detector!.checkHeartbeat(now, battery: battery, accuracy: accuracy);
        if (hb.started != null) unawaited(_applyStationary(hb.started!));
        if (hb.updated != null) unawaited(_applyStationary(hb.updated!));
        if (hb.completed != null) unawaited(_applyStationary(hb.completed!));
      }
      _safeNotify();
      if (_lastTodayRefresh == null || now.difference(_lastTodayRefresh!) > const Duration(seconds: 30)) {
        unawaited(refreshToday());
      }
      if (_lastDrain == null || now.difference(_lastDrain!) > const Duration(minutes: 2)) {
        unawaited(_drainQueue());
      }
      if (_lastKeepAlive == null || now.difference(_lastKeepAlive!) > const Duration(seconds: 15)) {
        _lastKeepAlive = now;
        unawaited(_ensureTrackingAlive());
      }
    }
  }

  void _setBusy(bool value) {
    busy = value;
    _safeNotify();
  }

  void _safeNotify() {
    if (!_disposed) notifyListeners();
  }

  // ── Map parsing ──────────────────────────────────────────────────────────
  LocationRecord _locationFromMap(Map<String, dynamic> map) => LocationRecord(
        id: map['id']?.toString() ?? _uuid.v4(),
        employeeId: map['employeeId']?.toString() ?? employee?.id ?? '',
        sessionId: map['sessionId']?.toString() ?? session?.id ?? '',
        latitude: _asDouble(map['latitude']),
        longitude: _asDouble(map['longitude']),
        accuracy: _asDouble(map['accuracy']),
        speed: map['speed'] == null ? null : _asDouble(map['speed']),
        bearing: map['bearing'] == null ? null : _asDouble(map['bearing']),
        battery: _asInt(map['battery'], battery),
        platform: map['platform']?.toString() ?? _platform.name,
        movementStatus: MovementStatus.parse(map['movementStatus']?.toString()),
        recordedAt: _asDate(map['recordedAt']),
        source: map['source']?.toString() ?? _platform.name,
      );

  StationaryEvent _stationaryFromMap(Map<String, dynamic> map) {
    final start = _asDate(map['startAt'] ?? map['start_at']);
    final rawEnd = map['endAt'] ?? map['end_at'];
    final end = rawEnd == null ? null : _asDate(rawEnd);
    var duration = _asInt(map['durationSeconds'] ?? map['duration_seconds']);
    if (duration <= 0 && end != null) {
      duration = end.difference(start).inSeconds;
    }
    duration = duration.clamp(0, 86400);

    // Guard against 0,0 coordinates (uninitialized native state).
    var lat = _asDouble(map['latitude']);
    var lng = _asDouble(map['longitude']);
    if (lat.abs() < 0.0001 && lng.abs() < 0.0001) {
      final pos = position;
      if (pos != null) {
        lat = pos.latitude;
        lng = pos.longitude;
      }
    }

    return StationaryEvent(
      id: map['id']?.toString() ?? _uuid.v4(),
      employeeId: map['employeeId']?.toString() ?? employee?.id ?? '',
      sessionId: map['sessionId']?.toString() ?? session?.id ?? '',
      latitude: lat,
      longitude: lng,
      startAt: start,
      endAt: end,
      durationSeconds: duration,
      accuracy: _asDouble(map['accuracy']),
      battery: map['battery'] == null ? null : _asInt(map['battery']),
      status: StationaryStatus.parse(map['status']?.toString()),
      radiusMeters: _asDouble(map['radiusMeters'] ?? map['radius_meters'], AppConfig.stationaryRadiusMeters),
    );
  }

  double _asDouble(Object? value, [double fallback = 0]) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? fallback;
    return fallback;
  }

  int _asInt(Object? value, [int fallback = 0]) {
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? fallback;
    return fallback;
  }

  DateTime _asDate(Object? value) {
    if (value is num) {
      final n = value.toInt();
      if (n <= 0) return DateTime.now();
      if (n < 10000000000) return DateTime.fromMillisecondsSinceEpoch(n * 1000);
      return DateTime.fromMillisecondsSinceEpoch(n);
    }
    if (value is String) {
      final parsed = int.tryParse(value);
      if (parsed != null) {
        if (parsed <= 0) return DateTime.now();
        if (parsed < 10000000000) return DateTime.fromMillisecondsSinceEpoch(parsed * 1000);
        return DateTime.fromMillisecondsSinceEpoch(parsed);
      }
      return DateTime.tryParse(value) ?? DateTime.now();
    }
    return DateTime.now();
  }

  void _resolveCurrentAddress() {
    final pt = position;
    if (pt == null) return;
    final cached = GeoAddressService.instance.getCached(pt.latitude, pt.longitude);
    if (cached != null) {
      if (currentAddress != cached) {
        currentAddress = cached;
        _safeNotify();
      }
      return;
    }
    GeoAddressService.instance.resolve(pt.latitude, pt.longitude).then((addr) {
      if (addr != null && addr != currentAddress && !_disposed) {
        currentAddress = addr;
        _safeNotify();
      }
    });
  }

  @override
  void dispose() {
    _disposed = true;
    _ticker?.cancel();
    _eventSub?.cancel();
    if (simulation) {
      unawaited(_platform.dispose());
    }
    super.dispose();
  }
}
