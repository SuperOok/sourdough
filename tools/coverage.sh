#!/bin/zsh
# Runs all three storeys with coverage measurement and fails if any source
# file in SourdoughKit/Sources or Sourdough/ is below 100 % line coverage.
#
#   tools/coverage.sh              the reference device
#   tools/coverage.sh <UDID>       some other simulator
#
# Exceptions live in EXCLUDE below, each with its reason. `#Preview` blocks
# are not measured by xccov in practice and need no entry.
cd "${0:A:h}/.."

DEVICE="${1:-$("${0:A:h}/simulator.sh")}"
# Parallel testing is off by default: on a 16 GB MacBook Air it made single
# tests up to ten times slower. `PARALLEL=YES WORKERS=<n>` turns it on.
PARALLEL="${PARALLEL:-NO}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"

# Files excluded from the 100 % rule, one regex per line, with the reason.
EXCLUDE=(
  # (none)
)

rm -rf coverage && mkdir coverage
FAIL=0

# Storey one: SourdoughKit.
( cd SourdoughKit && swift test --enable-code-coverage >/dev/null 2>&1 ) || { print "SourdoughKit tests failed"; exit 1; }
PROF=$(cd SourdoughKit && swift test --show-codecov-path 2>/dev/null)
python3 - "$PROF" <<'PY' || FAIL=1
import json, sys
data = json.load(open(sys.argv[1]))["data"][0]["files"]
bad = 0
for f in data:
    if "/Sources/SourdoughKit/" not in f["filename"]:
        continue
    pct = f["summary"]["lines"]["percent"]
    name = f["filename"].split("/Sources/")[1]
    print(f"{pct:6.1f} %  {name}")
    if pct < 100: bad = 1
sys.exit(bad)
PY

# Storeys two and three: app, app tests and interface tests in one run.
xcodebuild test \
  -project Sourdough.xcodeproj -scheme Sourdough \
  -destination "platform=iOS Simulator,id=$DEVICE" \
  -parallel-testing-enabled "$PARALLEL" -parallel-testing-worker-count "${WORKERS:-2}" \
  -enableCodeCoverage YES -resultBundlePath coverage/app.xcresult \
  >coverage/app.log 2>&1 || { tail -25 coverage/app.log; exit 1; }

xcrun xccov view --report --json coverage/app.xcresult > coverage/app.json
python3 - "${EXCLUDE[@]}" <<'PY' || FAIL=1
import json, re, sys
excl = [re.compile(p) for p in sys.argv[1:]]
bad = 0
for t in json.load(open("coverage/app.json"))["targets"]:
    if t["name"] != "Sourdough.app":
        continue
    for f in t["files"]:
        if any(e.search(f["path"]) for e in excl):
            continue
        pct = f["lineCoverage"] * 100
        print(f"{pct:6.1f} %  {f['name']}")
        if pct < 100: bad = 1
sys.exit(bad)
PY

(( FAIL )) && print "Coverage below 100 %." || print "Coverage 100 %."
exit $FAIL
