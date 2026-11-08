#!/bin/zsh
# Storey one: the calculation logic in SourdoughKit. No Xcode project, no
# simulator, seconds.
#
#   tools/tests.sh            summary, plus any failure
#   tools/tests.sh -v         every test case by name
cd "${0:A:h}/.."

OUT=$(cd SourdoughKit && swift test 2>&1)
STATUS=$?

if [[ "$1" == "-v" ]]; then
  print -r -- "$OUT" | grep -E '^(✔|✘) Test ' | sort
else
  print -r -- "$OUT" | grep -E '^✘' | grep -v 'Test run with' || true
fi

if ! print -r -- "$OUT" | grep -E 'Test run with'; then
  print -r -- "$OUT" | tail -25
fi
exit $STATUS
