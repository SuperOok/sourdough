#!/bin/zsh
# Storey three: the whole scheme — the interface tests of `SourdoughUITests`
# and with them the app tests. Needs a simulator and takes minutes;
# `tools/apptests.sh` runs the app tests alone.
#
#   tools/uitests.sh              the reference device
#   tools/uitests.sh <UDID>       some other simulator
#
# If the live view of the simulator runs in the Claude app, the tests get
# slow enough for single cases to time out; such a case usually passes alone
# (`-only-testing:`) and is no code defect.
cd "${0:A:h}/.."

DEVICE="${1:-$("${0:A:h}/simulator.sh")}"
# Parallel testing is off by default: on a 16 GB MacBook Air it made single
# tests up to ten times slower. `PARALLEL=YES WORKERS=<n>` turns it on.
PARALLEL="${PARALLEL:-NO}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

OUT=$(xcodebuild test \
        -project Sourdough.xcodeproj \
        -scheme Sourdough \
        -destination "platform=iOS Simulator,id=$DEVICE" \
        -parallel-testing-enabled "$PARALLEL" -parallel-testing-worker-count "${WORKERS:-2}" 2>&1)
STATUS=$?

print -r -- "$OUT" | grep -E "^Test Case .* (passed|failed)" | sort
print -r -- "$OUT" | grep -E '^(✔|✘) Test run with' || true
print -r -- "$OUT" | grep -E "^.*: error:" || true

if (( STATUS != 0 )); then
  print -r -- "$OUT" | tail -25
fi
exit $STATUS
