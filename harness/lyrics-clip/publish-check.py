#!/usr/bin/env python3
"""Run the real Now Playing harness plus the lyric publication regression; optionally mutate the fix."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import sys

ROOT = Path(__file__).resolve().parents[2]
with tempfile.TemporaryDirectory(prefix="lyrics-publish-") as temp:
    work = Path(temp)
    harness = work / "harness" / "now-playing"
    shutil.copytree(ROOT / "harness/now-playing", harness, ignore=shutil.ignore_patterns("build"))
    for name in ("harness-fail.h", "sha256-fixture.h"):
        shutil.copy2(ROOT / "harness" / name, harness.parent / name)
    artwork = harness / "artwork.m"
    source = artwork.read_text()
    anchor = "void artworkChecks(void) {"
    if source.count(anchor) != 1:
        raise SystemExit("artworkChecks definition changed")
    sources = 'NSArray *SGMotionSourceOrder(void) { return @[@"canvas"]; }'
    if source.count(sources) != 1:
        raise SystemExit("motion source double changed")
    source = source.replace(sources, 'extern BOOL harnessMotionSourcesOff;\n'
        'NSArray *SGMotionSourceOrder(void) { return harnessMotionSourcesOff ? @[] : @[@"canvas"]; }')
    renderer = """CGImageRef SGLyricsClipFrameWithLayout(CGImageRef backdrop, CGImageRef cover, NSString *previous, NSString *line,
                                       NSString *translation, NSString *next, CGSize size, SGLyricsClipLayout layout) {
    return CGImageRetain(backdrop);
}"""
    if source.count(renderer) != 1:
        raise SystemExit("renderer double definition changed")
    source = source.replace(renderer,
        "CGImageRef harnessPublicationFrame(NSString *, CGImageRef);\n" +
        renderer.replace("return CGImageRetain(backdrop);", "return harnessPublicationFrame(line, backdrop);"))
    # Run after fixture initialization and existing tests; its function can see those file-local doubles.
    source += "\n" + (ROOT / "harness/lyrics-clip/publish-check.inc").read_text()
    source += "\nvoid lyricPublishChecks(void) { publishSequenceChecks(); }\n"
    artwork.write_text(source)
    main = harness / "main.m"
    main.write_text(main.read_text().replace("    sg_system = info;",
        "    extern void harnessRecordPublished(NSDictionary *);\n    harnessRecordPublished(info);\n    sg_system = info;")
        .replace("        activityChecks();",
        "        activityChecks();\n        extern void lyricPublishChecks(void);\n        lyricPublishChecks();"))
    src = ROOT / "tweak/Sources"
    mutations = {
        "--mutate-identity": ("composed[MPMediaItemPropertyArtwork] = still;",
            "MPMediaItemArtwork *fresh = [[MPMediaItemArtwork alloc] initWithBoundsSize:still.bounds.size "
            "requestHandler:^UIImage *(CGSize wanted) { return [still imageWithSize:wanted]; }];\n"
            "        objc_setAssociatedObject(fresh, &sg_nativeKey, native ?: NSNull.null, OBJC_ASSOCIATION_RETAIN_NONATOMIC);\n"
            "        composed[MPMediaItemPropertyArtwork] = fresh;",
            "FAIL same lyric ID retains its static artwork across Spotify and extras resends"),
        "--mutate": ("MPMediaItemArtwork *still = objc_getAssociatedObject(animated, &sg_stillKey);",
                     "MPMediaItemArtwork *still = nil;",
                     "FAIL first lyric publication has a composed ordinary artwork fallback"),
        "--mutate-native": ("id native = nativeArtwork(shown);", "id native = shown;",
                            "FAIL direct Lyrics to Every song uses native cover without a Spotify artwork update"),
        "--mutate-main": ("return previous;", "return previewFor(artworkID, line, size);",
                          "FAIL ordinary artwork never renders on the main request thread"),
    }
    selected = next((flag for flag in mutations if flag in sys.argv), None)
    if selected:
        src = work / "Sources"
        shutil.copytree(ROOT / "tweak/Sources", src)
        target = src / "Shared/LockScreenLyrics/LyricsArtwork.x"
        text = target.read_text()
        before, after, expected = mutations[selected]
        if text.count(before) != 1:
            raise SystemExit("publication mutation anchor changed")
        target.write_text(text.replace(before, after))
    env = dict(os.environ, SRC=str(src), OUT=str(work / "out"))
    result = subprocess.run(["sh", str(harness / "build.sh")], env=env, text=True,
                            stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    print(result.stdout)
    if selected:
        if result.returncode == 0 or expected not in result.stdout:
            raise SystemExit("publication mutant did not fail at the fallback boundary")
        print(f"mutation caught: {selected}: {expected}")
    elif result.returncode:
        raise SystemExit(result.returncode)
