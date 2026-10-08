#!/usr/bin/env python3
"""Fetch what an Android export needs, so no Android Studio is installed or opened.

  python3 scripts/setup_android.py --accept-licenses --print-env     # install, then print `export` lines
  python3 scripts/setup_android.py --verify dist/ghost-notes-android.apk

WHAT AN EXPORT NEEDS. The Android preset uses Godot's prebuilt template APK (no Gradle build), so
the SDK is small: platform-tools, one build-tools (its apksigner signs), one platform, and the
command-line tools that install them. No NDK, CMake, emulator or system images - measured, by
exporting against exactly these four. A JDK 17+ must be on the machine (GitHub's Ubuntu runner
has one, and so do most developer machines); this script finds it and does not fetch one.

EVERYTHING LIVES IN build/tools/android/ (git-ignored, and what CI caches): the SDK, a debug
keystore and a private Godot config whose editor settings name them. The printed environment
points Godot there, so the developer's own Android Studio, SDK and ~/.android are never read or
changed.

LICENSES. Installing SDK packages means accepting Google's Android SDK licenses. That is the
user's act, so it is explicit: nothing is fetched without --accept-licenses.

SIGNING. The debug keystore is made here with keytool. Until a real release key exists, the
environment also points Godot's RELEASE keystore at it, so a release-template APK is signed with
the DEBUG key and installs by hand. Set GODOT_ANDROID_KEYSTORE_RELEASE_PATH / _USER / _PASSWORD
and those win. A debug key is not a secret, but each machine makes its own: two builds from
different machines install over each other only after an uninstall (CI caches its keystore).
"""

from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path
import re
import shlex
import shutil
import subprocess
import sys
import urllib.request
import zipfile

ROOT = Path(__file__).resolve().parent.parent
TOOLS = ROOT / "build" / "tools" / "android"
SDK = TOOLS / "sdk"
KEYSTORE = TOOLS / "debug.keystore"
CONFIG = TOOLS / "config"
# Google's command-line tools; the checksum is the one published on developer.android.com/studio.
CMDLINE = "commandlinetools-linux-15859902_latest.zip"
CMDLINE_URL = f"https://dl.google.com/android/repository/{CMDLINE}"
CMDLINE_SHA256 = "4e4c464f145a7512b57d088ac6c278c03c9eea610886b35a5e0804e74eedf583"
BUILD_TOOLS = "35.0.0"
PLATFORM = "android-35"
PACKAGES = ["platform-tools", f"build-tools;{BUILD_TOOLS}", f"platforms;{PLATFORM}"]
ALIAS, PASSWORD = "androiddebugkey", "android"


def say(message: str) -> None:
    print(f"setup_android: {message}", file=sys.stderr)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def java_home() -> Path:
    """A JDK 17+ with keytool: $JAVA_HOME, else the one `java` on PATH belongs to."""
    candidates = []
    if os.environ.get("JAVA_HOME"):
        candidates.append(Path(os.environ["JAVA_HOME"]))
    java = shutil.which("java")
    if java:
        candidates.append(Path(java).resolve().parent.parent)
    for home in candidates:
        java_bin, keytool = home / "bin" / "java", home / "bin" / "keytool"
        if not (java_bin.is_file() and keytool.is_file()):
            continue
        out = subprocess.run([str(java_bin), "-version"], capture_output=True, text=True).stderr
        match = re.search(r'version "(\d+)', out)
        if match and int(match.group(1)) >= 17:
            return home
    raise RuntimeError("no JDK 17 or newer (set JAVA_HOME, or put its java on PATH)")


def sdkmanager() -> Path:
    return SDK / "cmdline-tools" / "latest" / "bin" / "sdkmanager"


def fetch_cmdline_tools() -> None:
    if sdkmanager().is_file():
        return
    TOOLS.mkdir(parents=True, exist_ok=True)
    archive = TOOLS / CMDLINE
    if not (archive.is_file() and sha256(archive) == CMDLINE_SHA256):
        part = archive.with_name(archive.name + ".part")
        say(f"downloading {CMDLINE}")
        try:
            with urllib.request.urlopen(CMDLINE_URL, timeout=60) as source, part.open("wb") as out:
                shutil.copyfileobj(source, out, 8 * 1024 * 1024)
            if sha256(part) != CMDLINE_SHA256:
                raise RuntimeError(f"checksum mismatch for {CMDLINE}")
            part.replace(archive)
        finally:
            part.unlink(missing_ok=True)
    staging = TOOLS / "unpack"
    shutil.rmtree(staging, ignore_errors=True)
    with zipfile.ZipFile(archive) as package:
        for info in package.infolist():
            target = package.extract(info, staging)
            mode = info.external_attr >> 16
            if mode:
                os.chmod(target, mode & 0o777)
    destination = SDK / "cmdline-tools" / "latest"
    destination.parent.mkdir(parents=True, exist_ok=True)
    shutil.rmtree(destination, ignore_errors=True)
    (staging / "cmdline-tools").replace(destination)
    shutil.rmtree(staging, ignore_errors=True)


def have_packages() -> bool:
    return ((SDK / "platform-tools" / "adb").is_file()
            and (SDK / "build-tools" / BUILD_TOOLS / "apksigner").is_file()
            and (SDK / "platforms" / PLATFORM / "android.jar").is_file())


def install_packages(jdk: Path) -> None:
    if have_packages():
        return
    env = dict(os.environ, JAVA_HOME=str(jdk))
    base = [str(sdkmanager()), f"--sdk_root={SDK}"]
    say("accepting the Android SDK licenses (--accept-licenses)")
    subprocess.run(base + ["--licenses"], input="y\n" * 50, text=True, env=env,
                   stdout=subprocess.DEVNULL, check=True)
    say("installing " + ", ".join(PACKAGES))
    subprocess.run(base + PACKAGES, input="y\n" * 10, text=True, env=env, stdout=subprocess.DEVNULL, check=True)
    if not have_packages():
        raise RuntimeError("sdkmanager ran, but the SDK is still missing a package")


def make_keystore(jdk: Path) -> None:
    if KEYSTORE.is_file():
        return
    say("making the debug keystore")
    subprocess.run([str(jdk / "bin" / "keytool"), "-genkeypair", "-keystore", str(KEYSTORE),
                    "-storepass", PASSWORD, "-keypass", PASSWORD, "-alias", ALIAS, "-keyalg", "RSA",
                    "-keysize", "2048", "-validity", "9999",
                    "-dname", "CN=Android Debug,O=Android,C=US"],
                   check=True, capture_output=True)


def write_config(jdk: Path) -> Path:
    """A Godot config directory whose editor settings name this SDK and JDK."""
    text = (ROOT / "project.godot").read_text()
    minor = re.search(r'config/features=PackedStringArray\("(\d+\.\d+)"', text)
    if not minor:
        raise RuntimeError("project.godot names no Godot version")
    settings = CONFIG / "godot" / f"editor_settings-{minor.group(1)}.tres"
    settings.parent.mkdir(parents=True, exist_ok=True)
    settings.write_text('[gd_resource type="EditorSettings" format=3]\n\n[resource]\n'
                        f'export/android/android_sdk_path = "{SDK}"\n'
                        f'export/android/java_sdk_path = "{jdk}"\n')
    return CONFIG


def environment(jdk: Path) -> dict[str, str]:
    env = {
        "ANDROID_HOME": str(SDK),
        "JAVA_HOME": str(jdk),
        "XDG_CONFIG_HOME": str(CONFIG),
        "GODOT_ANDROID_KEYSTORE_DEBUG_PATH": str(KEYSTORE),
        "GODOT_ANDROID_KEYSTORE_DEBUG_USER": ALIAS,
        "GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD": PASSWORD,
    }
    if not os.environ.get("GODOT_ANDROID_KEYSTORE_RELEASE_PATH"):
        say("no release keystore given: the release APK will be signed with the DEBUG key")
        env.update(GODOT_ANDROID_KEYSTORE_RELEASE_PATH=str(KEYSTORE),
                   GODOT_ANDROID_KEYSTORE_RELEASE_USER=ALIAS,
                   GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=PASSWORD)
    return env


def verify(apk: str) -> int:
    signer = SDK / "build-tools" / BUILD_TOOLS / "apksigner"
    if not signer.is_file():
        say(f"no apksigner in {SDK}; run this with --accept-licenses first")
        return 1
    env = dict(os.environ, JAVA_HOME=str(java_home()))
    result = subprocess.run([str(signer), "verify", "--print-certs", apk], env=env,
                            capture_output=True, text=True)
    if result.returncode != 0:
        say(f"{apk} does not verify:\n{result.stdout}{result.stderr}")
        return 1
    say(f"{apk} is signed: " + next((l for l in result.stdout.splitlines() if "DN:" in l), "verified"))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--accept-licenses", action="store_true",
                        help="accept Google's Android SDK licenses so the SDK can be installed")
    parser.add_argument("--print-env", action="store_true", help="print `export` lines for build.sh to eval")
    parser.add_argument("--verify", metavar="APK", help="check an APK's signature, then exit")
    args = parser.parse_args()
    try:
        if args.verify:
            return verify(args.verify)
        if not args.accept_licenses and not have_packages():
            say("the Android SDK is not installed here; pass --accept-licenses to fetch it "
                "(it accepts Google's Android SDK licenses)")
            return 1
        jdk = java_home()
        if not have_packages():
            fetch_cmdline_tools()
            install_packages(jdk)
        make_keystore(jdk)
        write_config(jdk)
        env = environment(jdk)
    except (OSError, RuntimeError, subprocess.CalledProcessError) as error:
        say(str(error))
        return 1
    if args.print_env:
        for key, value in env.items():
            print(f"export {key}={shlex.quote(value)}")
    else:
        say(f"ready: SDK in {SDK}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
