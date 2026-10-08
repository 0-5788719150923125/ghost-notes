#!/usr/bin/env python3
"""Install the pinned Godot editor and export templates needed by a local build.

Usage: python3 scripts/setup_godot.py --target linux --print-godot
The editor is cached in build/tools/; Godot's templates use its normal data directory.
All downloads come from the official Godot release and are checked against its asset digests.
"""

from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path
import shutil
import subprocess
import sys
import urllib.error
import urllib.request
import zipfile


VERSION = "4.7.2.stable"
RELEASE = "4.7.2-stable"
ROOT = Path(__file__).resolve().parent.parent
TOOLS = ROOT / "build" / "tools" / "godot" / VERSION
BASE_URL = f"https://github.com/godotengine/godot/releases/download/{RELEASE}"
EDITOR_ARCHIVE = f"Godot_v{RELEASE}_linux.x86_64.zip"
EDITOR = f"Godot_v{RELEASE}_linux.x86_64"
TEMPLATE_ARCHIVE = f"Godot_v{RELEASE}_export_templates.tpz"
SHA256 = {
    EDITOR_ARCHIVE: "cadd3204e728a35d3f13adb7fd0d7902636b79f6b95c40c265eb73b6c35329e4",
    TEMPLATE_ARCHIVE: "f298490b8d44d934be425a5a65a51bf15f422428b229a06a6e11d9ffea248011",
}
TEMPLATES = {
    "linux": ("linux_debug.x86_64", "linux_release.x86_64"),
    "windows": ("windows_debug_x86_64.exe", "windows_release_x86_64.exe"),
    "android": ("android_debug.apk", "android_release.apk", "android_source.zip"),
}


def say(message: str) -> None:
    print(f"setup_godot: {message}", file=sys.stderr)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def archive(name: str) -> Path:
    TOOLS.mkdir(parents=True, exist_ok=True)
    dest = TOOLS / name
    if dest.is_file() and sha256(dest) == SHA256[name]:
        return dest
    if dest.exists():
        dest.unlink()
    part = dest.with_name(dest.name + ".part")
    say(f"downloading {name}")
    try:
        with urllib.request.urlopen(f"{BASE_URL}/{name}", timeout=60) as source:
            with part.open("wb") as output:
                total = int(source.headers.get("Content-Length") or 0)
                downloaded = 0
                next_report = 100 * 1024 * 1024
                while chunk := source.read(8 * 1024 * 1024):
                    output.write(chunk)
                    downloaded += len(chunk)
                    if downloaded >= next_report:
                        amount = f"{downloaded // (1024 * 1024)} MiB"
                        if total:
                            amount += f" / {total // (1024 * 1024)} MiB"
                        say(f"downloaded {amount}")
                        next_report += 100 * 1024 * 1024
        if sha256(part) != SHA256[name]:
            raise RuntimeError(f"checksum mismatch for {name}")
        part.replace(dest)
    finally:
        part.unlink(missing_ok=True)
    return dest


def editor_version(path: str) -> str:
    try:
        result = subprocess.run(
            [path, "--headless", "--version"], capture_output=True, text=True, timeout=20
        )
    except (OSError, subprocess.TimeoutExpired):
        return ""
    return result.stdout.strip().splitlines()[-1] if result.returncode == 0 and result.stdout.strip() else ""


def editor(explicit: str | None) -> str:
    candidates = [explicit] if explicit else [shutil.which("godot"), str(TOOLS / EDITOR)]
    for candidate in candidates:
        if candidate and editor_version(candidate).startswith(VERSION + "."):
            return candidate
    if explicit:
        raise RuntimeError(f"{explicit} is not Godot {VERSION}")
    if sys.platform != "linux" or os.uname().machine != "x86_64":
        raise RuntimeError("automatic editor setup currently supports Linux x86_64")
    path = TOOLS / EDITOR
    with zipfile.ZipFile(archive(EDITOR_ARCHIVE)) as package:
        names = [name for name in package.namelist() if Path(name).name == EDITOR]
        if len(names) != 1:
            raise RuntimeError(f"{EDITOR_ARCHIVE} does not contain {EDITOR}")
        with package.open(names[0]) as source, path.open("wb") as output:
            shutil.copyfileobj(source, output)
    path.chmod(0o755)
    if not editor_version(str(path)).startswith(VERSION + "."):
        raise RuntimeError(f"downloaded editor did not report Godot {VERSION}")
    return str(path)


def template_dir() -> Path:
    data_home = Path(os.environ.get("XDG_DATA_HOME") or Path.home() / ".local" / "share")
    return data_home / "godot" / "export_templates" / VERSION


def install_templates(targets: list[str]) -> None:
    destination = template_dir()
    needed = {name for target in targets for name in TEMPLATES[target]}
    missing = {name for name in needed if not (destination / name).is_file()
               or (destination / name).stat().st_size < 1_000_000}
    if not missing:
        return
    destination.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(archive(TEMPLATE_ARCHIVE)) as package:
        for filename in sorted(missing):
            matches = [name for name in package.namelist() if Path(name).name == filename]
            if len(matches) != 1:
                raise RuntimeError(f"{TEMPLATE_ARCHIVE} does not contain {filename}")
            part = destination / (filename + ".part")
            say(f"installing {filename}")
            try:
                with package.open(matches[0]) as source, part.open("wb") as output:
                    shutil.copyfileobj(source, output)
                part.replace(destination / filename)
            finally:
                part.unlink(missing_ok=True)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--target", action="append", choices=sorted(TEMPLATES), default=[])
    parser.add_argument("--godot", help="use this installed editor; fail if its version differs")
    parser.add_argument("--print-godot", action="store_true", help="print the editor path for build.sh")
    args = parser.parse_args()
    try:
        path = editor(args.godot)
        install_templates(args.target or ["linux"])
    except (OSError, RuntimeError, urllib.error.URLError, zipfile.BadZipFile) as error:
        say(str(error))
        return 1
    if args.print_godot:
        print(path)
    else:
        say(f"ready: Godot {VERSION}; {', '.join(args.target or ['linux'])} templates")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
