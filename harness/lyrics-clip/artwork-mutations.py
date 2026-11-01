#!/usr/bin/env python3
"""Prove the exact-raster and decoded resting-line checks reject broken production encoders."""
import os
import argparse
from pathlib import Path
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
CASES = [
    ("cover-ratio",
     "CGFloat blocks = MAX(floor(pixels / (3 * 16)), 1);\n"
     "    return CGSizeMake(blocks * 3 * 16, blocks * 4 * 16);",
     "CGFloat width = MAX(floor(pixels / 16) * 16, 16);\n"
     "    return CGSizeMake(width, round(width * 4 / 3 / 16) * 16);",
     [], "fallback raster for 1170 pixels is exactly 3:4 and encoder-aligned"),
    ("motion-ratio",
     "CGFloat units = floor(MIN(stored.width / 6, stored.height / 8));\n"
     "    *motion = (Motion){stored, CGSizeMake(units * 6, units * 8), length};",
     "CGFloat width = MIN(stored.width, stored.height * .75);\n"
     "    *motion = (Motion){stored, CGSizeMake(floor(width / 2) * 2, floor(width / .75 / 2) * 2), length};",
     ["motion"], "motion clip is exactly 3:4 with even sides inside the source"),
    ("encoded-rest",
     "fitBand(asset, motion, &over, from, seconds);\n    __block BOOL ok = YES, any = NO;",
     "fitBand(asset, motion, &over, from, seconds);\n"
     "    if (!line.length && next.length) { CGImageRelease(over.words); over.words = NULL; }\n"
     "    __block BOOL ok = YES, any = NO;",
     ["motion"], "the lone next line is centred 40% down the screen inside 17–65%"),
]

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--case", choices=[case[0] for case in CASES], help="run one mutation")
selected = parser.parse_args().case
for name, before, after, args, expected in CASES:
    if selected and name != selected:
        continue
    with tempfile.TemporaryDirectory(prefix=f"lyrics-{name}-") as temp:
        work = Path(temp)
        src = work / "Sources"
        shutil.copytree(ROOT / "tweak/Sources", src)
        target = src / "Shared/LockScreenLyrics/SGLyricsClip.m"
        text = target.read_text()
        if text.count(before) != 1:
            raise SystemExit(f"{name}: mutation anchor is not unique")
        target.write_text(text.replace(before, after))
        out = work / "build"
        env = dict(os.environ, SRC=str(src), OUT=str(out))
        subprocess.run(["sh", str(ROOT / "harness/lyrics-clip/build.sh")], env=env, check=True)
        result = subprocess.run([str(out / "lyrics-clip"), *args], text=True,
                                stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
        failures = [line.strip() for line in result.stdout.splitlines() if line.strip().startswith("FAIL ")]
        if result.returncode != 1 or not any(expected in line for line in failures):
            print(result.stdout)
            raise SystemExit(f"{name}: did not fail at its regression boundary")
        print(f"mutation caught: {name} (exit {result.returncode})", flush=True)
        for failure in dict.fromkeys(failures):
            print(failure, flush=True)
