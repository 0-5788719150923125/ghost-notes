#!/usr/bin/env python3
"""Stage exported builds as release assets: archives, SHA256SUMS and a manifest.

  python3 scripts/package_release.py archive linux      # dist/ghost-notes-linux.x86_64 -> dist/release/
  python3 scripts/package_release.py archive windows    # dist/ghost-notes-windows.exe
  python3 scripts/package_release.py archive android    # dist/ghost-notes-android.apk, copied as-is
  python3 scripts/package_release.py finalize           # SHA256SUMS + manifest.json over dist/release/

The same commands run on a developer machine and in CI (.github/workflows/build.yml); the
workflow passes arguments and holds no packaging logic. Asset names carry no version, so the
latest release always has the same filenames (the in-app update path, next/ci_builds.md, can
pick an asset by platform). The version lives in the tag and the manifest: the full commit.

A Linux archive is a tar.gz that keeps the executable bit; a Windows archive is a zip. Each
holds one folder, `ghost-notes/`, with the program in it.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tarfile
import zipfile

ROOT = Path(__file__).resolve().parent.parent
DIST = ROOT / os.environ.get("OUT", "dist")  # build.sh's OUT, so both agree
STAGE = DIST / "release"
FOLDER = "ghost-notes"
## Fixed time in every archive member, so the same export packs to the same bytes.
EPOCH = 315532800  # 1980-01-01

TARGETS = {
    "android": {"asset": "ghost-notes-android-arm64.apk", "files": {"ghost-notes-android.apk": None}},
    "linux": {"asset": "ghost-notes-linux-x86_64.tar.gz", "files": {"ghost-notes-linux.x86_64": "ghost-notes"}},
    "windows": {
        "asset": "ghost-notes-windows-x86_64.zip",
        "files": {
            "ghost-notes-windows.exe": "ghost-notes.exe",
        },
    },
}


def fail(message: str) -> None:
    print(f"package_release: {message}", file=sys.stderr)
    raise SystemExit(1)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def archive(target: str) -> None:
    spec = TARGETS[target]
    STAGE.mkdir(parents=True, exist_ok=True)
    out = STAGE / spec["asset"]
    out.unlink(missing_ok=True)
    for source in spec["files"]:
        path = DIST / source
        if not path.is_file() or path.stat().st_size < 1_000_000:
            fail(f"{path} is missing or too small to be an export. Run scripts/build.sh --release {target}.")
    if target == "android":
        # An APK is already the archive: copied, named for its architecture.
        shutil.copyfile(DIST / "ghost-notes-android.apk", out)
    elif target == "linux":
        with tarfile.open(out, "w:gz") as bundle:
            for source, inside in spec["files"].items():
                info = bundle.gettarinfo(DIST / source, f"{FOLDER}/{inside}")
                info.mode, info.uid, info.gid, info.uname, info.gname, info.mtime = 0o755, 0, 0, "", "", EPOCH
                with (DIST / source).open("rb") as stream:
                    bundle.addfile(info, stream)
    else:
        with zipfile.ZipFile(out, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
            for source, inside in spec["files"].items():
                info = zipfile.ZipInfo(f"{FOLDER}/{inside}", (1980, 1, 1, 0, 0, 0))
                info.compress_type = zipfile.ZIP_DEFLATED
                info.external_attr = 0o755 << 16
                bundle.writestr(info, (DIST / source).read_bytes())
    print(f"package_release: {out} ({out.stat().st_size // 1048576} MB)")


def godot_version() -> str:
    text = (ROOT / "scripts" / "setup_godot.py").read_text()
    match = re.search(r'^VERSION = "([^"]+)"', text, re.M)
    return match.group(1) if match else "unknown"


def commit() -> str:
    # CI passes the commit it checked out; a local run asks git.
    sha = os.environ.get("GITHUB_SHA")
    if sha:
        return sha
    return subprocess.run(["git", "rev-parse", "HEAD"], cwd=ROOT, capture_output=True, text=True).stdout.strip()


def finalize() -> None:
    assets = sorted(p for p in STAGE.glob("ghost-notes-*") if p.is_file())
    if not assets:
        fail("no archives in dist/release/. Run `archive <target>` first.")
    sums = "".join(f"{sha256(p)}  {p.name}\n" for p in assets)
    (STAGE / "SHA256SUMS").write_text(sums)
    sha = commit()
    manifest = {
        "commit": sha,
        "tag": f"build-{sha}",
        "godot": godot_version(),
        "assets": [{"name": p.name, "sha256": sha256(p), "bytes": p.stat().st_size} for p in assets],
    }
    (STAGE / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
    print(f"package_release: SHA256SUMS and manifest.json for {len(assets)} asset(s), commit {sha[:12]}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = parser.add_subparsers(dest="command", required=True)
    sub.add_parser("archive").add_argument("target", choices=sorted(TARGETS))
    sub.add_parser("finalize")
    args = parser.parse_args()
    if args.command == "archive":
        archive(args.target)
    else:
        finalize()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
