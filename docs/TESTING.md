# Testing

## Static checks

```bash
flutter analyze
```

Expected: `No issues found!`

## Unit and widget tests

```bash
flutter test
```

- `test/geo_test.dart` — distance, bearing, offset, interpolation, geofence accuracy widening and the 50 m cap.
- `test/stationary_detector_test.dart` — 20 s threshold, poor-accuracy rejection, break-radius completion and duration.
- `test/workflow_test.dart` — controller login → office check-in against an in-memory database.
- `test/app_flow_test.dart` — full 390×844 widget journey across every screen, catching `RenderFlex` overflows.
- `test/responsive_test.dart` — live check-in, every tab, site detail, office check-out and the day story at 320×568 and 768×1024.

## Native bridge smoke test

Starts a short real tracking session through the Kotlin/Swift bridge, waits for a
location or status event, checks the durable queue and stops tracking.

```bash
flutter test integration_test/native_tracking_smoke_test.dart -d <device>
```

Verified against:

- iPhone 17 Pro simulator, iOS 26.5
- Android emulator, API 37

On the Android emulator, set a fix first:

```bash
adb emu geo fix 80.2588 12.9763
adb shell pm grant com.example.propcare_track android.permission.ACCESS_FINE_LOCATION
adb shell pm grant com.example.propcare_track android.permission.ACCESS_COARSE_LOCATION
adb shell pm grant com.example.propcare_track android.permission.ACCESS_BACKGROUND_LOCATION
```

## Screenshots

```bash
tool/capture_screenshots.sh emulator-5554
```

The script pins the emulator to the office, grants location permissions while
`flutter drive` installs the build, then walks welcome → login → office
check-in → live map → sites → site detail → history → profile → office
check-out → day story. Thirteen PNGs land in `screenshots/` at the device
resolution (1080×2400 in the checked-in set).

## Integration test (desktop simulator)

```bash
flutter test integration_test/app_test.dart -d macos
```

The test clears local prefs and the sqflite database, then drives the real app:

1. Splash → single welcome page → login with the prefilled demo employee.
2. Office check-in at BAID Hi-Tech Park.
3. Waits ~23 s at the office dwell so the 20-second stationary rule fires.
4. Opens Sites → Casagrand Suncity → demo jump → site check-in.
5. Holds to check out of the site and asserts tracking is still live.
6. Returns to Today → office check-out via hold-to-confirm.
7. Asserts history was written, opens the day story, then logs out with hold-to-confirm.

Any `RenderFlex` overflow or unhandled framework error fails the test.

## Build checks

```bash
flutter build apk --debug
flutter build ios --simulator --debug
flutter build macos --debug
```

## Manual device checklist

### Android
- [ ] First check-in requests foreground then background location.
- [ ] Notification appears with the location foreground-service type.
- [ ] Minimise the app: fixes keep arriving, the notification stays.
- [ ] Walk 30 m away: stationary event completes at the last inside fix.
- [ ] Revoke location in Settings: app shows an error on resume.
- [ ] Force-stop and reopen: interrupted-session sheet appears; resume works.
- [ ] Reboot with an active session: tracking resumes or the app resumes it.
- [ ] Log out with active tracking: hold-to-confirm, session interrupted, records still in History.

### iOS
- [ ] "Always" location prompt appears after check-in.
- [ ] Blue background-location indicator is visible while tracking.
- [ ] Lock the phone for several minutes: route still records.
- [ ] Force-quit and reopen: interrupted-session sheet appears.
- [ ] Site check-out leaves the office tracking session live.
- [ ] Office check-out stops the indicator.

### Visual
- [ ] No overflow at 320×568, 390×844 and tablet widths.
- [ ] Text scales to 1.3× without clipping critical buttons.
- [ ] White cards and accent text remain legible in bright sunlight (manual).

## Verified in this environment

| Check | Result |
| --- | --- |
| `flutter analyze` | No issues found |
| `flutter test` | 13/13 passed |
| `flutter build apk --debug` | Built successfully (Kotlin 2.3.0) |
| `flutter build ios --simulator --debug` | Built successfully (iOS 14.0) |
| `flutter build macos --debug` | Built successfully |
| iOS native tracking smoke test (iPhone 17 Pro simulator) | Passed |
| Android native tracking smoke test (API 37 emulator) | Passed |
| Google Maps render on Android emulator | Passed, no API-key errors |
| Android full capture run (welcome → check-in → check-out → day story) | Passed, 14 screenshots |

The remaining manual checklist items need a physical device, a locked screen and
real movement; they cannot be simulated faithfully in CI.
