"""Fetch a YouTube channel's latest videos into a folder, unattended - an actor's footage cache.

    python3 scripts/fetch_channel.py <channel> --count N --out <folder> [--min-minutes 0] [--wait 45]
                                     [--cookies-from-browser firefox] [--cookies <file>] [--backoff 3600]
                                     [--no-captions] [--list] [--no-upgrade]

    python3 scripts/fetch_channel.py @EphemeralRift --count 60 --out "/home/crow/Downloads/Ephemeral Rift (more)"

<channel> is a handle (`@EphemeralRift`) or a channel's link. Its Videos tab is read newest first - the tab
YouTube keeps Shorts and live streams out of - and anything still to premiere or not public is passed over,
until N are found. Every length is taken (2026-10-27: a two-minute video is another sound and setting to
learn from); --min-minutes passes over the shorter. Each is fetched as the Actor card fetches a link
(src/likeness/actor_sources.gd, `fetch_args`): up to 1080p, H.264 and AAC where the site has them, its
automatic captions (json3: a time for every word) and its details beside it, named
`@<channel> - <title> (1080p).mp4`, so the Actor card reads the folder in place and finds each video's
captions by its name.

MADE TO RUN OVERNIGHT AND AGAIN:
- What is in the folder already is never fetched again: the archive (`archive.txt`, yt-dlp's own) lists
  every video fetched, and a video another downloader left there is known by its title (compared as
  the Actor card compares titles, its "(1080p, h264)" tag aside) and written into the archive.
- A video that fails is tried once more at the end; the rest go on. A partial download is carried on
  from where it stopped (`--continue`).
- A VIDEO'S CAPTIONS NEVER COST IT THE VIDEO (2026-10-27: "HTTP Error 429: Too Many Requests" on the captions of
  every captioned video, and so none of them fetched): yt-dlp asks for YouTube's captions as a browser would,
  through curl_cffi - without it they are refused - and a caption refused is a warning, the video fetched all
  the same (`--ignore-errors`: a video that fails still fails); its captions are asked for alone at the end. A
  video left without them is heard by the Actor card's Hear instead.
- It waits --wait seconds (give or take a third) between videos, and a second between requests.
- WHEN YOUTUBE ASKS IF IT IS A BOT ("Sign in to confirm you're not a bot" - after a dozen videos in a row,
  2026-10-23), it waits --backoff seconds (an hour: fifteen minutes was not enough) before the next, rather
  than meeting the same answer for every one left; that video is tried again at the end. Signed in, it is asked less: --cookies-from-browser reads the
  browser's own cookies (firefox, chrome, chromium, brave, edge, vivaldi, opera, safari; `name:profile` for a
  profile), --cookies a cookies.txt - the same as yt-dlp's options, handed to it. The cookies stay where they
  are; nothing is copied.
- Ctrl+C stops it; what is fetched is kept, and running it again carries on.
- Every line yt-dlp says goes to <out>/fetch.log as well; the end says what was fetched, what was there
  and what failed.

ITS OWN yt-dlp, KEPT CURRENT: an environment of its own (`~/.cache/fetch_channel/venv`, made with the Python
that runs this the first time), brought to the newest yt-dlp (with curl_cffi) and deno at the start of every run - YouTube
changes how it hands out video, and an older yt-dlp meets it as "HTTP Error 403: Forbidden" on every
download (2026-10-23, yt-dlp 2026.07.04). --no-upgrade skips that; --python names another Python with
yt_dlp in it. yt-dlp is given a JavaScript runtime for YouTube's challenges: the environment's deno, else deno
or node on the PATH. Standard library only.
"""

from __future__ import annotations

import argparse
import json
import os
import random
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path

# The Actor card's own choices (src/likeness/actor_sources.gd): the format, the captions.
FORMAT = "bv*[height<=1080][vcodec^=avc1]+ba[acodec^=mp4a]/b[height<=1080]"
SUB_LANGS = "en.*"
NAME = "%(uploader_id)s - %(title)s (%(height)sp).%(ext)s"
VIDEO_EXTS = {".mp4", ".mkv", ".webm", ".mov", ".m4v"}


def own_venv() -> Path:
    """The script's own environment, in the user's cache."""
    if sys.platform == "win32":
        base = Path(os.environ.get("LOCALAPPDATA") or Path.home() / "AppData" / "Local")
    elif sys.platform == "darwin":
        base = Path.home() / "Library" / "Caches"
    else:
        base = Path(os.environ.get("XDG_CACHE_HOME") or Path.home() / ".cache")
    return base / "fetch_channel" / "venv"


def ready(venv: Path, upgrade: bool) -> str:
    """The environment's Python, made if missing and brought to the newest yt-dlp and deno; "" if it could
    not be."""
    py = venv_bin(venv, "python")
    if not py.exists():
        print("making %s ..." % venv, flush=True)
        if subprocess.run([sys.executable, "-m", "venv", str(venv)]).returncode != 0:
            return ""
        upgrade = True
    if upgrade:
        print("bringing yt-dlp and deno to their newest ...", flush=True)
        # secretstorage: how yt-dlp reads a Chromium browser's cookies on Linux, where they are encrypted;
        # curl-cffi: how it asks for YouTube's captions as a browser (without it, "HTTP Error 429")
        r = subprocess.run([str(py), "-m", "pip", "install", "--quiet", "--disable-pip-version-check", "--upgrade",
                            "yt-dlp[default,curl-cffi]", "deno"] + (["secretstorage"] if sys.platform.startswith("linux") else []))
        if r.returncode != 0:
            return ""
    return str(py)


def venv_bin(venv: Path, name: str) -> Path:
    return venv / ("Scripts" if sys.platform == "win32" else "bin") / (name + (".exe" if sys.platform == "win32" else ""))


def runtime(venv: Path) -> list:
    """yt-dlp's JavaScript runtime: the environment's deno, else deno or node on the PATH."""
    own = venv_bin(venv, "deno")
    if own.exists():
        return ["--js-runtimes", "deno:" + str(own)]
    for rt in ("deno", "node"):
        found = shutil.which(rt)
        if found:
            return ["--js-runtimes", "%s:%s" % (rt, found)]
    return []


def comparable(title: str) -> str:
    """A title made comparable, as ActorSources.comparable makes it: a leading "@channel - " and a
    "(1080p, h264)"-style tag off, lowercase letters and digits, one space between runs."""
    t = title.strip()
    t = re.sub(r"\s*[\[(][^\])]*\b(?:\d{3,4}p|h264|h265|hevc|av1|vp9|avc1?)\b[^\])]*[\])]\s*$", "", t)
    t = re.sub(r"^@\S+\s+-\s+", "", t)
    return " ".join(re.findall(r"[a-z0-9]+", t.lower()))


def channel_url(channel: str) -> str:
    """The channel's Videos tab - where YouTube keeps Shorts and live streams out."""
    c = channel.strip()
    if not c.startswith("http"):
        c = "https://www.youtube.com/" + (c if c.startswith("@") else "@" + c)
    c = re.sub(r"/(videos|shorts|streams|featured|playlists)/?$", "", c.rstrip("/"))
    return c + "/videos"


class Log:
    """Every line to the terminal, and to the log file when there is one (none for --list)."""

    def __init__(self, path):
        self.f = open(path, "a", encoding="utf-8") if path else open(os.devnull, "w")

    def __call__(self, *parts) -> None:
        line = " ".join(str(p) for p in parts)
        print(line, flush=True)
        self.f.write(time.strftime("%Y-%m-%d %H:%M:%S ") + line + "\n")
        self.f.flush()


def listing(py: str, rt: list, url: str, most: int, log: Log) -> list:
    """The tab's newest [most] entries: [{id, title, duration, live_status, availability}]."""
    cmd = [py, "-u", "-m", "yt_dlp", "--flat-playlist", "-J", "--no-warnings", "--playlist-end", str(most)] + rt + [url]
    out = subprocess.run(cmd, capture_output=True, text=True)
    if out.returncode != 0:
        log("could not list %s: %s" % (url, (out.stderr or "").strip().splitlines()[-1:] or "no reason given"))
        return []
    entries = json.loads(out.stdout).get("entries") or []
    return [e for e in entries if isinstance(e, dict) and e.get("id")]


def wanted(e: dict, min_minutes: float) -> str:
    """Why entry [e] is passed over, "" when it is wanted."""
    if e.get("live_status") in ("is_upcoming", "is_live"):
        return "not out yet" if e.get("live_status") == "is_upcoming" else "live now"
    if e.get("availability") not in (None, "public", "unlisted"):
        return str(e.get("availability"))
    d = e.get("duration")
    if d is not None and float(d) < min_minutes * 60.0:
        return "%.1f minutes" % (float(d) / 60.0)
    return ""


def already(out: Path) -> tuple:
    """(the archive's ids, the titles of the videos in the folder, comparable)."""
    ids = set()
    arch = out / "archive.txt"
    if arch.exists():
        for line in arch.read_text(encoding="utf-8").splitlines():
            parts = line.split()
            if len(parts) == 2:
                ids.add(parts[1])
    titles = {}
    for p in out.iterdir():
        if p.suffix.lower() in VIDEO_EXTS and not p.name.endswith(".part"):
            titles[comparable(p.stem)] = p.name
    return ids, titles


# yt-dlp's warning that it cannot ask as a browser, said in the terminal once a run
TOLD = set()


def fetch(py: str, rt: list, vid: str, out: Path, captions: bool, log: Log, captions_only: bool = False) -> str:
    """One video into [out], as the Actor card fetches one; yt-dlp's every line into the log. "ok", "captions"
    (the video fetched, its captions refused), "bot" (YouTube asked it to sign in, to prove it is not a bot) or
    "failed". [captions_only]: its captions alone, named as its video is - the archive, which lists the video,
    would pass it over."""
    cmd = [py, "-u", "-m", "yt_dlp", "--no-playlist", "--newline", "--no-overwrites", "--continue",
           "--socket-timeout", "30", "--retries", "10", "--fragment-retries", "10", "--sleep-requests", "1",
           "-f", FORMAT, "--ignore-errors", "-o", str(out / NAME)]
    if captions_only:
        cmd += ["--skip-download"]
    else:
        cmd += ["--merge-output-format", "mp4", "--throttled-rate", "100K", "--concurrent-fragments", "4",
                "--download-archive", str(out / "archive.txt"), "--write-info-json"]
    if captions or captions_only:
        cmd += ["--write-auto-subs", "--sub-langs", SUB_LANGS, "--sub-format", "json3"]
    cmd += rt + ["https://www.youtube.com/watch?v=" + vid]
    p = subprocess.Popen(cmd, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
    last = 0.0
    bot = False
    refused = False
    for line in p.stdout:
        line = line.rstrip()
        if "not a bot" in line:
            bot = True
        if "Unable to download video subtitles" in line:
            refused = True
            print("   " + line, flush=True)
        if "no impersonate target is available" in line and "impersonate" not in TOLD:
            TOLD.add("impersonate")
            print("   yt-dlp cannot ask as a browser (no curl_cffi in its Python): YouTube refuses captions more "
                  "often", flush=True)
        # the progress lines, once every half minute; everything else as it comes
        if "[download]" in line and "%" in line and "Destination" not in line:
            if time.time() - last < 30.0:
                continue
            last = time.time()
        log.f.write(time.strftime("%Y-%m-%d %H:%M:%S   ") + line + "\n")
        if "ERROR" in line or "Merging" in line or "has already been" in line:
            print("   " + line, flush=True)
    log.f.flush()
    if p.wait() == 0:
        return "captions" if refused else "ok"
    return "bot" if bot else "failed"


def main() -> int:
    ap = argparse.ArgumentParser(description="Fetch a channel's latest videos (not Shorts) into a folder.")
    ap.add_argument("channel", help="a handle (@Name) or a channel's link")
    ap.add_argument("--count", type=int, required=True, help="how many videos to have fetched (newest first)")
    ap.add_argument("--out", required=True, help="the folder they go to (made if missing)")
    ap.add_argument("--min-minutes", type=float, default=0.0, help="shorter videos are passed over (none by default)")
    ap.add_argument("--wait", type=float, default=45.0, help="seconds between videos, give or take a third")
    ap.add_argument("--no-captions", action="store_true", help="fetch no automatic captions")
    ap.add_argument("--list", action="store_true", help="say what would be fetched, and fetch nothing")
    ap.add_argument("--no-upgrade", action="store_true", help="use the environment's yt-dlp as it is")
    ap.add_argument("--python", default="", help="another Python with yt_dlp in it, not the script's own")
    ap.add_argument("--cookies-from-browser", default="", metavar="BROWSER",
                    help="sign in as the browser is (firefox, chrome, ...; name:profile): YouTube asks less if it is a bot")
    ap.add_argument("--cookies", default="", metavar="FILE", help="a cookies.txt to sign in with")
    ap.add_argument("--backoff", type=float, default=3600.0,
                    help="seconds to wait when YouTube asks if this is a bot, before the next video")
    a = ap.parse_args()
    try:
        return run(a)
    except KeyboardInterrupt:
        print("\nstopped - what is fetched is kept; run it again to carry on", flush=True)
        return 130


def run(a) -> int:
    venv = own_venv()
    py = a.python or ready(venv, not a.no_upgrade)
    if not py or not Path(py).exists():
        print("could not make yt-dlp's environment at %s (see above), or give --python" % venv)
        return 2
    ver = subprocess.run([py, "-m", "yt_dlp", "--version"], capture_output=True, text=True).stdout.strip()
    out = Path(a.out).expanduser()
    if not a.list:
        out.mkdir(parents=True, exist_ok=True)
    log = Log(None if a.list else out / "fetch.log")
    js = runtime(venv)
    auth = (["--cookies-from-browser", a.cookies_from_browser] if a.cookies_from_browser else []) \
        + (["--cookies", str(Path(a.cookies).expanduser())] if a.cookies else [])
    rt = js + auth
    url = channel_url(a.channel)
    log("listing %s (yt-dlp %s, %s%s)" % (url, ver, js[1].split(":")[0] if js else "no JavaScript runtime",
                                         ", signed in as " + (a.cookies_from_browser or "cookies.txt") if auth else ""))
    entries = listing(py, rt, url, max(a.count * 2, a.count + 10), log)
    if not entries:
        return 1
    ids, titles = already(out) if out.is_dir() else (set(), {})
    picked, passed = [], []
    for e in entries:
        why = wanted(e, a.min_minutes)
        if why:
            passed.append((e, why))
            continue
        picked.append(e)
        if len(picked) >= a.count:
            break
    have, todo = [], []
    for e in picked:
        name = titles.get(comparable(e.get("title") or ""))
        if e["id"] in ids or name:
            have.append((e, name))
            # a video another downloader left here: the archive learns it, so yt-dlp passes it too
            if e["id"] not in ids and not a.list:
                with open(out / "archive.txt", "a", encoding="utf-8") as f:
                    f.write("youtube %s\n" % e["id"])
        else:
            todo.append(e)
    for e, why in passed:
        log("  passed over: %s (%s)" % (e.get("title"), why))
    for e, name in have:
        log("  already here: %s" % (name or e.get("title")))
    minutes = sum(float(e.get("duration") or 0) for e in todo) / 60.0
    log("%d of the newest %d to fetch (%.0f minutes of video, about %.0f GB at 1080p - his first eight ran 1.35 GB "
        "an hour); %d already here" % (len(todo), len(picked), minutes, minutes / 60.0 * 1.35, len(have)))
    if a.list:
        for e in todo:
            log("  would fetch: %s (%.0f min)" % (e.get("title"), float(e.get("duration") or 0) / 60.0))
        return 0
    failed, uncaptioned = [], []
    for n, e in enumerate(todo):
        log("[%d/%d] %s" % (n + 1, len(todo), e.get("title")))
        got = fetch(py, rt, e["id"], out, not a.no_captions, log)
        if got == "captions":
            uncaptioned.append(e)
            log("   fetched, but not its captions - asked for again at the end")
        elif got != "ok":
            failed.append(e)
            log("   failed - tried again at the end")
        if n + 1 < len(todo):
            if got == "bot":
                log("   YouTube asked if this is a bot: waiting %.0f minutes%s" % (a.backoff / 60.0,
                    "" if auth else " (--cookies-from-browser makes it ask less)"))
                time.sleep(a.backoff)
            else:
                time.sleep(a.wait * random.uniform(0.67, 1.33))
    still = []
    for e in failed:
        log("[again] %s" % e.get("title"))
        time.sleep(a.wait)
        got = fetch(py, rt, e["id"], out, not a.no_captions, log)
        if got == "bot":
            log("   YouTube asked again: waiting %.0f minutes" % (a.backoff / 60.0))
            time.sleep(a.backoff)
            got = fetch(py, rt, e["id"], out, not a.no_captions, log)
        if got == "captions":
            uncaptioned.append(e)
        elif got != "ok":
            still.append(e)
    bare = []
    for e in uncaptioned:
        log("[captions] %s" % e.get("title"))
        time.sleep(a.wait)
        if fetch(py, rt, e["id"], out, True, log, captions_only=True) != "ok":
            bare.append(e)
    log("done: %d fetched, %d already here, %d failed%s%s" % (
        len(todo) - len(still), len(have), len(still),
        "".join("\n  failed: %s" % e.get("title") for e in still),
        "".join("\n  no captions (Hear will transcribe it): %s" % e.get("title") for e in bare)))
    return 1 if still else 0


if __name__ == "__main__":
    raise SystemExit(main())
