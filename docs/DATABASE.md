# Local database

Engine: **sqflite** on Android/iOS/macOS, **sqflite_common_ffi** on Windows/Linux. Web is intentionally unsupported (`AppDatabase` throws `UnsupportedError`). Database file: `propcare_track.db` in the platform database directory. Schema version: `1`.

Every operational table carries `sync_status` (`pending` / `synced` / `failed`) or is reachable from a table that does, so Phase 2 can push rows without a migration. Phase 1 never writes `synced` or `failed`.

## Tables

### `employees`
Seeded demo crew.

| Column | Type | Notes |
| --- | --- | --- |
| `id` | TEXT PK | `emp-1042`, `emp-2087` |
| `code` | TEXT UNIQUE | `EMP-1042` |
| `name`, `email`, `phone` | TEXT | profile data |
| `department`, `designation`, `joined_at` | TEXT | profile data |
| `avatar_seed` | TEXT | deterministic avatar color |
| `password_hash` | TEXT | `sha256(salt + password)` |

### `office_config`
Single seeded row: BAID Hi-Tech Park, `12.9763, 80.2588`, radius `200 m`. Radius is editable in the repository layer for future admin config.

### `assigned_sites`
Seeded rows with unique IDs, coordinates, radius (`250 m`) and sort order.

| ID | Code | Name | Coordinates |
| --- | --- | --- | --- |
| `site-suncity` | SITE-01 | Casagrand Suncity | `12.84018, 80.14907` |
| `site-firstcity` | SITE-02 | Casagrand First City | `12.895398, 80.208018` |

### `attendance_records`
One row per office attendance day.

- `id`, `employee_id`, `session_id`, `office_id`
- `check_in_at`, `check_out_at` (epoch ms)
- `check_in_lat/lng/accuracy/battery`
- `check_out_lat/lng/accuracy/battery`
- `status` — `active`, `completed`, `interrupted`, `closedManually`
- `total_duration_seconds`, `sync_status`, `created_at`

Indexes: `(employee_id, check_in_at)`, `(employee_id, status)`.

### `tracking_sessions`
One row per office attendance session; the native tracker writes locations against `tracking_sessions.id`.

- `id`, `employee_id`, `attendance_id`, `office_id`
- `started_at`, `ended_at`, `status` (`active`, `completed`, `interrupted`)
- `platform` (`android`, `ios`, `simulated`)
- `start_battery`, `end_battery`
- `last_latitude`, `last_longitude`, `last_update_at`
- `distance_meters`, `location_count`
- `sync_status`, `created_at`

### `location_records`
Every accepted GPS fix.

`id` (UUID), `employee_id`, `session_id`, `latitude`, `longitude`, `accuracy`, `speed`, `bearing`, `battery`, `platform`, `movement_status` (`moving` / `stationary` / `unknown`), `recorded_at`, `source` (`native` / `simulated`), `sync_status`.

Unique primary key makes native-queue replay idempotent. `TrackingRepository.appendLocation` rejects duplicate ids and out-of-range fixes.

### `stationary_events`
A stop of at least 20 seconds inside a ~30 m anchor.

`id`, `employee_id`, `session_id`, `latitude`, `longitude`, `start_at`, `end_at`, `duration_seconds`, `accuracy`, `battery`, `status` (`active` / `completed`), `radius_meters`, `sync_status`.

The active row is upserted on every update and completed when the employee moves beyond the 48 m break radius, when the session ends, or when the stationary sweep fires after 90 s without a fix.

### `site_attendance`
One row per site visit.

`id`, `employee_id`, `session_id`, `site_id`, `site_name`, `check_in_at`, `check_out_at`, check-in/out coordinates, accuracy and battery, `duration_seconds`, `status` (`active` / `completed`), `sync_status`.

### `battery_logs`
`id`, `employee_id`, `session_id`, `level`, `recorded_at`, `context`.

Contexts: `check_in`, `tracking` (every 5 minutes or ±5 %), `site_check_in`, `site_check_out`, `check_out`, `logout`, `office_check_out`, `session_closed`.

### `app_meta`
Key/value metadata reserved for future migrations and sync cursors.

## Transactions

`AttendanceRepository.startSession`, `closeSession` and `markSessionInterrupted` write attendance, tracking session and battery log in one `db.transaction`. A failure rolls the whole transition back, and `AppController` stops the native tracker if the DB write fails after a successful start.

## Derived data

`HistoryRepository.dayStory(employeeId, date)` joins the day's attendance, tracking session, locations, stationary events, site visits and battery logs into a `DayStory` used by the Today screen, live map and cinematic story view. `daySummaries` aggregates completed/interrupted days for the archive. Nothing is deleted on logout.
