#!/usr/bin/env python3
"""Bundle the Python helpers that exported Ghost Notes copies into user:// on demand."""

from __future__ import annotations

from pathlib import Path
import zipfile


ROOT = Path(__file__).resolve().parent.parent
HOSTS = ROOT / "hosts"
OUTPUT = ROOT / "data" / "hosts_bundle.zip"


def main() -> None:
    files = sorted(
        path for path in HOSTS.rglob("*")
        if path.is_file()
        and (path.suffix == ".py" or path.name == "requirements.txt")
        and not path.name.startswith("test_")
        and "__pycache__" not in path.parts
    )
    if not files:
        raise RuntimeError("no Python host files found")
    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(OUTPUT, "w", compression=zipfile.ZIP_DEFLATED) as bundle:
        for path in files:
            name = path.relative_to(HOSTS).as_posix()
            info = zipfile.ZipInfo(name, (1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o644 << 16
            bundle.writestr(info, path.read_bytes())
    print(f"package_hosts: {len(files)} files -> {OUTPUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
