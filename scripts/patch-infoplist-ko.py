#!/usr/bin/env python3
"""Puts Korean wording for the permission prompts Vitrine's overlay sets into the IPA's ko InfoPlist.strings, in place.

  scripts/patch-infoplist-ko.py <ipa> <Payload/X.app/>

plist/liquid-glass.plist carries English text for NSMotionUsageDescription (it replaces Spotify's own) and, when
Spotify has none, NSLocalNetworkUsageDescription. A <lang>.lproj/InfoPlist.strings of the app wins over Info.plist in
that language, so on a Korean iPhone Spotify's own Korean motion text would still be shown. This sets the same two
keys there, in the wording and tone of Spotify's Korean strings (회원님, 합니다체). A binary strings file stays binary.
"""
import os
import plistlib
import re
import subprocess
import sys
import tempfile
import zipfile

ipa, app_dir = sys.argv[1:3]

MOTION = ("AirPods 제스처와 공간 음성은 회원님의 머리 움직임을 읽습니다. 고개를 두 번 끄덕여 노래에 좋아요를 표시하고, "
          "고개를 저어 건너뛰며, 회원님이 고개를 돌려도 노래방 기능의 목소리가 정면에 머물 수 있습니다.")
LOCAL_NET = "Spotify Connect 및 Cast에 사용할 주변 스피커와 기기를 찾습니다."

with zipfile.ZipFile(ipa) as z:
    names = z.namelist()
    info = plistlib.loads(z.read(f"{app_dir}Info.plist"))
    want = {"NSMotionUsageDescription": MOTION}
    if not info.get("NSLocalNetworkUsageDescription"):
        want["NSLocalNetworkUsageDescription"] = LOCAL_NET
    targets = sorted(n for n in names if re.fullmatch(re.escape(app_dir) + r"ko[^/]*\.lproj/InfoPlist\.strings", n))
    if not targets:
        targets = [f"{app_dir}ko.lproj/InfoPlist.strings"]
    out = {}
    for member in targets:
        binary, data = True, {}
        if member in names:
            raw = z.read(member)
            binary = raw[:6] == b"bplist"
            try:
                data = plistlib.loads(raw)
            except Exception:
                # a text .strings file: keep its pairs, then write it back as text
                data = {}
                for m in re.finditer(r'^"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)";', raw.decode("utf-8", "replace"), re.M):
                    data[m.group(1)] = m.group(2).replace('\\"', '"').replace("\\n", "\n").replace("\\\\", "\\")
                binary = False
        else:
            binary = False
        data.update(want)
        if binary:
            out[member] = plistlib.dumps(data, fmt=plistlib.FMT_BINARY)
        else:
            lines = []
            for k, v in data.items():
                esc = v.replace("\\", "\\\\").replace('"', '\\"').replace("\n", "\\n")
                lines.append(f'"{k}" = "{esc}";')
            out[member] = ("\n".join(lines) + "\n").encode("utf-8")

with tempfile.TemporaryDirectory() as tmp:
    for member, blob in out.items():
        path = os.path.join(tmp, member)
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as f:
            f.write(blob)
    subprocess.run(["zip", "-q", os.path.abspath(ipa), *out], cwd=tmp, check=True)

for member in out:
    print(f"    {member}: {', '.join(want)}")
