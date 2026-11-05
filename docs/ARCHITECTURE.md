# Architecture

## Layers

```text
┌──────────────────────────────────────────────────────────────┐
│ UI            screens · sheets · widgets                     │
│               watches AppController through provider         │
├──────────────────────────────────────────────────────────────┤
│ State         AppController (ChangeNotifier)                 │
│               attendance state machine, session recovery,    │
│               battery cadence, queue drain, history refresh  │
├──────────────────────────────────────────────────────────────┤
│ Domain        models · geo rules · StationaryDetector        │
├──────────────────────────────────────────────────────────────┤
│ Data          repositories → AppDatabase (sqflite)           │
├──────────────────────────────────────────────────────────────┤
│ Platform      TrackingPlatform abstraction                   │
│               NativeTrackingPlatform (Android/iOS)           │
│               SimulatedTrackingPlatform (desktop)            │
│               LocationService · BatteryService · SessionStore│
└──────────────────────────────────────────────────────────────┘
```

The UI never talks to the database or the location plugins directly. `AppController` is the single source of truth and exposes immutable lists and plain fields to the screens.

## Attendance state machine

```text
                 officeCheckIn
   signed out ─────────────────► active ──────────────┐
        ▲                         │  │               │
        │                  siteCheckIn/out          │ officeCheckOut
        │                         │  │               ▼
        │                         ▼  │           completed
        │                      on site
        │
        │  logout (any state)            force-close / reboot
        └────────────────────────────── interrupted
                                          │
                          resumeInterruptedSession ─► active
                          closeInterruptedSession  ─► closedManually
```

Key invariants:

- **Office check-in** validates the fix, starts the native tracker, writes attendance + tracking session + battery log in one transaction, then attaches the Dart stationary detector when the platform does not provide native stationary events.
- **Site check-in** requires an active office attendance session and no other open site visit. It writes the visit and a `site_check_in` battery log. It never calls `stop()`.
- **Site check-out** closes the visit and logs `site_check_out`. Tracking continues.
- **Office check-out** closes any open site visit, closes an active stationary event, stops the tracker, closes the attendance + tracking session, and logs `check_out`.
- **Logout** closes an open site visit, closes an active stationary event, stops the tracker, marks attendance `interrupted` and the tracking session `interrupted`, logs `logout`, clears the signed-in employee id, and keeps every row. It is explicitly *not* an office check-out.
- **Interrupted recovery** is offered on next login. `resume` reactivates the same session and restarts tracking; `close` marks it `closedManually` / `completed` and keeps the records.

## Error handling

`AppException` carries a stable `code` (`gps_off`, `permission_denied`, `background_denied`, `tracking_start_failed`, `interrupted_session`). Screens show the message inline or as a snack; no error is swallowed silently.

`AppController.error` is for background failures that happen while the employee is elsewhere. `HomeShell` drains it into a snack and calls `dismissError()`.

## Lifecycle

`PropCareApp` is a `WidgetsBindingObserver`. On `AppLifecycleState.resumed` it calls `AppController.onAppResume()`, which refreshes battery/permissions, drains the native queue, refreshes today's data and restarts tracking if the OS stopped it.

`AppController` also has an 8-second ticker for battery refresh, stationary sweeps, history refresh throttling and a 2-minute queue drain.

## Platform abstraction

```dart
abstract class TrackingPlatform {
  String get name;
  bool get supportsNativeStationary;
  Stream<Map<String, dynamic>> get events;
  Future<bool> start(TrackingConfig config);
  Future<bool> stop();
  Future<bool> isTracking();
  Future<Map<String, dynamic>> status();
  Future<List<Map<String, dynamic>>> drainQueue();
  Future<void> ackQueue(List<String> ids);
  Future<void> dispose();
}
```

- **Android** — `TrackingService` (foreground, `location` type) + `TrackingBridge` + `TrackingQueue`.
- **iOS** — `LocationTrackingManager` + `TrackingStore`.
- **Desktop** — `SimulatedTrackingPlatform`, a deterministic 7-leg journey with compressed dwell/transit times.

When `supportsNativeStationary` is true, Dart does not run its own detector, so stationary events are never duplicated.

## Design system

- **Colors** — white `#FFFFFF`, soft page tint `#F7F9FC`, ink `#101828`, mint `#0E9F6E`, cyan `#0B84C7`, coral `#E8583F`, violet `#6157D9`, amber `#C77A06`.
- **Type** — Poppins for every text role (400/500/600/700/800).
- **Surfaces** — elevated white cards with 1 px `#EDF1F7` borders, soft ink shadows, 18–28 px radii.
- **Maps** — Android/iOS use `GoogleRouteMap` (real Google Maps) with office/site markers, radius circles, the live fix, an accuracy circle and the stored route polyline. macOS/desktop and widget tests fall back to the offline custom-painted `RadarMap`/`RouteStoryMap` (concentric range rings, survey grid, breadcrumb trail, glowing pulse orb).
- **Motion** — staggered fade/slide entrances, animated route replay, hold-to-confirm interactions, animated counters and battery sparklines.
