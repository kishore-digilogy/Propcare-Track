#!/usr/bin/env bash
#
# Capture the Paper Atlas screens from a real Android build.
#
#   tool/capture_screenshots.sh [device-id]
#
# Defaults to emulator-5554. The emulator is pinned to the office coordinates
# and permissions are re-granted while Flutter installs the test build, so the
# office check-in in the capture flow succeeds without touching the device.
# Screenshots are written to screenshots/ on the host.
set -euo pipefail

DEVICE="${1:-emulator-5554}"
APP_ID="com.example.propcare_track"

if ! command -v adb >/dev/null 2>&1; then
  echo "adb is required." >&2
  exit 1
fi

# Best effort: only the Android emulator supports `emu geo fix`.
adb -s "$DEVICE" emu geo fix 80.2588 12.9763 >/dev/null 2>&1 || true

# `flutter drive` reinstalls the app, which can reset runtime permissions.
# Keep granting them until the capture run finishes.
(
  for _ in $(seq 1 600); do
    for permission in \
      android.permission.ACCESS_FINE_LOCATION \
      android.permission.ACCESS_COARSE_LOCATION \
      android.permission.ACCESS_BACKGROUND_LOCATION \
      android.permission.POST_NOTIFICATIONS; do
      adb -s "$DEVICE" shell pm grant "$APP_ID" "$permission" >/dev/null 2>&1 || true
    done
    sleep 0.4
  done
) &
GRANT_PID=$!
trap 'kill "$GRANT_PID" >/dev/null 2>&1 || true' EXIT

# Flutter's incremental Android build can miss edits made under integration_test/.
# Dropping the cached kernel guarantees the capture target is recompiled.
rm -f build/app/intermediates/flutter/debug/flutter_assets/kernel_blob.bin

flutter drive \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/screenshot_test.dart \
  -d "$DEVICE" \
  --no-enable-impeller

echo "Screenshots written to screenshots/."
