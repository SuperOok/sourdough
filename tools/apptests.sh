#!/bin/zsh
# Storey two: the app-layer tests of the target `SourdoughTests`. They run in
# the simulator with the app as host, without interface.
#
#   tools/apptests.sh              the reference device
#   tools/apptests.sh <UDID>       some other simulator
#
# The destination is given by id, never by name: device names are not unique.
# `xcrun simctl list devices available` shows the UDIDs.
cd "${0:A:h}/.."

# Reference device: iPhone 15 (393 x 852 points), iOS 27; see tools/simulator.sh.
DEVICE="${1:-$("${0:A:h}/simulator.sh")}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

OUT=$(xcodebuild test \
        -project Sourdough.xcodeproj \
        -scheme Sourdough \
        -destination "platform=iOS Simulator,id=$DEVICE" \
        -only-testing:SourdoughTests 2>&1)
STATUS=$?

print -r -- "$OUT" | grep -E '^✘' | grep -v 'Test run with' || true
print -r -- "$OUT" | grep -E 'Test run with'
print -r -- "$OUT" | grep -E "^.*: error:" || true

if (( STATUS != 0 )); then
  print -r -- "$OUT" | tail -25
fi
exit $STATUS
