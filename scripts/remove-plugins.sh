#!/usr/bin/env bash
# Remove every PlugIns/ directory and .appex bundle from an IPA, before signing.
# Adapted from SUB2-8687/vitrine (GPL-3).
# Usage: bash scripts/remove-plugins.sh <app.ipa>
set -euo pipefail

IPA="${1:-}"
[ -n "$IPA" ] && [ -f "$IPA" ] || { echo "usage: $0 <app.ipa>" >&2; exit 1; }
python3 -B - "$IPA" <<'PY'
from pathlib import Path
import re
import subprocess
import sys
import zipfile

ipa = Path(sys.argv[1]).resolve()
def extensions():
    with zipfile.ZipFile(ipa) as archive:
        names = archive.namelist()
        if not any(re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", n) for n in names):
            raise ValueError("IPA has no Payload/*.app/Info.plist")
        return [n for n in names if any(
            part == "PlugIns" or part.endswith(".appex") for part in n.split("/"))]

members = extensions()
if not members:
    print("    no app extensions in this IPA")
    sys.exit(0)
bundles = sorted({n[:n.index(".appex") + len(".appex")] for n in members if ".appex" in n})
print(f"==> removing every app extension from {ipa.name}", flush=True)
for bundle in bundles:
    print(f"    removed: {bundle}", flush=True)
# Literal archive member names avoid shell globs, argument limits and masked zip failures.
subprocess.run(["zip", "-q", "-d", "-nw", str(ipa), "-@"],
               input="\n".join(members) + "\n", text=True, check=True)
if extensions():
    sys.exit("app extensions remain after removal")
print("    done: no PlugIns/ and no .appex left")
PY
