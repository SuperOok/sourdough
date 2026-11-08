#!/bin/zsh
# Prints the UDID of the reference simulator: an iPhone 15 under the newest
# installed iOS 27 runtime. Creates it if there is none. The preinstalled
# iPhone 15 only has iOS 17, which cannot load the app (deployment target
# 27.0), and device names are not unique, so the other tools take the id
# from here.
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
python3 - <<'PY'
import json, re, subprocess, sys

def simctl(*args):
    return subprocess.run(["xcrun", "simctl", *args], capture_output=True, text=True, check=True).stdout

runtimes = [r for r in json.loads(simctl("list", "runtimes", "available", "-j"))["runtimes"]
            if re.search(r"iOS-27-\d+$", r["identifier"])]
if not runtimes:
    sys.exit("No iOS 27 runtime installed.")
runtime = max(runtimes, key=lambda r: [int(n) for n in r["version"].split(".")])
devices = json.loads(simctl("list", "devices", "available", "-j"))["devices"][runtime["identifier"]]
phones = [d for d in devices if d["name"] == "iPhone 15"]
if phones:
    print(phones[0]["udid"])
else:
    print(simctl("create", "iPhone 15", "com.apple.CoreSimulator.SimDeviceType.iPhone-15",
                 runtime["identifier"]).strip())
PY
