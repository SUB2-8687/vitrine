#!/usr/bin/env python3
"""Localize overlay permission prompts in all Korean InfoPlist.strings.

Usage: patch-infoplist-ko.py <ipa> <Payload/X.app/> [original-ipa]
Pass the original IPA after injection: the overlay may already have supplied
the otherwise absent local-network description in the output's Info.plist.
Adapted from SUB2-8687/vitrine (GPL-3).
"""
import json
from pathlib import Path
import plistlib
import re
import subprocess
import sys
import tempfile
import zipfile

MOTION = ("AirPods 제스처와 공간 음성은 회원님의 머리 움직임을 읽습니다. 고개를 두 번 끄덕여 노래에 좋아요를 표시하고, "
          "고개를 저어 건너뛰며, 회원님이 고개를 돌려도 노래방 기능의 목소리가 정면에 머물 수 있습니다.")
LOCAL_NET = "Spotify Connect 및 Cast에 사용할 주변 스피커와 기기를 찾습니다."


def patch(ipa, app_dir, original):
    if not re.fullmatch(r"Payload/[^/]+\.app/", app_dir):
        raise ValueError("app directory must be Payload/<name>.app/")
    with zipfile.ZipFile(original) as source:
        info = plistlib.loads(source.read(f"{app_dir}Info.plist"))
    with zipfile.ZipFile(ipa) as archive:
        names = archive.namelist()
        korean = re.compile(re.escape(app_dir) + r"(ko[^/]*\.lproj)/")
        targets = sorted({f"{app_dir}{match.group(1)}/InfoPlist.strings"
                          for name in names if (match := korean.match(name))})
        if not targets:
            print("warning: app has no Korean localization; permission prompts unchanged", file=sys.stderr)
            return
        output = {}
        for member in targets:
            raw = archive.read(member) if member in names else b""
            binary = raw.startswith(b"bplist")
            if binary:
                data = plistlib.loads(raw)
            elif raw:
                # Apple's parser accepts UTF-16 and OpenStep strings too; never
                # recover a partial table from malformed input.
                xml = subprocess.run(["plutil", "-convert", "xml1", "-o", "-", "--", "-"],
                                     input=raw, capture_output=True, check=True).stdout
                data = plistlib.loads(xml)
            else:
                data = {}
            if not isinstance(data, dict):
                raise ValueError(f"{member}: expected a strings dictionary")
            data["NSMotionUsageDescription"] = MOTION
            # Keep Spotify's localized wording even if its base plist lacks it.
            if not info.get("NSLocalNetworkUsageDescription") and not data.get("NSLocalNetworkUsageDescription"):
                data["NSLocalNetworkUsageDescription"] = LOCAL_NET
            if binary:
                output[member] = plistlib.dumps(data, fmt=plistlib.FMT_BINARY)
            else:
                output[member] = ("\n".join(
                    f"{json.dumps(k, ensure_ascii=False)} = {json.dumps(v, ensure_ascii=False)};"
                    for k, v in data.items()) + "\n").encode("utf-8")
    with tempfile.TemporaryDirectory() as tmp:
        for member, blob in output.items():
            path = Path(tmp, member)
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(blob)
        subprocess.run(["zip", "-q", str(Path(ipa).resolve()), *output], cwd=tmp, check=True)
    for member in output:
        print(f"    {member}: Korean permission prompts updated")


if __name__ == "__main__":
    if len(sys.argv) not in (3, 4):
        sys.exit(__doc__)
    patch(sys.argv[1], sys.argv[2], sys.argv[3] if len(sys.argv) == 4 else sys.argv[1])
