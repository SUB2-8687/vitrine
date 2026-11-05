#!/usr/bin/env python3
"""Choose and run the Mac harnesses a change needs.

The harness list lives here (one place).  For each harness the tweak files it
builds are derived from its build scripts and the quoted imports of its own
sources, then closed over quoted imports.  ``plan`` prints a GitHub Actions
matrix (at most five shards) and ``run`` executes one shard sequentially.
Python 3 standard library only: the plan job runs on ubuntu with no Apple SDK.

    harness-plan.py explain <path>...
    harness-plan.py plan --changed-from <file|-> [--all] [--github-output PATH]
    harness-plan.py run --names "Pitch" "Palette"
    harness-plan.py run --shard 1/3 --names pitch,palette
"""

import argparse
import fcntl
import json
import os
import posixpath
import re
import shlex
import signal
import stat
import subprocess
import sys
import time
from contextlib import ExitStack, contextmanager
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
TWEAK = "tweak/Sources"

# CI names, commands and Theos requirements; ``dir`` is the harness directory.
# Explicit weights estimate CI minutes. Mutation checks prove a check catches its
# bug while it is written; they run by hand, not on every push.
HARNESSES = [
    {"name": "AutoMix facts", "dir": "automix",
     "run": "sh harness/automix/check.sh"},
    {"name": "Album notes", "dir": "album-notes", "theos": True,
     "run": "bash harness/album-notes/build.sh"},
    {"name": "Album counts", "dir": "album-counts",
     "run": "bash harness/album-counts/check.sh"},
    {"name": "Album cover", "dir": "album", "theos": True, "weight": 5,
     "run": "sh harness/album/cover-check.sh"},
    {"name": "Album faces and row more", "dir": "album", "theos": True, "weight": 16,
     "run": "sh harness/album/build.sh && sh harness/album/faces-more-check.sh"},
    {"name": "Appearance accent", "dir": "appearance-accent", "theos": True,
     "run": "bash harness/appearance-accent/check.sh"},
    {"name": "Appearance rows", "dir": "appearance-page",
     "run": "bash harness/appearance-page/rows-check.sh"},
    {"name": "Explicit badges", "dir": "ui-refinements", "theos": True,
     "run": "bash harness/ui-refinements/badge-check.sh"},
    {"name": "Settings search", "dir": "settings-search",
     "run": "sh harness/settings-search/build.sh"},
    {"name": "Home podcasts", "dir": "home-podcasts", "theos": True,
     "run": "bash harness/home-podcasts/check.sh"},
    {"name": "Settings bars inset", "dir": "settings-bars",
     "run": "sh harness/settings-bars/build.sh"},
    {"name": "Ad block hubs", "dir": "adblock", "theos": True,
     "run": "sh harness/adblock/build.sh"},
    {"name": "Free fonts registration", "dir": "fonts",
     "run": "sh harness/fonts/build.sh"},
    {"name": "Player visualiser", "dir": "player-visualiser",
     "run": "sh harness/player-visualiser/build.sh"},
    {"name": "Now playing bar text", "dir": "now-playing-bar", "theos": True,
     "run": "bash harness/now-playing-bar/check.sh"},
    {"name": "Artwork clear", "dir": "artwork-clear",
     "run": "sh harness/artwork-clear/build.sh"},
    {"name": "Meaning translation", "dir": "meaning-translate",
     "run": "sh harness/meaning-translate/build.sh"},
    {"name": "Artist artwork", "dir": "artist-artwork",
     "run": "bash harness/artist-artwork/build.sh"},
    {"name": "Artist photo", "dir": "artist-artwork", "theos": True,
     "run": "sh harness/artist-artwork/photo-check.sh"},
    {"name": "Artist cut-out Play", "dir": "artist",
     "run": "bash harness/artist/cutout-check.sh"},
    {"name": "Album credits", "dir": "album-credits",
     "run": "sh harness/album-credits/build.sh && harness/album-credits/build/album-credits-check"},
    {"name": "Audio effects routes", "dir": "audio-effects",
     "run": "sh harness/audio-effects/build.sh route && harness/audio-effects/build/route-check"},
    {"name": "Audio effects format text", "dir": "audio-effects",
     "run": "sh harness/audio-effects/build.sh format && harness/audio-effects/build/audio-format-check"},
    {"name": "Audio effects presets", "dir": "audio-effects",
     "run": "sh harness/audio-effects/build.sh presets && harness/audio-effects/build/preset-files-check"},
    {"name": "Automatic translation settings", "dir": "auto-translation-settings",
     "run": "sh harness/auto-translation-settings/check.sh"},
    {"name": "AutoEq offline", "dir": "autoeq",
     "run": "sh harness/autoeq/build.sh && harness/autoeq/build/autoeq-check"},
    {"name": "Clean links", "dir": "clean-links",
     "run": "sh harness/clean-links/build.sh && harness/clean-links/build/clean-links-check"},
    {"name": "Connection test settings", "dir": "connection-test-settings",
     "run": "sh harness/connection-test-settings/check.sh"},
    {"name": "Driver auth and redaction", "dir": "driver",
     "run": "sh harness/driver/auth-check.sh && sh harness/driver/command-check.sh && python3 harness/driver/phone-check.py"},
    {"name": "Fluid clips", "dir": "fluid-clip",
     "run": "sh harness/fluid-clip/build.sh && harness/fluid-clip/build/fluid-clip"},
    {"name": "Haptic track", "dir": "haptics",
     "run": "sh harness/haptics/build.sh && harness/haptics/build/track"},
    {"name": "Hangul pronunciation", "dir": "hangul-pronunciation",
     "run": "bash harness/hangul-pronunciation/check.sh && bash harness/hangul-pronunciation/settings.sh"},
    {"name": "Liveprog guard", "dir": "liveprog-guard",
     "run": "python3 harness/liveprog-guard/run.py"},
    {"name": "Gesture hold speed", "dir": "gesture-hold",
     "run": "sh harness/gesture-hold/check.sh"},
    {"name": "Head gestures", "dir": "head-gestures",
     "run": "sh harness/head-gestures/build.sh && harness/head-gestures/build/head-gestures"},
    {"name": "Keyboard commands", "dir": "keyboard-commands",
     "run": "sh harness/keyboard-commands/build.sh"},
    {"name": "Keyboard top controller", "dir": "keyboard-top-controller",
     "run": "sh harness/keyboard-top-controller/build.sh"},
    {"name": "Listening stats", "dir": "listening-stats", "theos": True,
     "run": "sh harness/listening-stats/build.sh && harness/listening-stats/build/listening-stats"},
    {"name": "Local files and LRC", "dir": "local-files", "theos": True,
     "run": "sh harness/local-files/build.sh"},
    {"name": "Local file Find Info", "dir": "local-files",
     "run": "python3 harness/local-files/suggest-build.py"},
    {"name": "Lyrics menu translation", "dir": "lyrics",
     "run": "sh harness/lyrics/translation-check.sh"},
    {"name": "Lyrics clips", "dir": "lyrics-clip",
     "run": "sh harness/lyrics-clip/build.sh && harness/lyrics-clip/build/lyrics-clip"},
    {"name": "Lyrics backgrounds", "dir": "lyrics-background",
     "run": "sh harness/lyrics-background/build.sh"},
    {"name": "Lyrics PiP text", "dir": "lyrics-pip", "theos": True,
     "run": "sh harness/lyrics-pip/build.sh && harness/lyrics-pip/build/lyrics-pip"},
    {"name": "Lyrics sources", "dir": "lyrics-sources",
     "run": "sh harness/lyrics-sources/build.sh"},
    {"name": "Genius lyrics", "dir": "genius-lyrics",
     "run": "sh harness/genius-lyrics/build.sh"},
    {"name": "Offline lyrics store", "dir": "lyrics-store",
     "run": "sh harness/lyrics-store/build.sh"},
    {"name": "Lyrics state and concurrent walk", "dir": "lyrics-sources",
     "run": "sh harness/lyrics-sources/state-build.sh"},
    {"name": "Lyrics translation and AI", "dir": "lyrics-translation",
     "run": "sh harness/lyrics-translation/build.sh && harness/lyrics-translation/build/check --auto-retry-only"},
    {"name": "On-device kept translation", "dir": "lyrics-translation",
     "run": "bash harness/lyrics-translation/ondevice-kept-check.sh"},
    {"name": "Moving artwork", "dir": "motion",
     "run": "sh harness/motion/build.sh && harness/motion/build/motion"},
    {"name": "Native declutter", "dir": "native-declutter",
     "run": "sh harness/native-declutter/check.sh"},
    {"name": "Now playing", "dir": "now-playing", "theos": True,
     "run": "sh harness/now-playing/build.sh"},
    {"name": "Palette", "dir": "palette",
     "run": "sh harness/palette/build.sh && harness/palette/build/palette-check"},
    {"name": "Player field palette", "dir": "palette",
     "run": "bash harness/palette/field-check.sh"},
    {"name": "Pitch", "dir": "pitch",
     "run": "sh harness/pitch/build.sh && harness/pitch/build/pitch"},
    {"name": "Player title notification", "dir": "player", "theos": True,
     "run": "sh harness/player/title-notification-check.sh"},
    {"name": "Player repeat transitions", "dir": "player",
     "run": "sh harness/player/repeat-check.sh"},
    {"name": "Player lyrics layout", "dir": "player",
     "run": "sh harness/player/lyrics-layout-check.sh"},
    {"name": "Player lyric line", "dir": "player-lyric-line",
     "run": "sh harness/player-lyric-line/build.sh"},
    {"name": "Player refinements", "dir": "player-refinements", "theos": True,
     "run": "sh harness/player-refinements/check.sh"},
    {"name": "Player upcoming tracks", "dir": "player",
     "run": "sh harness/player/upcoming-tracks-check.sh"},
    {"name": "Player settings", "dir": "player", "theos": True, "weight": 7,
     "run": "sh harness/player/settings-check.sh"},
    {"name": "Player AutoMix UI", "dir": "player", "theos": True, "weight": 11,
     "run": "sh harness/player/automix-check.sh"},
    {"name": "Preferences and counters", "dir": "prefs",
     "run": "sh harness/prefs/check.sh"},
    {"name": "Radio modes", "dir": "radio-modes",
     "run": "sh harness/radio-modes/build.sh"},
    {"name": "Song audio retention", "dir": "song-audio",
     "run": "sh harness/song-audio/build.sh"},
    {"name": "Sing model-free", "dir": "sing",
     "run": "sh harness/sing/build.sh && harness/sing/build/sing spatial"},
    {"name": "Sing render regressions", "dir": "sing",
     "run": "OUT=harness/sing/build/render sh harness/sing/render-regressions-build.sh"},
    {"name": "Sleep timer", "dir": "sleep-timer",
     "run": "sh harness/sleep-timer/build.sh && harness/sleep-timer/build/sleep-timer"},
    {"name": "Spicy lyrics", "dir": "spicy-lyrics",
     "run": "sh harness/spicy-lyrics/build.sh"},
    {"name": "UI refinements album menu", "dir": "ui-refinements", "theos": True,
     "run": "sh harness/ui-refinements/menu-check.sh"},
    {"name": "Update offline", "dir": "update",
     "run": "sh harness/update/offline-check.sh"},
    {"name": "Visualizer", "dir": "visualiser",
     "run": "sh harness/visualiser/build.sh && harness/visualiser/build/spectrum"},
]

SOURCE_SUFFIXES = {".m", ".mm", ".h", ".x", ".inc", ".c", ".cc", ".cpp"}
SKIP_PARTS = {"build", ".build"}

# Cross-directory executable-name collisions in the host build/check scripts.
# Bundled Catalyst checks have distinct CFBundleIdentifiers; bare executables
# use their process name even when CFFIXED_USER_HOME points somewhere else.
SHARED_PREFERENCE_DOMAINS = {
    "check": {
        "appearance-page", "driver", "fonts", "genius-lyrics", "gesture-hold", "local-files", "lyrics-sources",
        "lyrics-translation", "native-declutter", "player",
        "prefs", "radio-modes", "spicy-lyrics", "ui-refinements", "update",
    },
    "now-playing": {"local-files", "now-playing"},
    "state-check": {"lyrics-sources", "motion"},
}

HARNESS_TERMINATION_GRACE_SECONDS = 2.0
HARNESS_GROUP_POLL_SECONDS = 0.05

IMPORT_RE = re.compile(r'^\s*#\s*(?:import|include)\s+"([^"]+)"', re.MULTILINE)


def repo_rel(path):
    return path.relative_to(REPO).as_posix()


def harness_files(hdir):
    """Every source-ish file in a harness directory, build output excluded."""
    root = REPO / hdir
    files = []
    if not root.is_dir():
        return files
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        rel = repo_rel(path)
        if any(part in SKIP_PARTS for part in rel.split("/")):
            continue
        files.append(rel)
    return sorted(files)


def shell_vars(text, script_dir):
    """Resolve the shell variables the build scripts use for repo paths.

    ``SRC=../../tweak/Sources``, ``SRC=$(cd "$HERE/../.." && pwd)/tweak/Sources``,
    ``VENDOR=../../vendor/audio`` and ``FX=$SRC/Shared/AudioEffects`` all
    become repo-relative paths.
    """
    values = {"HERE": script_dir}
    for line in text.splitlines():
        match = re.match(r"\s*([A-Za-z_]\w*)=(.*)$", line)
        if not match:
            continue
        name, raw = match.group(1), match.group(2)
        if name in values:
            continue
        raw = substitute(raw, values)
        # ``$(dirname "$0")`` and ``${0%/*}`` are the script's directory.
        raw = re.sub(r'\$\(\s*dirname\s+"?\$0"?\s*\)', script_dir, raw)
        raw = raw.replace("${0%/*}", script_dir)
        if "mktemp" in raw or "xcrun" in raw:
            continue
        # ``$(cd "$HERE/../.." && pwd)/tweak/Sources``: the cd'ed directory
        # plus whatever follows the substitution.
        best = None
        for cd in re.finditer(r'\$\(\s*cd\s+(?:--\s+)?([^&]+?)\s*&&\s*pwd\s*\)([^\s"\'`;|&]*)', raw):
            # ``HERE`` is repo-relative, so ``"$HERE/../.."`` normalises to
            # the repo root ('').
            source = cd.group(1).strip().strip('"\'')
            normalized = posixpath.normpath(source)
            if normalized.startswith(".."):
                normalized = posixpath.normpath(posixpath.join(script_dir, source))
            base = None if normalized.startswith("..") else ("" if normalized == "." else normalized)
            if base is not None:
                suffix = cd.group(2).lstrip("/").rstrip("}):,")
                best = posixpath.normpath(posixpath.join(base, suffix)) if base else suffix
                break
        if best is None:
            for token in TOKEN_RE.findall(raw):
                if "$" in token:
                    continue
                resolved = resolve_path_token(token, script_dir)
                if resolved and (best is None or len(resolved[0]) > len(best)):
                    best = resolved[0]
        if best:
            values[name] = best
    return values


def substitute(text, values):
    for name in sorted(values, key=len, reverse=True):
        value = values[name]
        text = text.replace("${%s}" % name, value)
        text = text.replace("$%s" % name, value)
    return text


TOKEN_RE = re.compile(r"""[^\s"';|&()<>`]+""")
FLAG_PREFIXES = ("-isystem", "-iframework", "-include", "-I", "-L", "-F", "-o")
# Directories whose contents are not enumerated: output trees and Git metadata.
DIR_SKIP_PARTS = {"build", ".build", ".git"}


def resolve_path_token(token, script_dir, from_flag=False):
    """Resolve one shell word to (repo path, is_dir), or None.

    Relative words are tried from the script's directory and from the repo
    root; absolute words must be inside the repo.  ``$THEOS``-style words and
    globs are skipped.
    """
    token = token.rstrip(".,:=+_/").lstrip(":=+_")
    for prefix in FLAG_PREFIXES:
        if token.startswith(prefix) and len(token) > len(prefix):
            token = token[len(prefix):]
            from_flag = True
            break
    token = token.rstrip(".,:=/*")
    # Only path-like words: a bare word such as ``build`` in ``OUT=build`` or
    # ``Makefile`` in prose is not a dependency by itself.  A word given to
    # ``-I``/``-isystem`` is a directory even without a slash.  ``~`` paths
    # are outside the repo.
    if not token or (not from_flag and "/" not in token and "." not in token):
        return None
    if any(marker in token for marker in ("$", "*", "?")) or token.startswith("~"):
        return None
    if token.startswith("/"):
        normalized = posixpath.normpath(token)
        if not normalized.startswith(str(REPO) + "/"):
            return None
        candidates = [normalized[len(str(REPO)) + 1:]]
    else:
        if token.startswith("~") or token.startswith(".."):
            candidates = [posixpath.normpath(posixpath.join(script_dir, token))]
        else:
            candidates = [
                posixpath.normpath(posixpath.join(script_dir, token)),
                posixpath.normpath(token),
            ]
    for candidate in candidates:
        if candidate == "." or candidate.startswith("../"):
            continue
        # Build output is not an input (a local run leaves these behind).
        if any(part in DIR_SKIP_PARTS for part in candidate.split("/")):
            continue
        path = REPO / candidate
        if not exact_case(path):
            continue
        return candidate, path.is_dir()
    return None


def exact_case(path):
    """Existence with Ubuntu's case-sensitive semantics, even on a Mac."""
    try:
        current = REPO
        for part in path.relative_to(REPO).parts:
            if part not in os.listdir(current):
                return False
            current = current / part
    except (OSError, ValueError):
        return False
    return True


def directory_files(directory):
    """Every file under a directory, minus build output and Git metadata."""
    found = set()
    root = REPO / directory
    if not root.is_dir():
        return found
    for path in root.rglob("*"):
        if not path.is_file():
            continue
        rel = repo_rel(path)
        if rel == "scripts/harness-plan.py":
            continue
        if any(part in DIR_SKIP_PARTS for part in rel.split("/")):
            continue
        found.add(rel)
    return found


def reference_paths(text, script_dir):
    """Repo files and directories named as path words in a piece of shell."""
    found = set()
    # Quotes are gone by now only if the script had none around a path with
    # variables; remove them so ``"$SRC"/Foo.m`` is one path.
    text = text.replace('"', "").replace("'", "")
    for match in TOKEN_RE.finditer(text):
        token = match.group(0)
        # ``FOO=../../vendor/audio`` and ``-I../shim`` are one word.
        parts = [token] + token.split("=")
        for part in parts:
            resolved = resolve_path_token(part, script_dir)
            if resolved:
                found.add(resolved)
    return found


def expanded_loops(text):
    """Yield loop bodies with the loop variable set to each word.

    now-playing's ``for f in Shared/... Shared/...; do ... "$SRC/$f"`` is the
    form used in these scripts.
    """
    bodies = []
    loop_re = re.compile(r"for\s+(\w+)\s+in\s+([^;\n]+);?\s*do\b(.*?)\bdone", re.S)
    while True:
        match = loop_re.search(text)
        if not match:
            break
        var, words, body = match.groups()
        for word in words.split():
            bodies.append(substitute(body, {var: word}))
        text = text[:match.start()] + text[match.end():]
    return bodies, text


def script_refs(script_rel, hdir):
    """Repo paths (files and directories) a build/check script uses."""
    try:
        text = (REPO / script_rel).read_text(errors="replace")
    except OSError:
        return set()
    script_dir = posixpath.dirname(script_rel)
    values = shell_vars(text, script_dir)
    text = substitute(text, values)
    bodies, rest = expanded_loops(text)
    refs = reference_paths(rest, script_dir)
    for body in bodies:
        refs |= reference_paths(body, script_dir)
    return refs


def quoted_imports(rel):
    try:
        text = (REPO / rel).read_text(errors="replace")
    except OSError:
        return set()
    return set(IMPORT_RE.findall(text))


def resolve_import(name, source_rel, hdir, roots):
    candidates = [
        posixpath.normpath(TWEAK + "/" + name),
        posixpath.normpath(posixpath.join(posixpath.dirname(source_rel), name)),
        posixpath.normpath(posixpath.join(hdir, name)),
    ]
    candidates += [posixpath.normpath(posixpath.join(root, name)) for root in roots]
    for candidate in candidates:
        if (REPO / candidate).is_file():
            return candidate
    return None


def is_broad_root(directory):
    """An include root such as tweak/Sources: imports are followed, files are not."""
    return directory == TWEAK or TWEAK.startswith(directory + "/") or directory in (".", "harness")


def derive_deps(harness):
    """Files outside the harness dir that changing would affect this harness."""
    hdir = "harness/" + harness["dir"]
    own = harness_files(hdir)
    deps = set()
    roots = set()

    # Only the scripts the run command names: build-sim.sh and other
    # simulator scripts in the same directory are not CI inputs.
    scripts = re.findall(r"[\w./-]+\.sh", harness["run"])
    script_refs = set()
    for rel in scripts:
        script_refs |= script_refs_for(rel)
    for path, is_dir in script_refs:
        if is_dir:
            if is_broad_root(path):
                roots.add(path)
            else:
                deps |= directory_files(path)
        else:
            deps.add(path)

    # Quoted imports of the harness's own sources and of everything found above,
    # then the transitive closure.
    queue = list(deps)
    seen = set(queue)
    for rel in own:
        if Path(rel).suffix in SOURCE_SUFFIXES:
            queue.append(rel)
            seen.add(rel)
    while queue:
        current = queue.pop()
        for name in quoted_imports(current):
            resolved = resolve_import(name, current, hdir, roots)
            if not resolved or resolved in seen:
                continue
            seen.add(resolved)
            if not resolved.startswith(hdir + "/"):
                deps.add(resolved)
            if Path(resolved).suffix in SOURCE_SUFFIXES:
                queue.append(resolved)
    # A file in the tweak or a build input elsewhere: both count.  The
    # harness's own files are covered by the directory rule at selection time.
    deps = {rel for rel in deps if not rel.startswith(hdir + "/")}
    return own, sorted(deps)


def script_refs_for(script_rel):
    return script_refs(script_rel, posixpath.dirname(script_rel))


def build_index():
    index = []
    for harness in HARNESSES:
        own, deps = derive_deps(harness)
        entry = dict(harness)
        entry["files"] = own
        entry["deps"] = deps
        entry["weight"] = harness.get("weight") or (3 if harness.get("theos") else 1 + min(3, len(deps) // 6))
        entry["always"] = not any(rel.startswith(TWEAK + "/") for rel in deps)
        index.append(entry)
    return index


def dependency_root(path):
    """The directory a dependency belongs to, for the ``roots`` report."""
    if path.startswith(TWEAK + "/"):
        return TWEAK
    parts = path.split("/")
    if parts[0] == "vendor":
        return "/".join(parts[:2])
    if parts[0] == "harness":
        # harness/<dir>/<include dir> files, or a shared file such as
        # harness/scene.m, or another harness directory's sources.
        directory = posixpath.dirname(path)
        if directory == "harness":
            return path
        return "/".join(directory.split("/")[:3]) if len(parts) > 3 else directory
    return "/".join(parts[:2]) if len(parts) > 1 else path


def dependency_roots(entry):
    roots = {}
    for path in entry["deps"]:
        root = dependency_root(path)
        roots[root] = roots.get(root, 0) + 1
    return roots


def selected_for(path, index):
    path = posixpath.normpath(path)
    names = []
    for entry in index:
        hdir = "harness/" + entry["dir"]
        if path == hdir or path.startswith(hdir + "/") or path in entry["deps"]:
            names.append(entry["name"])
    return names


def is_global_change(path):
    return (
        path.startswith(".github/")
        or path in ("scripts/harness-plan.py", "scripts/harness-plan-data.json")
        or path == "tweak/Makefile"
    )


def shard_matrix(selected):
    """At most five greedy shards by weight; a shard with any Theos harness sets Theos up."""
    if not selected:
        return []
    units = [{"theos": bool(h.get("theos")), "harnesses": [h], "weight": h["weight"]} for h in selected]
    count = min(5, len(units))
    bins = [[] for _ in range(count)]
    loads = [0] * count
    for unit in sorted(units, key=lambda u: u["weight"], reverse=True):
        target = min(range(count), key=lambda i: (loads[i], i))
        bins[target].append(unit)
        loads[target] += unit["weight"]
    # Keep the list order stable inside a shard.
    order = {h["name"]: i for i, h in enumerate(HARNESSES)}
    matrix = []
    for number, units_in_shard in enumerate(bins, 1):
        harnesses = [h for unit in units_in_shard for h in unit["harnesses"]]
        harnesses.sort(key=lambda h: order[h["name"]])
        matrix.append({
            "shard": "%d/%d" % (number, count),
            "harnesses": ",".join(h["name"] for h in harnesses),
            "theos": any(h.get("theos") for h in harnesses),
        })
    return matrix


def plan(index, changed, all_harnesses):
    reasons = []
    always = [h["name"] for h in index if h["always"]]
    if all_harnesses:
        reasons.append("all harnesses requested (workflow_dispatch, schedule, or the changed list is unknown)")
        selected = list(index)
    else:
        global_paths = [p for p in changed if is_global_change(p)]
        # A path no longer in the checkout (deleted, or a rename's old name; the workflow diffs with --no-renames)
        # is in no dependency set, as those are read from the files that exist, yet a harness may still use it.
        gone = [p for p in changed if not (REPO / p).exists()]
        if global_paths or gone:
            if global_paths:
                reasons.append("global change: " + ", ".join(global_paths))
            if gone:
                reasons.append("deleted or renamed away, a harness may still use it: " + ", ".join(gone))
            selected = list(index)
        else:
            selected = [h for h in index if h["always"]]
            for path in changed:
                for name in selected_for(path, index):
                    entry = next(h for h in index if h["name"] == name)
                    if entry not in selected:
                        selected.append(entry)
            selected.sort(key=lambda h: HARNESSES.index(next(x for x in HARNESSES if x["name"] == h["name"])))
    if always and not all_harnesses:
        for name in always:
            print("warning: no tweak dependency found for %r; always selected" % name,
                  file=sys.stderr)
    matrix = shard_matrix(selected)
    return selected, matrix, reasons


def read_changed(path):
    try:
        if path == "-":
            data = sys.stdin.read()
        else:
            data = Path(path).read_text()
    except OSError as error:
        print("warning: cannot read changed files (%s); running everything" % error,
              file=sys.stderr)
        return None
    return [line.strip() for line in data.splitlines() if line.strip()]


def write_github_output(path, matrix, any_):
    payload = json.dumps({"include": matrix}, separators=(",", ":"))
    with open(path, "a") as output:
        output.write("matrix<<HARNESS_MATRIX\n%s\nHARNESS_MATRIX\n" % payload)
        output.write("any=%s\n" % ("true" if any_ else "false"))


def cmd_plan(args):
    index = build_index()
    changed = []
    unknown = args.all
    if args.changed_from:
        loaded = read_changed(args.changed_from)
        if loaded is None:
            unknown = True
        else:
            changed = loaded
    elif not args.all:
        print("error: plan needs --changed-from <file|-> (or --all)", file=sys.stderr)
        return 2
    selected, matrix, reasons = plan(index, changed, unknown)

    for reason in reasons:
        print("run all: " + reason)
    print("changed files: %d" % len(changed))
    print("selected (%d of %d):" % (len(selected), len(index)))
    for harness in selected:
        print("  %s [%s]" % (harness["name"], harness["dir"] + ("; theos" if harness.get("theos") else "")))
    if not selected:
        print("  (none)")
    print("shards (%d):" % len(matrix))
    for shard in matrix:
        print("  %s%s: %s" % (shard["shard"], " (theos)" if shard["theos"] else "", shard["harnesses"]))
    payload = json.dumps({"include": matrix}, separators=(",", ":"))
    print("matrix: " + payload)
    print("any: " + ("true" if matrix else "false"))
    if args.github_output:
        write_github_output(args.github_output, matrix, bool(matrix))
    return 0


def find_harness(token, index):
    lowered = token.lower()
    for entry in index:
        if lowered in (entry["name"].lower(), entry["dir"].lower()):
            return entry
    return None


def script_preference_domains(script_rel):
    """Audit the output syntax used by host scripts, refusing unknown names.

    The dependency parser deliberately excludes build outputs and does not
    evaluate shell branches, so it cannot derive these lock domains itself.
    Audit every output branch, using default output names, instead.
    """
    text = (REPO / script_rel).read_text()
    commands = []
    for line in text.replace("\\\n", "").splitlines():
        lexer = shlex.shlex(line, posix=True, punctuation_chars=";&|")
        lexer.whitespace_split = True
        lexer.commenters = "#"
        commands.append(list(lexer))
    text = "\n".join(" ".join(words) for words in commands)
    bundles = re.findall(r"<key>CFBundleIdentifier</key>\s*<string>([^<]+)</string>", text)
    if "CFBundleIdentifier" in text and not bundles:
        raise ValueError("unrecognized bundle identifier syntax in " + script_rel)

    def basenames(word, resolving=()):
        word = word.replace('"', "").replace("'", "")
        word = re.sub(r"\$\{\w+:\+[^{}]*\}", "", word)
        word = re.sub(r"\$\{\w+:-([^{}]+)\}", r"\1", word)
        name = posixpath.basename(word)
        variable = re.fullmatch(r"\$(?:\{(\w+)\}|(\w+))", name)
        if variable:
            variable = variable.group(1) or variable.group(2)
            if variable in resolving:
                raise ValueError("cyclic output variable in " + script_rel)
            assignments = re.findall(r"^\s*" + variable + r"=(.+)$", text, re.M)
            # A script may canonicalize an already assigned output directory.
            assignments = [value for value in assignments if not value.startswith("$(cd ")]
            if assignments:
                return set().union(*(basenames(value, resolving + (variable,)) for value in assignments))
        if not name or any(char in name for char in "$*?{}"):
            raise ValueError("unresolved output name %r in %s" % (word, script_rel))
        return {name}

    outputs = []
    for words in commands:
        words = iter(words)
        for word in words:
            if word == "-o":
                output = next(words, None)
                if not output or output.startswith("-") or re.fullmatch(r"[;&|]+", output):
                    raise ValueError("missing output path after -o in " + script_rel)
                outputs.append(output)
            elif word.startswith("-o"):
                outputs.append(word[2:])

    domains = set()
    for output in outputs:
        names = {name for name in basenames(output) if not name.endswith(".o")}
        if bundles and names:
            if not any(marker in output for marker in (".app/", "$APP/", "${APP}/")):
                raise ValueError("cannot associate output %s with its bundle in %s" % (output, script_rel))
            if any("$" in bundle for bundle in bundles):
                raise ValueError("unresolved bundle identifier in " + script_rel)
            domains.update(bundles)
        else:
            domains.update(names)
    return domains


def check_preference_lock_coverage():
    domains = {}
    scripts = {}
    for harness in HARNESSES:
        for script in re.findall(r"[\w./-]+\.sh", harness["run"]):
            if script not in scripts:
                scripts[script] = script_preference_domains(script)
            for domain in scripts[script]:
                domains.setdefault(domain, set()).add(harness["dir"])
    for domain, directories in sorted(domains.items()):
        if len(directories) > 1 and not directories <= SHARED_PREFERENCE_DOMAINS.get(domain, set()):
            raise ValueError("uncovered preference domain %r shared by %s; update SHARED_PREFERENCE_DOMAINS"
                             % (domain, ", ".join(sorted(directories))))


@contextmanager
def harness_locks(harness):
    resources = ["dir-" + harness["dir"]]
    resources.extend("prefs-" + domain for domain, directories in SHARED_PREFERENCE_DOMAINS.items()
                     if harness["dir"] in directories)
    waiting = False
    with ExitStack() as stack:
        directory = Path("/tmp") / ("vitrine-harness-%s" % os.getuid())
        directory.mkdir(mode=0o700, exist_ok=True)
        directory_fd = os.open(directory, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        stack.callback(os.close, directory_fd)
        info = os.fstat(directory_fd)
        if info.st_uid != os.getuid() or stat.S_IMODE(info.st_mode) != 0o700:
            raise ValueError("unsafe lock directory %s: requires current uid and mode 0700" % directory)
        # Keep lock files: unlinking lets a new runner lock a different inode
        # while an existing waiter still holds the old one. Use /tmp rather
        # than caller-specific TMPDIR so runners agree on the same resources.
        for resource in sorted(resources):
            fd = os.open(resource + ".lock", os.O_CREAT | os.O_RDWR | os.O_NOFOLLOW,
                         0o600, dir_fd=directory_fd)
            lock = stack.enter_context(os.fdopen(fd, "a"))
            try:
                fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
            except BlockingIOError:
                if not waiting:
                    print("=== %s: waiting for shared harness resources" % harness["name"], flush=True)
                    waiting = True
                fcntl.flock(lock, fcntl.LOCK_EX)
        yield


class HarnessInterrupted(KeyboardInterrupt):
    def __init__(self, signum):
        self.signum = signum


def harness_group_exists(process):
    process.poll()
    try:
        os.killpg(process.pid, 0)
    except ProcessLookupError:
        return False
    return True


def terminate_harness(process):
    try:
        os.killpg(process.pid, signal.SIGTERM)
    except ProcessLookupError:
        process.wait()
        return
    deadline = time.monotonic() + HARNESS_TERMINATION_GRACE_SECONDS
    while harness_group_exists(process):
        if time.monotonic() >= deadline:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            break
        time.sleep(HARNESS_GROUP_POLL_SECONDS)
    process.wait()
    # Grandchildren are reaped by their parent (or the OS after reparenting).
    # Do not release shared resources while any member of the group remains.
    while harness_group_exists(process):
        time.sleep(HARNESS_GROUP_POLL_SECONDS)


def run_harness(command):
    process = None
    pending_signal = None
    returncode = None

    def interrupted(signum, frame):
        nonlocal pending_signal
        # Never raise asynchronously: cancellation during Popen or cleanup
        # must not escape before we own (or have reaped) the entire group.
        pending_signal = signum

    previous = {sig: signal.signal(sig, interrupted) for sig in (signal.SIGINT, signal.SIGTERM)}
    # Most harness scripts read $THEOS with no fallback; a local run without it
    # would fail on /bin/logos.pl before checking anything. CI sets its own.
    env = dict(os.environ)
    env.setdefault("THEOS", os.path.expanduser("~/theos"))
    try:
        process = subprocess.Popen(command, shell=True, executable="/bin/bash",
                                   cwd=REPO, start_new_session=True, env=env)
        while pending_signal is None:
            try:
                returncode = process.wait(timeout=HARNESS_GROUP_POLL_SECONDS)
                break
            except subprocess.TimeoutExpired:
                continue
        if pending_signal is not None:
            raise HarnessInterrupted(pending_signal)
        return returncode
    except BaseException:
        returncode = None
        raise
    finally:
        try:
            if process is not None and returncode != 0:
                terminate_harness(process)
        finally:
            for sig, handler in previous.items():
                signal.signal(sig, handler)


def cmd_run(args):
    index = build_index()
    tokens = []
    if args.names:
        for value in args.names:
            tokens.extend(part.strip() for part in value.split(",") if part.strip())
    if not tokens:
        print("error: run needs --names (or --shard with '=' names)", file=sys.stderr)
        return 2

    chosen = []
    for token in tokens:
        harness = find_harness(token, index)
        if not harness:
            # Names contain spaces and --names may receive them split apart.
            print("error: unknown harness %r" % token, file=sys.stderr)
            return 2
        if harness not in chosen:
            chosen.append(harness)

    try:
        check_preference_lock_coverage()
    except (OSError, ValueError) as error:
        print("error: %s" % error, file=sys.stderr)
        return 2

    label = args.shard or "local"
    results = []
    for harness in chosen:
        start = time.monotonic()
        try:
            with harness_locks(harness):
                print("=== %s: %s" % (harness["name"], harness["run"]), flush=True)
                returncode = run_harness(harness["run"])
        except HarnessInterrupted as error:
            print("error: interrupted by %s" % signal.Signals(error.signum).name, file=sys.stderr)
            return 128 + error.signum
        except (OSError, ValueError) as error:
            print("error: %s" % error, file=sys.stderr)
            return 2
        seconds = time.monotonic() - start
        results.append((harness["name"], returncode == 0, seconds))
        print("=== %s: %s (%.1fs)" % (harness["name"], "PASS" if returncode == 0 else "FAIL", seconds),
              flush=True)

    lines = ["", "| Harness | Result | Seconds |", "| --- | --- | --- |"]
    for name, passed, seconds in results:
        lines.append("| %s | %s | %.1f |" % (name, "PASS" if passed else "FAIL", seconds))
    table = "\n".join(lines)
    print(table)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a") as output:
            output.write("\n## Harnesses %s\n%s\n" % (label, table))
    return 0 if all(passed for _, passed, _ in results) else 1


def cmd_explain(args):
    index = build_index()
    failed = False
    for raw in args.paths:
        path = posixpath.normpath(raw)
        names = selected_for(path, index)
        print(path)
        if names:
            print("  " + "\n  ".join(names))
        else:
            print("  (no harness)")
        failed = failed or not names
    return 1 if failed else 0


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    sub = parser.add_subparsers(dest="command", required=True)

    plan_parser = sub.add_parser("plan", help="select harnesses and shard them")
    plan_parser.add_argument("--changed-from", metavar="FILE", help="changed paths, one per line; - for stdin")
    plan_parser.add_argument("--all", action="store_true", help="run every harness")
    plan_parser.add_argument("--github-output", metavar="PATH", help="append matrix and any outputs")
    plan_parser.set_defaults(func=cmd_plan)

    run_parser = sub.add_parser("run", help="run harnesses sequentially")
    run_parser.add_argument("--shard", metavar="SPEC", help="shard label such as 1/3")
    run_parser.add_argument("--names", nargs="+", metavar="NAME", help="harness names or directory ids")
    run_parser.set_defaults(func=cmd_run)

    explain_parser = sub.add_parser("explain", help="show which harnesses each path selects")
    explain_parser.add_argument("paths", nargs="+")
    explain_parser.set_defaults(func=cmd_explain)

    args = parser.parse_args(argv)
    return args.func(args)


if __name__ == "__main__":
    sys.exit(main())
