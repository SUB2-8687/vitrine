#!/usr/bin/env python3
"""One rule of each AutoMix area broken once, in a copy of the sources: automix-check.sh must fail on the check that
guards it.

    THEOS=$HOME/theos python3 harness/player/automix-mutation-check.py [--only NAME]
"""
import argparse
import os
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
SOURCES = HERE.parent.parent / "tweak" / "Sources"
MIX = "Redesigned/Player/PlayerMix.x"
QUEUE = "Redesigned/Player/PlayerQueue.m"
PREVIEW = "Shared/AutoMix/AutoMixPreview.m"

# The sliders' bands shared as one pair again: whichever slider lays out takes the pair into itself and places it anew.
SHARED_BANDS = [
    ("static SGRMixBands *bandsOf(UISlider *slider) {\n    return objc_getAssociatedObject(slider, &kBandsKey);\n}",
     "static SGRMixBands *sg_shared;\nstatic SGRMixBands *bandsOf(UISlider *slider) {\n    return sg_shared;\n}"),
    ("objc_setAssociatedObject(slider, &kBandsKey, bands, OBJC_ASSOCIATION_RETAIN_NONATOMIC);", "sg_shared = bands;"),
    ("    CGFloat start = barX(", "    if (band.superview != slider) [slider insertSubview:band atIndex:0];\n    CGFloat start = barX("),
    ("    [sg_sliders addObject:slider];",
     "    static __weak UISlider *last;\n    if (last != slider) {\n        last = slider;\n        sg_generation++;\n    }\n"
     "    [sg_sliders addObject:slider];"),
]
HIDDEN_DRAWS = [("if (!sg_progressOn || !slider.window || hiddenUp(slider)) {", "if (!sg_progressOn) {")]

# (file, what is broken, each text replaced with its replacement, the check that must say WRONG)
MUTATIONS = [
    (MIX, "the progress bar draws a window whose times are unknown",
     [("BOOL outgoing = facts.timesKnown && SGRMixTrackIs(", "BOOL outgoing = SGRMixTrackIs(")],
     "progress unknown times draw nothing"),
    (MIX, "the bands as they hung the phone: one pair for every slider, hidden ones included",
     SHARED_BANDS + HIDDEN_DRAWS,
     "progress three sliders, one shown: layout settles"),
    (MIX, "the shown sliders share one pair of bands",
     SHARED_BANDS,
     "progress two sliders shown: each its own bands, layout settles"),
    (MIX, "a hidden slider makes and places bands",
     HIDDEN_DRAWS,
     "progress hidden sliders do nothing"),
    (QUEUE, "the queue names a blend into a song that is not the first row",
     [("\n        || !SGRMixTrackIs(next, facts.toURI, facts.toUID)) return nil;", ") return nil;")],
     "queue facts for another pair"),
    (MIX, "a seek back leaves the cover hidden under a stage that stopped moving",
     [('[self stop:@"a seek back before the window" done:NO];', "[_link invalidate];\n            _link = nil;\n            _view = nil;")],
     "artwork a seek back hands the cover back"),
    (MIX, "a stage keeps the cover hidden while the player is not seen, as long as it is in a window",
     [("return !sg_artworkOn || !seen(view) ||", "return !sg_artworkOn || !view.window ||")],
     "artwork a hidden player hands the cover back"),
    (MIX, "a stage keeps its plan after the facts named another next song",
     [("            if (_plan != sg_facts) {\n                [self stop:@\"the facts changed\" done:NO];\n                return;\n            }\n", "")],
     "artwork a new next song hands the cover back"),
    (PREVIEW, "the preview's overlap ignores Blend length",
     [("length = off ? 0 : _shown.seconds;", "length = off ? 0 : 5;")],
     "preview crossfade 1 s, changed in Spotify's settings"),
]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--only", choices=[mutation[1] for mutation in MUTATIONS], action="append",
                        help="rerun a failed mutation without repeating valid passes")
    only = parser.parse_args().only
    failed = False
    for source, name, edits, guard in MUTATIONS:
        if only and name not in only:
            continue
        with tempfile.TemporaryDirectory(prefix="player-automix-mutation.") as work:
            sources = Path(work) / "Sources"
            shutil.copytree(SOURCES, sources)
            target = sources / source
            text = target.read_text()
            missing = [original for original, _ in edits if text.count(original) != 1]
            if missing:
                print("mutation %r: the text to break is not in %s once: %r" % (name, source, missing))
                failed = True
                continue
            for original, broken in edits:
                text = text.replace(original, broken)
            target.write_text(text)
            env = dict(os.environ, SRC=str(sources))
            run = subprocess.run(["sh", str(HERE / "automix-check.sh")], env=env,
                                 stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True)
            caught = run.returncode != 0 and any(guard in line and line.endswith("-- WRONG") for line in run.stdout.splitlines())
            print("mutation %r: %s" % (name, "caught by \"%s\"" % guard if caught else "NOT CAUGHT"), flush=True)
            if not caught:
                print(run.stdout, flush=True)
                failed = True
    print("automix mutations: %s" % ("FAIL" if failed else "PASS"))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
