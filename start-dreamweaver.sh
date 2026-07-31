#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$ROOT_DIR/Ihpone/DreamWeaver"
PROJECT_FILE="$PROJECT_DIR/DreamWeaver.xcodeproj"
DERIVED_DATA_DIR="$ROOT_DIR/.derivedData/start-script"
IOS_SCHEME="DreamWeaver"
WATCH_SCHEME="DreamWeaver WatchKit App"
IOS_APP_NAME="DreamWeaver.app"
WATCH_APP_NAME="DreamWeaver WatchKit App.app"
IOS_BUNDLE_ID="GJDRW.DreamWeaver"
WATCH_BUNDLE_ID="GJDRW.DreamWeaver.watchkitapp"
DEFAULT_IOS_NAME="${DREAMWEAVER_IOS_SIM_NAME:-iPhone 17 Pro}"
DEFAULT_WATCH_NAME="${DREAMWEAVER_WATCH_SIM_NAME:-Apple Watch Series 11 (46mm)}"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

if [[ ! -d "$DEVELOPER_DIR" ]]; then
  echo "Xcode developer directory not found: $DEVELOPER_DIR" >&2
  exit 1
fi

export DEVELOPER_DIR

find_device_udid() {
  local device_name="$1"
  xcrun simctl list devices available | awk -v name="$device_name" '
    index($0, name " (") {
      if (match($0, /[0-9A-F-]{36}/)) {
        print substr($0, RSTART, RLENGTH)
      }
      exit
    }
  '
}

find_first_matching_udid() {
  local pattern="$1"
  xcrun simctl list devices available | awk -v pattern="$pattern" '
    $0 ~ pattern {
      if (match($0, /[0-9A-F-]{36}/)) {
        print substr($0, RSTART, RLENGTH)
      }
      exit
    }
  '
}

ensure_device_udid() {
  local requested_name="$1"
  local fallback_pattern="$2"
  local kind="$3"
  local udid

  udid="$(find_device_udid "$requested_name")"
  if [[ -n "$udid" ]]; then
    printf '%s' "$udid"
    return 0
  fi

  udid="$(find_first_matching_udid "$fallback_pattern")"
  if [[ -n "$udid" ]]; then
    echo "$kind simulator '$requested_name' not found, using first available match." >&2
    printf '%s' "$udid"
    return 0
  fi

  echo "No available $kind simulator found." >&2
  exit 1
}

find_pair_id() {
  local watch_udid="$1"
  local phone_udid="$2"
  xcrun simctl list pairs | awk -v watch="$watch_udid" -v phone="$phone_udid" '
    /^[0-9A-F-]+/ { current = $1; has_watch = 0; has_phone = 0 }
    index($0, watch) { has_watch = 1 }
    index($0, phone) { has_phone = 1 }
    has_watch && has_phone { print current; exit }
  '
}

boot_device() {
  local udid="$1"
  if xcrun simctl list devices | grep -F "$udid" | grep -Fq "(Booted)"; then
    echo "Simulator already booted: $udid"
    return 0
  fi

  xcrun simctl boot "$udid" >/dev/null 2>&1 || true
}

wait_for_boot() {
  local udid="$1"
  xcrun simctl bootstatus "$udid" -b >/dev/null
}

activate_simulator_ui() {
  open -a Simulator
  osascript -e 'tell application "Simulator" to activate' >/dev/null 2>&1 || true
}

IOS_UDID="$(ensure_device_udid "$DEFAULT_IOS_NAME" "iPhone" "iPhone")"
WATCH_UDID="$(ensure_device_udid "$DEFAULT_WATCH_NAME" "Apple Watch" "Apple Watch")"

PAIR_ID="$(find_pair_id "$WATCH_UDID" "$IOS_UDID")"
if [[ -z "$PAIR_ID" ]]; then
  echo "Creating iPhone/Watch simulator pair..."
  PAIR_ID="$(xcrun simctl pair "$WATCH_UDID" "$IOS_UDID")"
fi

echo "Using iPhone simulator: $IOS_UDID"
echo "Using Watch simulator: $WATCH_UDID"
echo "Using simulator pair: $PAIR_ID"

echo "Opening Simulator UI..."
activate_simulator_ui

echo "Booting iPhone simulator..."
boot_device "$IOS_UDID"
echo "Booting Watch simulator..."
boot_device "$WATCH_UDID"

echo "Waiting for iPhone simulator to finish booting..."
wait_for_boot "$IOS_UDID"
echo "Waiting for Watch simulator to finish booting..."
wait_for_boot "$WATCH_UDID"

activate_simulator_ui

mkdir -p "$DERIVED_DATA_DIR"

echo "Building iPhone app..."
xcodebuild \
  -project "$PROJECT_FILE" \
  -scheme "$IOS_SCHEME" \
  -destination "platform=iOS Simulator,id=$IOS_UDID" \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  build

echo "Building Watch app..."
xcodebuild \
  -project "$PROJECT_FILE" \
  -scheme "$WATCH_SCHEME" \
  -destination "platform=watchOS Simulator,id=$WATCH_UDID" \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  build

IOS_APP_PATH="$DERIVED_DATA_DIR/Build/Products/Debug-iphonesimulator/$IOS_APP_NAME"
WATCH_APP_PATH="$DERIVED_DATA_DIR/Build/Products/Debug-watchsimulator/$WATCH_APP_NAME"

if [[ ! -d "$IOS_APP_PATH" ]]; then
  echo "Built iPhone app not found: $IOS_APP_PATH" >&2
  exit 1
fi

if [[ ! -d "$WATCH_APP_PATH" ]]; then
  echo "Built Watch app not found: $WATCH_APP_PATH" >&2
  exit 1
fi

echo "Installing iPhone app..."
xcrun simctl uninstall "$IOS_UDID" "$IOS_BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$IOS_UDID" "$IOS_APP_PATH"

echo "Installing Watch app..."
xcrun simctl uninstall "$WATCH_UDID" "$WATCH_BUNDLE_ID" >/dev/null 2>&1 || true
xcrun simctl install "$WATCH_UDID" "$WATCH_APP_PATH"

echo "Launching iPhone app..."
xcrun simctl launch "$IOS_UDID" "$IOS_BUNDLE_ID"

echo "Launching Watch app..."
xcrun simctl launch "$WATCH_UDID" "$WATCH_BUNDLE_ID"

echo "DreamWeaver iPhone and Watch apps are running."