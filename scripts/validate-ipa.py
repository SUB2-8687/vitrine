#!/usr/bin/env python3
"""Validate a Spotify IPA before extraction (not a decryption check).

Adapted from kes158/vitrine 6f17644 and SUB2-8687/vitrine 622a4fa (GPL-3.0).
"""
import argparse
import plistlib
import re
import signal
import struct
import sys
import zipfile
import zlib
from pathlib import Path
from xml.parsers.expat import ExpatError

MAX_ARCHIVE_BYTES = 2 * 1024**3
MAX_DIRECTORY_BYTES = 32 * 1024**2
MAX_ENTRIES = 50000
MAX_MEMBER_BYTES = 2 * 1024**3
MAX_EXPANDED_BYTES = 8 * 1024**3
MAX_PLIST_BYTES = 1024**2
CHECK_SECONDS = 120
CHUNK_BYTES = 1024**2


class InvalidIPA(ValueError):
    pass


def check_directory(path):
    # Bound the central directory before ZipFile allocates its member objects.
    size = path.stat().st_size
    if size > MAX_ARCHIVE_BYTES:
        raise InvalidIPA("IPA exceeds the 2 GiB archive size limit.")
    with path.open("rb") as source:
        prefix = source.read(512).lstrip().lower()
        if prefix.startswith((b"<!doctype html", b"<html", b"<head", b"<body")):
            raise InvalidIPA("Download is an HTML/login/error page, not an IPA. Use a direct download link.")
        source.seek(max(0, size - (65535 + 22)))
        tail = source.read()
    offset = tail.rfind(b"PK\x05\x06")
    if offset < 0 or len(tail) - offset < 22:
        raise InvalidIPA("Download is not a ZIP or is truncated/corrupt; download the IPA again.")
    _, disk, start_disk, disk_entries, entries, directory_size, directory_offset, comment = struct.unpack_from(
        "<4s4H2LH", tail, offset
    )
    if disk or start_disk or disk_entries != entries or entries == 65535 or directory_offset == 0xffffffff:
        raise InvalidIPA("Multi-disk and ZIP64 IPA archives are not supported.")
    if entries > MAX_ENTRIES or directory_size > MAX_DIRECTORY_BYTES:
        raise InvalidIPA("IPA exceeds the entry count or central-directory size limit.")
    if offset + 22 + comment != len(tail) or directory_offset + directory_size != size - len(tail) + offset:
        raise InvalidIPA("IPA ZIP directory is corrupt or truncated.")


def spotify_version(path):
    check_directory(path)
    with zipfile.ZipFile(path) as archive:
        entries = archive.infolist()
        if len(entries) > MAX_ENTRIES or sum(item.file_size for item in entries) > MAX_EXPANDED_BYTES:
            raise InvalidIPA("IPA exceeds the entry count or 8 GiB expanded size limit.")
        names = set()
        extraction_paths = set()
        for item in entries:
            name = item.filename
            # ZIP directories end in one slash; that marker is not a path component.
            path = name[:-1] if item.is_dir() else name
            if (item.orig_filename != name or "\\" in name
                    or any(part in ("", ".", "..") for part in path.split("/"))):
                raise InvalidIPA("IPA contains a noncanonical archive path.")
            extraction_path = path.casefold()
            if extraction_path in extraction_paths:
                raise InvalidIPA("IPA contains colliding extraction paths (case-insensitive).")
            extraction_paths.add(extraction_path)
            names.add(name)
            if item.file_size > MAX_MEMBER_BYTES:
                raise InvalidIPA("IPA member exceeds the 2 GiB size limit.")
            if item.flag_bits & 1 or item.compress_type not in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED):
                raise InvalidIPA("IPA uses encrypted or unsupported ZIP compression.")
            if (item.external_attr >> 16) & 0o170000 == 0o120000:
                raise InvalidIPA("IPA contains an unsafe symbolic link.")
        plists = [item for item in entries if re.fullmatch(r"Payload/[^/]+\.app/Info\.plist", item.filename)]
        if len(plists) != 1:
            raise InvalidIPA("IPA must contain exactly one Payload/*.app/Info.plist.")
        if plists[0].file_size > MAX_PLIST_BYTES:
            raise InvalidIPA("IPA Info.plist exceeds the 1 MiB size limit.")
        # Reading every member to EOF checks CRCs without extracting or buffering it.
        for item in entries:
            with archive.open(item) as member:
                while member.read(CHUNK_BYTES):
                    pass
        info = plistlib.loads(archive.read(plists[0]))
        if not isinstance(info, dict) or info.get("CFBundleIdentifier") != "com.spotify.client":
            raise InvalidIPA("IPA is not the original Spotify app (com.spotify.client).")
        if info.get("CFBundleExecutable") != "Spotify" or plists[0].filename[:-len("Info.plist")] + "Spotify" not in names:
            raise InvalidIPA("IPA is missing the Spotify executable.")
        version = info.get("CFBundleShortVersionString")
        if not isinstance(version, str) or not re.fullmatch(r"[0-9]+(?:\.[0-9]+)+", version):
            raise InvalidIPA("IPA has no valid Spotify version.")
        return version


def timed_out(signum, frame):
    raise InvalidIPA("IPA validation exceeded the 120 second time limit.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("ipa", type=Path)
    parser.add_argument("--github-output", type=Path)
    args = parser.parse_args()
    signal.signal(signal.SIGALRM, timed_out)
    signal.alarm(CHECK_SECONDS)
    try:
        version = spotify_version(args.ipa)
    except (OSError, ValueError, zipfile.BadZipFile, RuntimeError, ExpatError, NotImplementedError, EOFError, zlib.error) as error:
        # Untrusted member names, response bodies and parser errors may contain secrets.
        message = str(error) if isinstance(error, InvalidIPA) else "IPA is corrupt or unreadable (ZIP/CRC/plist check failed)."
        print(f"::error::{message}", file=sys.stderr)
        return 1
    finally:
        signal.alarm(0)
    if args.github_output:
        with args.github_output.open("a") as output:
            output.write(f"version={version}\n")
    print(f"Validated Spotify {version} IPA.")
    print("::warning::A valid ZIP does not prove the IPA is decrypted; supply a decrypted Spotify IPA.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
