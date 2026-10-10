#!/usr/bin/env python3
"""Exercise the exported binary's helper against disposable copies on this OS.

Usage: python3 scripts/smoke_update.py path/to/ghost-notes[.exe]
"""

from __future__ import annotations

import hashlib
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time


def digest(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            h.update(chunk)
    return h.hexdigest()


def main() -> int:
    if len(sys.argv) != 2:
        print("usage: scripts/smoke_update.py path/to/ghost-notes[.exe]", file=sys.stderr)
        return 2
    binary = Path(sys.argv[1]).resolve()
    if not binary.is_file():
        print(f"smoke_update: missing executable: {binary}", file=sys.stderr)
        return 2
    with tempfile.TemporaryDirectory(prefix="ghost-update-smoke-") as directory:
        root = Path(directory)
        suffix = ".exe" if sys.platform == "win32" else ".bin"
        target = root / f"ghost-notes{suffix}"
        helper = root / f"helper{suffix}"
        staged = root / f"ghost-notes.new{suffix}"
        for path in (target, helper, staged):
            shutil.copy2(binary, path)
            path.chmod(0o755)
        expected = digest(staged)
        parent = subprocess.Popen(
            [str(target), "--headless", "--", "--update-smoke-hold"],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.PIPE,
        )
        helper_process: subprocess.Popen[str] | None = None
        try:
            time.sleep(0.4)
            if parent.poll() is not None:
                raise RuntimeError("old app exited before the update could start")
            helper_process = subprocess.Popen(
                [str(helper), "--headless", "--", "--apply-update", str(target),
                 str(parent.pid), str(staged), expected, "0"],
                stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
            )
            parent.wait(timeout=15)
            helper_stdout, helper_stderr = helper_process.communicate(timeout=45)
            if helper_process.returncode or parent.returncode or staged.exists() or not (root / f"ghost-notes{suffix}.ghost-previous").is_file() or digest(target) != expected:
                raise RuntimeError(f"swap failed (app {parent.returncode}, helper {helper_process.returncode}):\n{helper_stdout}\n{helper_stderr}")
        finally:
            if parent.poll() is None:
                parent.kill()
                parent.wait(timeout=10)
            if helper_process is not None and helper_process.poll() is None:
                helper_process.kill()
                helper_process.wait(timeout=10)
    print("smoke_update: exported helper waited for app exit, swapped the executable, kept a backup")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
