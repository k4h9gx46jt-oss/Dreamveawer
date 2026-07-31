#!/usr/bin/env bash
set -euo pipefail

# Gate for launching DreamWeaver: runs the iPhone and Watch test suites first and
# only starts the apps when everything passes.
#
# Usage:
#   ./test-and-start.sh              # unit tests + Watch compile check, then launch
#   ./test-and-start.sh --watch      # only the Watch sleep-staging suite, then launch
#   ./test-and-start.sh --all        # unit and UI tests, then launch
#   ./test-and-start.sh --skip-tests # launch straight away
#
# Any other options are forwarded to run-tests.sh.

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
TEST_SCRIPT="$ROOT_DIR/run-tests.sh"
START_SCRIPT="$ROOT_DIR/start-dreamweaver.sh"

for script in "$TEST_SCRIPT" "$START_SCRIPT"; do
  if [[ ! -x "$script" ]]; then
    echo "Required script is missing or not executable: $script" >&2
    exit 1
  fi
done

SKIP_TESTS=0
TEST_ARGS=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-tests) SKIP_TESTS=1; shift ;;
    -h|--help)
      sed -n '3,12p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *) TEST_ARGS+=("$1"); shift ;;
  esac
done

if [[ $SKIP_TESTS -eq 0 ]]; then
  echo "=============================================================="
  echo " Step 1/2  —  Running the DreamWeaver test suites"
  echo "=============================================================="
  if ! "$TEST_SCRIPT" ${TEST_ARGS[@]+"${TEST_ARGS[@]}"}; then
    echo
    echo "Tests failed, so the apps were not launched." >&2
    exit 1
  fi
  echo
else
  echo "Skipping tests on request."
  echo
fi

echo "=============================================================="
echo " Step 2/2  —  Building and launching DreamWeaver"
echo "=============================================================="
exec "$START_SCRIPT"
