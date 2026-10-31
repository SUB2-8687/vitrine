#!/usr/bin/env python3
"""Each guarded rule of the Player page broken once, in a copy of the sources: settings-check.sh must fail on the check
that guards it.

    THEOS=$HOME/theos python3 harness/player/settings-mutation-check.py
"""
import os
import argparse
import shutil
import subprocess
import sys
import tempfile
import json
import signal
import time
from pathlib import Path

HERE = Path(__file__).resolve().parent
SOURCES = HERE.parent.parent / "tweak" / "Sources"
SETTINGS = "Redesigned/Player/PlayerSettings.m"
MOTION = "Redesigned/Player/PlayerMotion.x"
VISUALISER = "Redesigned/Player/PlayerVisualiser.m"

# (what is broken, the text replaced in PlayerSettings.m, its replacement, the check that must say WRONG)
MUTATIONS = [
    (SETTINGS, "Song without a clip turns the full-screen cover on without turning the Visualizer off first",
     "if (choice != SGRNoClipVisualiser && SGRPlayerAnimatedVisualiserOn()) {",
     "if (NO && SGRPlayerAnimatedVisualiserOn()) {",
     "the two switches never stored on together"),
    (SETTINGS, "the demo's tap sends the player a command",
     "- (void)toggleDemo {\n",
     "- (void)toggleDemo {\n    [SGPlayer() pause:nil];\n",
     "no command sent to the player"),
    (SETTINGS, "a track change invalidates the artwork request it just started",
     "    NSUInteger generation = _generation;\n    __weak SGRPlayerPreview *weakSelf = self;\n    dispatch_async",
     "    NSUInteger generation = ++_generation;\n    __weak SGRPlayerPreview *weakSelf = self;\n    dispatch_async",
     "no playback: the last song's title and delayed cover"),
    (SETTINGS, "rows can draw and receive touches above the pinned card",
     "CGFloat topCoverHeight = CGRectGetMinY(frame) - CGRectGetMinY(table.bounds);",
     "CGFloat topCoverHeight = 0;",
     "scrolled rows above the preview bottom are neither visible nor hit-testable"),
    (MOTION, "the preview borrows the previous track during real-player handover",
     "if (sg_motionFile && [track isEqualToString:sg_shown])",
     "if (sg_motionFile)",
     "handover: no old preview clip while the real player keeps its clip"),
    (MOTION, "preview teardown leaves the decoder and pending lookup alive",
     "void SGRPlayerMotionPreviewStop(void) {\n",
     "void SGRPlayerMotionPreviewStop(void) {\n    return;\n",
     "covered: the preview decoder is released"),
    (SETTINGS, "compact scrolling invalidates the unchanged preview",
     "if (!CGRectEqualToRect(self.preview.frame, card)) self.preview.frame = card;",
     "if (!CGRectEqualToRect(self.preview.frame, card)) self.preview.frame = card;\n    else [self.preview setNeedsLayout];",
     "compact scrolling does no preview layout or background resize"),
    (SETTINGS, "collapsing resizes the background render surface",
     "CGRect backgroundBounds = CGRectMake(0, 0, w, kPreviewExpandedHeight);",
     "CGRect backgroundBounds = bounds;",
     "collapsing does no background resize or text measurement"),
    (SETTINGS, "scrolling measures the demo button text again",
     "CGSize demo = _demoSize;",
     "CGSize demo = [_demoButton sizeThatFits:CGSizeMake(middleWidth, kHeaderRow)];",
     "collapsing does no background resize or text measurement"),
    (VISUALISER, "dismissal retains the preview visualizer and its artwork observer",
     "void SGRPlayerVisualiserPreviewStop(void) {\n",
     "void SGRPlayerVisualiserPreviewStop(void) {\n    return;\n",
     "dismissed visualizer is deallocated and artwork requests no preview palette"),
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", choices=[mutation[1] for mutation in MUTATIONS], action="append",
                        help="rerun a failed mutation without repeating valid passes")
    only = parser.parse_args().only
    # This runner owns the copied sources, object cache and simulator; settings-check
    # still owns the scenario and verdict, identically to its standalone invocation.
    def interrupted(signum, frame):
        raise KeyboardInterrupt

    signal.signal(signal.SIGTERM, interrupted)
    failed = False
    with tempfile.TemporaryDirectory(prefix="player-settings-mutation.") as work:
        sources = Path(work) / "Sources"
        shutil.copytree(SOURCES, sources)
        runtimes = json.loads(subprocess.check_output(["xcrun", "simctl", "list", "runtimes", "available", "-j"]))
        runtime = [r["identifier"] for r in runtimes["runtimes"] if r["identifier"].startswith("com.apple.CoreSimulator.SimRuntime.iOS-")][-1]
        udid = subprocess.check_output(["xcrun", "simctl", "create", "PlayerSettingsMutations-%d" % os.getpid(),
                                       "com.apple.CoreSimulator.SimDeviceType.iPhone-17-Pro", runtime], text=True).strip()
        try:
            subprocess.run(["xcrun", "simctl", "boot", udid], check=True)
            subprocess.run(["xcrun", "simctl", "bootstatus", udid], check=True, stdout=subprocess.DEVNULL)
            for source, name, original, broken, guard in MUTATIONS:
                if only and name not in only:
                    continue
                failed = run_mutation(work, sources, udid, source, name, original, broken, guard) or failed
        finally:
            try:
                subprocess.run(["xcrun", "simctl", "shutdown", udid], check=True)
            finally:
                subprocess.run(["xcrun", "simctl", "delete", udid], check=True)
    print("settings mutations: %s" % ("FAIL" if failed else "PASS"))
    return 1 if failed else 0


def run_mutation(work, sources, udid, source, name, original, broken, guard):
    started = time.monotonic()
    target = sources / source
    text = target.read_text()
    if text.count(original) != 1:
        print("mutation %r: the text to break is not in %s once" % (name, source))
        return True
    target.write_text(text.replace(original, broken))
    env = dict(os.environ, SRC=str(sources), PLAYER_SETTINGS_WORK=work,
               PLAYER_SETTINGS_UDID=udid, PLAYER_INCREMENTAL="1")
    env.pop("SHOTS", None)  # Never overwrite deliverable screenshots with a deliberately broken build.
    try:
        run = subprocess.Popen(["sh", str(HERE / "settings-check.sh")], env=env,
                               stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True,
                               start_new_session=True)
        try:
            output, _ = run.communicate()
        except BaseException:
            os.killpg(run.pid, signal.SIGTERM)
            run.wait()
            raise
    finally:
        target.write_text(text)
    # Reinstall into an empty container next time, just like the standalone run.
    subprocess.run(["xcrun", "simctl", "uninstall", udid, "com.vojta.playerharness"], check=True)
    caught = run.returncode != 0 and any(guard in line and line.endswith("-- WRONG") for line in output.splitlines())
    print("mutation %r: %s" % (name, "caught by \"%s\"" % guard if caught else "NOT CAUGHT"), flush=True)
    print("mutation wall time: %.1f s" % (time.monotonic() - started), flush=True)
    if not caught:
        print(output, flush=True)
    return not caught


if __name__ == "__main__":
    sys.exit(main())
