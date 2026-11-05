# Tracking engine

## Channels

| Channel | Type | Direction |
| --- | --- | --- |
| `propcare/tracking` | `MethodChannel` | Flutter → native |
| `propcare/tracking_events` | `EventChannel` | native → Flutter |

Methods: `startTracking(config)`, `stopTracking`, `isTracking`, `getStatus`, `getPendingRecords`, `ackPendingRecords`, `getBatteryLevel`.

Record map keys: `type`, `id`, `employeeId`, `sessionId`, `latitude`, `longitude`, `accuracy`, `speed`, `bearing`, `battery`, `platform`, `movementStatus`, `recordedAt`, `source`. Stationary records add `startAt`, `endAt`, `durationSeconds`, `status`, `radiusMeters`.

Event types: `location`, `stationary_started`, `stationary_updated`, `stationary_completed`, `battery`, `status`, `error`.

## Why a durable queue?

The native service must keep recording when the Flutter isolate is suspended, and must not lose data when the app is force-closed. Both platforms therefore write every record to an append-only JSON-lines file **before** broadcasting it:

- Android: `filesDir/tracking_queue.jsonl`
- iOS: `Application Support/PropCare/tracking_queue.jsonl`

`AppController` drains the queue on boot, every 2 minutes, on resume and after each native event burst. Each record has a UUID, so re-insertion after a partial drain is idempotent (`INSERT OR IGNORE`). Records are acknowledged only after the database transaction succeeds.

## Stationary detection

Reference rule (Dart `StationaryDetector`, Kotlin `TrackingService`, Swift `LocationTrackingManager` all implement it):

1. Reject fixes with accuracy > 80 m.
2. First fix becomes the anchor with `anchorSince = now`.
3. While within `30 m × 1.6 = 48 m` of the anchor, update `lastInsideAt`.
4. Once the anchor has been held for **20 s**, create an `active` stationary event at the anchor coordinate.
5. Every subsequent inside fix updates `endAt` and `durationSeconds`.
6. Moving beyond 48 m completes the event at `lastInsideAt` (not at the break fix), so the stored duration does not include the walk away.
7. If no fix arrives for 90 s while an event is active, the Dart sweep completes it at `lastInsideAt`.

The break hysteresis prevents GPS jitter from repeatedly opening/closing stops. Out-of-order fixes (`recordedAt < anchorSince`) are ignored without disturbing state. Native services persist their stationary state so a process restart can continue or complete the open event.

## Battery

`BatteryService` wraps `battery_plus`. Battery is attached to every location record and logged by `AppController`:

- at office check-in
- every 5 minutes or when the level changes by ±5 %
- at every site check-in and check-out
- at office check-out
- at logout

`battery_logs` powers the battery trace in the live map and the story view.

## Location stamping

Attendance is not location-locked. Office and site check-ins/check-outs are allowed from anywhere — at the office, at home or on the road. The app fetches the current fix and stamps latitude, longitude, accuracy and battery level on the record.

The geofence helpers are still used for proximity display. `withinGeofence(distance, radius, accuracy)` widens the radius by the reported accuracy, capped at 50 m:

```dart
tolerance = accuracy.clamp(0, 50)
inside = distance <= radius + tolerance
```

The office and site screens show distance and accuracy as context, not as a gate. A missing GPS fix is the only location-related blocker.

## Simulator

`SimulatedTrackingPlatform` emits a location every 3 seconds and follows a 7-leg journey:

| Leg | Duration |
| --- | --- |
| Office dwell | 26 s |
| Office → Suncity | 30 s |
| Suncity dwell | 40 s |
| Suncity → First City | 24 s |
| First City dwell | 40 s |
| First City → Office | 30 s |
| Office dwell | 24 s |

`jumpToSite` / `jumpToOffice` shift the journey clock so the next tick lands at the target. The simulator's accuracy, speed and battery values are realistic enough to exercise the same UI and stationary logic as a phone.

## Route on the map

Every `locations` row already written by the native service (or the simulator) is read back as the day's breadcrumb trail. On Android and iOS the trail is drawn as a Google Maps polyline in `GoogleRouteMap`, together with the office marker, site markers, radius circles, the live fix and its accuracy circle. The day-story replay uses the same widget with the archived route. macOS/desktop and widget tests keep the offline `RadarMap` painter so they need no API key or network.

Map tiles are the only network-dependent part of Phase 1. Tracking, attendance and route storage remain fully local.

## Android specifics

- `TrackingService` is a foreground service with `foregroundServiceType="location"`, a low-importance notification and `START_STICKY`.
- Uses `LocationManager` GPS + NETWORK providers. No Google Play Services dependency.
- Duplicate fixes from both providers are filtered (same 1.5 s window and < 2 m movement).
- `BootReceiver` attempts to restart tracking after reboot. Newer Android versions may refuse a location FGS from `BOOT_COMPLETED`; the app resume hook restarts tracking when the employee opens the app, and queued records are preserved.
- If background location is revoked, the service emits an `error` event; the UI explains how to restore it.

## iOS specifics

- `CLLocationManager` with `kCLLocationAccuracyBest`, `allowsBackgroundLocationUpdates = true`, `pausesLocationUpdatesAutomatically = false`, `showsBackgroundLocationIndicator = true`.
- `UIBackgroundModes: location` in `Info.plist`; all three location usage strings present.
- iOS may stop updates if the user force-quits the app. The queue keeps everything already written, and `onAppResume` restarts tracking for an active session.

## Edge-case matrix

| Situation | Behaviour |
| --- | --- |
| GPS off | Check-in blocked with `gps_off`; existing tracking shows an error notice. |
| Foreground permission denied | Check-in blocked with `permission_denied`. |
| Background permission denied | Check-in blocked with `background_denied` and an explanation. |
| No network | Tracking and storage stay local; Google Maps needs a connection for fresh tiles, and the last cached view remains usable. |
| Poor accuracy | Check-in still records the fix and stamps the accuracy; stationary ignores fixes above 80 m. |
| Remote check-in | Allowed from anywhere; current location is stamped. |
| Duplicate fixes | UUID primary key + 1.5 s/2 m native filter. |
| Force-close | Native queue survives; session resumes as interrupted on next login. |
| Reboot | Boot receiver best-effort restart; resume hook restarts tracking. |
| Low battery | Battery logged; no data loss. |
| Logout with active tracking | Hold-to-confirm, stop tracker, mark interrupted, keep rows. |
| Another site still open | Site check-in blocked until the other visit is closed. |
| Office check-out with open site | Site visit is closed automatically first. |
