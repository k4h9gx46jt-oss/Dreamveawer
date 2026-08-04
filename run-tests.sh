#!/usr/bin/env bash
set -euo pipefail

# Runs the DreamWeaver test suites on a simulator and prints a readable summary.
#
# Usage:
#   ./run-tests.sh                # unit tests (iPhone + Watch logic), default
#   ./run-tests.sh --watch        # only the Watch sleep-staging suite
#   ./run-tests.sh --all          # unit tests and UI tests
#   ./run-tests.sh --ui           # UI tests only
#   ./run-tests.sh --boot-watch-runtime  # launch iPhone + Watch sims/apps first
#   ./run-tests.sh --no-watch-build   # skip the watchOS compile check
#   ./run-tests.sh --filter DreamScoreTests
#   ./run-tests.sh --filter DreamScoreTests/phrasesAreFourBars

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_FILE="$ROOT_DIR/Ihpone/DreamWeaver/DreamWeaver.xcodeproj"
DERIVED_DATA_DIR="$ROOT_DIR/.derivedData/tests"
LOG_FILE="$DERIVED_DATA_DIR/last-test-run.log"
SCHEME="DreamWeaver"
WATCH_SCHEME="DreamWeaver WatchKit App"
UNIT_TARGET="DreamWeaverTests"
UI_TARGET="DreamWeaverUITests"
WATCH_SUITE="WatchREMClassifierTests"
DEFAULT_IOS_NAME="${DREAMWEAVER_IOS_SIM_NAME:-iPhone 17 Pro}"
DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

if [[ ! -d "$DEVELOPER_DIR" ]]; then
  echo "Xcode developer directory not found: $DEVELOPER_DIR" >&2
  exit 1
fi
export DEVELOPER_DIR

RUN_UNIT=1
RUN_UI=0
WATCH_BUILD=1
BOOT_WATCH_RUNTIME=0
FILTER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --all) RUN_UNIT=1; RUN_UI=1; shift ;;
    --ui) RUN_UNIT=0; RUN_UI=1; shift ;;
    --unit) RUN_UNIT=1; RUN_UI=0; shift ;;
    --watch) RUN_UNIT=1; RUN_UI=0; FILTER="$WATCH_SUITE"; shift ;;
    --boot-watch-runtime) BOOT_WATCH_RUNTIME=1; shift ;;
    --no-watch-build) WATCH_BUILD=0; shift ;;
    --filter)
      [[ $# -ge 2 ]] || { echo "--filter needs a value" >&2; exit 1; }
      FILTER="$2"
      shift 2
      ;;
    -h|--help)
      sed -n '3,14p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
done

find_device_udid() {
  xcrun simctl list devices available | awk -v name="$1" '
    index($0, name " (") {
      if (match($0, /[0-9A-F-]{36}/)) { print substr($0, RSTART, RLENGTH) }
      exit
    }
  '
}

find_first_matching_udid() {
  xcrun simctl list devices available | awk -v pattern="$1" '
    $0 ~ pattern {
      if (match($0, /[0-9A-F-]{36}/)) { print substr($0, RSTART, RLENGTH) }
      exit
    }
  '
}

IOS_UDID="$(find_device_udid "$DEFAULT_IOS_NAME")"
if [[ -z "$IOS_UDID" ]]; then
  IOS_UDID="$(find_first_matching_udid "iPhone")"
fi
if [[ -z "$IOS_UDID" ]]; then
  echo "No available iPhone simulator found." >&2
  exit 1
fi

mkdir -p "$DERIVED_DATA_DIR"

TEST_ARGS=()
if [[ -n "$FILTER" ]]; then
  TEST_ARGS+=(-only-testing:"$UNIT_TARGET/$FILTER")
else
  [[ $RUN_UNIT -eq 1 ]] && TEST_ARGS+=(-only-testing:"$UNIT_TARGET")
  [[ $RUN_UI -eq 1 ]] && TEST_ARGS+=(-only-testing:"$UI_TARGET")
fi

echo "Using iPhone simulator: $IOS_UDID"
echo "Running: ${TEST_ARGS[*]:-all tests}"
echo "Log: $LOG_FILE"
echo

if [[ $BOOT_WATCH_RUNTIME -eq 1 ]]; then
  echo "Booting iPhone + Watch simulators and launching apps via start-dreamweaver.sh..."
  "$ROOT_DIR/start-dreamweaver.sh" > "$DERIVED_DATA_DIR/last-watch-runtime-boot.log" 2>&1
  echo "Runtime boot complete."
  echo
fi

# The watch shares Shared/ with the app, so a watch-breaking change must fail here too.
if [[ $WATCH_BUILD -eq 1 ]]; then
  echo "Compiling the Watch app to check the shared sources..."
  if ! xcodebuild build \
        -project "$PROJECT_FILE" \
        -scheme "$WATCH_SCHEME" \
        -destination 'generic/platform=watchOS Simulator' \
        -derivedDataPath "$DERIVED_DATA_DIR" \
        > "$DERIVED_DATA_DIR/last-watch-build.log" 2>&1; then
    echo "WATCH BUILD FAILED" >&2
    grep -E "error:" "$DERIVED_DATA_DIR/last-watch-build.log" | sort -u | head -20 >&2
    exit 1
  fi
  echo "Watch app compiles."
  echo
fi

set +e
DREAMWEAVER_DISABLE_WCSESSION=1 xcodebuild test \
  -project "$PROJECT_FILE" \
  -scheme "$SCHEME" \
  -destination "platform=iOS Simulator,id=$IOS_UDID" \
  -parallel-testing-enabled NO \
  -derivedDataPath "$DERIVED_DATA_DIR" \
  "${TEST_ARGS[@]}" \
  > "$LOG_FILE" 2>&1
TEST_STATUS=$?
set -e

# xcodebuild logs a case once per repetition, so only unique names are counted.
# `grep` exits non-zero when nothing matches, which under `pipefail` would abort the
# script on a clean run, hence the explicit fallbacks.
count_unique() {
  { grep -oE "$1" "$LOG_FILE" || true; } | sort -u | wc -l | tr -d ' '
}

PASSED="$(count_unique "Test case '[^']+' passed")"
FAILED="$(count_unique "Test case '[^']+' failed")"

echo "------------------------------------------------------------"
if [[ $FAILED -gt 0 || $TEST_STATUS -ne 0 ]]; then
  echo "TESTS FAILED  —  passed: $PASSED, failed: $FAILED"
  echo
  { grep -E "' failed on '|error:|Issue recorded" "$LOG_FILE" || true; } | sort -u | head -40
  echo
  echo "Full log: $LOG_FILE"
  exit 1
fi

echo "ALL TESTS PASSED  —  $PASSED tests"
{ grep -oE "Test case '[^']+' passed" "$LOG_FILE" || true; } \
  | sed "s/Test case '//; s/' passed//" \
  | sort -u \
  | sed 's|/.*||' \
  | sort | uniq -c | sort -rn \
  | awk '{ printf "  %-34s %s\n", $2, $1 }'
echo "------------------------------------------------------------"
