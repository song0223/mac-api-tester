#!/usr/bin/env bash
set -euo pipefail

APP_NAME="MacAPITester"
BUNDLE_ID="com.songxiang.MacAPITester"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
APP_EXECUTABLE="$MACOS_DIR/$APP_NAME"
PLIST_PATH="$CONTENTS_DIR/Info.plist"

usage() {
  echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
  exit 2
}

MODE="${1:-run}"
case "$MODE" in
  run|--debug|--logs|--telemetry|--verify)
    ;;
  *)
    usage
    ;;
esac

running_pids() {
  /bin/ps -axo pid=,command= | /usr/bin/awk -v target="$APP_EXECUTABLE" '
    {
      pid = $1
      $1 = ""
      sub(/^[[:space:]]+/, "", $0)
      if ($0 == target || index($0, target " ") == 1) {
        print pid
      }
    }
  '
}

stop_running_app() {
  local pids
  pids="$(running_pids || true)"
  if [[ -n "$pids" ]]; then
    /bin/kill $pids >/dev/null 2>&1 || true
  fi
}

wait_for_app_process() {
  local timeout_seconds="${1:-10}"
  local interval_seconds="${2:-0.25}"
  local deadline
  deadline="$((SECONDS + timeout_seconds))"

  while true; do
    if /usr/bin/pgrep -f -x "$APP_EXECUTABLE" >/dev/null 2>&1; then
      return 0
    fi

    if (( SECONDS >= deadline )); then
      echo "Timed out waiting for $APP_NAME to launch after ${timeout_seconds}s." >&2
      return 1
    fi

    /bin/sleep "$interval_seconds"
  done
}

stop_running_app

swift build --product "$APP_NAME"

BUILD_BIN_DIR="$(swift build --show-bin-path)"
BUILD_BINARY="$BUILD_BIN_DIR/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$MACOS_DIR"
cp "$BUILD_BINARY" "$APP_EXECUTABLE"
chmod +x "$APP_EXECUTABLE"

cat >"$PLIST_PATH" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
EOF

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug)
    lldb -- "$APP_EXECUTABLE"
    ;;
  --logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify)
    open_app
    wait_for_app_process 10 0.25
    ;;
esac
