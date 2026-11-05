#!/bin/sh
# The redesign's Player page (main.m's settings scenario) in a simulator of its own, made for the run and deleted after
# it. Exits nonzero unless the scenario ends with "settings checks: n of n right -- PASS".
#     THEOS=$HOME/theos sh harness/player/settings-check.sh
# SRC=<tweak/Sources> builds other sources. APPEARANCE=light|dark and CONTENT_SIZE (a
# `simctl ui content_size` value, accessibility-extra-extra-extra-large for the largest text) are set on the simulator
# before the run, and SHOTS=<dir> keeps a screenshot of each state the scenario names (settings: screenshot <name> now).
set -eu
HERE=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
WORK=${PLAYER_SETTINGS_WORK:-$(mktemp -d "${TMPDIR:-/tmp}/player-settings.XXXXXX")}
if [ -z "${PLAYER_SETTINGS_WORK:-}" ]; then trap 'rm -rf "$WORK"' EXIT; fi
OUT="$WORK/build" sh "$HERE/build.sh" > "$WORK/build.log" 2>&1 || { cat "$WORK/build.log"; exit 1; }
# A clip taller than wide, as a Canvas is.
if [ ! -f "$WORK/clip.mp4" ]; then
xcrun --sdk macosx clang -fobjc-arc "$HERE/settings-clip.m" \
    -framework Foundation -framework AVFoundation -framework CoreMedia -framework CoreVideo \
    -o "$WORK/settings-clip"
"$WORK/settings-clip" "$WORK/clip.mp4"
fi

UDID=${PLAYER_SETTINGS_UDID:-}
if [ -z "$UDID" ]; then
TYPE=$(xcrun simctl list devicetypes | sed -n 's/.*(\(com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro\))$/\1/p' | head -1)
RUNTIME=$(xcrun simctl list runtimes available | sed -n 's/.* - \(com.apple.CoreSimulator.SimRuntime.iOS-[0-9-]*\)$/\1/p' | tail -1)
UDID=$(xcrun simctl create "PlayerSettings-$$" "$TYPE" "$RUNTIME")
trap 'xcrun simctl shutdown "$UDID" >/dev/null 2>&1; xcrun simctl delete "$UDID" >/dev/null 2>&1; rm -rf "$WORK"' EXIT
xcrun simctl boot "$UDID"
xcrun simctl bootstatus "$UDID" > /dev/null
fi
xcrun simctl install "$UDID" "$WORK/build/PlayerHarness.app"
if [ -n "${APPEARANCE:-}" ]; then xcrun simctl ui "$UDID" appearance "$APPEARANCE"; fi
if [ -n "${CONTENT_SIZE:-}" ]; then xcrun simctl ui "$UDID" content_size "$CONTENT_SIZE"; fi

# The scenario's log, line by line as it comes: each screenshot it names, and its verdict. The scenario exits by itself
# in about a minute; three are allowed.
python3 - "$UDID" "$WORK/clip.mp4" "${SHOTS:-}" <<'PY'
import os, re, subprocess, sys, threading
udid, clip, shots = sys.argv[1:4]
env = dict(os.environ, SIMCTL_CHILD_HARNESS_SCENARIO="settings", SIMCTL_CHILD_HARNESS_CANVAS_FILE=clip)
launch = subprocess.Popen(["xcrun", "simctl", "launch", "--console-pty", udid, "com.vojta.playerharness"],
                          stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, env=env)
watchdog = threading.Timer(180, launch.kill)
watchdog.start()
verdict = None
for line in launch.stdout:
    if "[harness]" in line:
        print(line.rstrip(), flush=True)
    shot = re.search(r"settings: screenshot (\S+) now", line)
    if shot and shots:
        os.makedirs(shots, exist_ok=True)
        subprocess.run(["xcrun", "simctl", "io", udid, "screenshot", os.path.join(shots, shot.group(1) + ".png")],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    result = re.search(r"settings checks: (\d+) of (\d+) right -- (PASS|FAIL)", line)
    if result:
        verdict = result.group(3)
    if verdict:
        break
watchdog.cancel()
launch.kill()
launch.wait()
if verdict != "PASS":
    print("FAILED: player settings (%s)" % (verdict or "no verdict in 180 s"), flush=True)
    sys.exit(1)
PY
