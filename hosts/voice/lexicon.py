#!/usr/bin/env python3
"""Words eSpeak has to guess at: Wiktionary's reading, and a stress on every full vowel.

A word CMUdict does not have (ghost's `Phonemes.is_known` - the audit's UNKNOWN) reaches
eSpeak with no dictionary behind it, and eSpeak answers from its letter rules. The reported
case (2026-10-16, a lesson on the six trig functions): cosine said "co-seen", cotangent
"co-angent", cosecant "co-seh-cant". eSpeak gives

    cosine     kˈoʊsaɪn        cotangent  kˈoʊtændʒənt        cosecant  kˈoʊsɛkənt

- THE CORE SYLLABLE UNSTRESSED in each, and en_US-libritts-high slurs a full vowel it is given
no stress on: the diphthong of "sine" closes to "ee", the t of "tan" goes. A dictionary marks a
secondary stress there (Merriam-Webster \\ˈkō-ˌsīn\\), and cosecant's vowel is wrong besides.
The user, hearing the sentence both ways: the second (kˈoʊsˌaɪn, kˈoʊtˌændʒənt, kˈoʊsˌiːkənt)
"sounds quite a bit better". So, for such a word only:

  1. ITS READING is Wiktionary's American one where Wiktionary has it - fetched once from
     kaikki.org (Tatu Ylonen's wiktextract: Wiktionary as JSON, one file per word, rebuilt from
     the dumps) and kept in a cache beside the voices - else eSpeak's own.
  2. EVERY FULL VOWEL LEFT UNSTRESSED is given a secondary stress ([secondary]). A reduced one
     (schwa, the short i and u, the r-colored schwa) is left as it is - that is what reduction is.

WHY ONLY THESE WORDS. eSpeak's transcriptions are what the voices were trained on, and a
dictionary in another convention disagrees with them on a third of ordinary words (requirements.txt,
"was" -> "wars"). A word eSpeak knows is left to eSpeak; a word it is guessing at has nothing to
lose. The reading panel marks them (`rare` on the token) - this file decides nothing about which.

WIKTIONARY'S IPA IS NOT ESPEAK'S, so it is rewritten ([to_espeak]): the stress mark moved from the
syllable's start to its vowel (where eSpeak puts it), the long vowels written long (/i/ -> iː,
/ɑ/ -> ɑː), tie bars, syllable dots and narrow detail dropped, and an entry tagged for another
accent - or an untagged one in British symbols (ɒ, əʊ, ɪə) - not used. Every symbol of the result
must be in the voice's own phoneme map, or eSpeak's reading is kept.

THE NETWORK IS NEVER A FAILURE. A fetch waits FETCH_TIMEOUT at most; a word Wiktionary does not
have is remembered as missing (and asked again after MISS_DAYS); a network that does not answer
is left alone for OFFLINE_RETRY seconds. `mode` comes with each request: "fetch" (the app),
"cache" (read what is kept, ask nothing) or "off" (a gate or a probe: no Wiktionary at all, so a
test is the same on every machine - the stress rule still applies, it needs nothing outside).

LICENSE: Wiktionary's text is CC BY-SA. It is fetched at run time into the user's own cache and
never shipped; nothing here redistributes it.
"""

from __future__ import annotations

import json
import os
import re
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

URL = "https://kaikki.org/dictionary/English/meaning/{a}/{ab}/{word}.jsonl"
FETCH_TIMEOUT = 4.0
OFFLINE_RETRY = 600.0
MISS_DAYS = 30
HIT_DAYS = 180

STRESS = ("ˈ", "ˌ")
# One vowel nucleus each, longest first: a diphthong, a long vowel, then a single vowel.
NUCLEI = ("aɪ", "aʊ", "eɪ", "oʊ", "ɔɪ", "əʊ", "iː", "uː", "ɑː", "ɔː", "ɜː", "ɛː")
VOWEL = set("aeiouæɑɒɔəɐɛɜɝɚɪʊʌʉɨᵻɵøœy")
# What reduction leaves: these take no stress of their own.
REDUCED = {"ə", "ɐ", "ɪ", "ᵻ", "i", "u", "ʊ", "ɚ", "ɨ"}
# Accents whose readings are this voice's (American), and the symbols only another accent uses.
OURS = {"US", "General-American", "GA", "General American", "Canada"}
THEIRS = ("ɒ", "əʊ", "ɪə", "eə", "ʊə")
# Narrow detail a voice trained on eSpeak never saw: tie bars, syllable dots, aspiration, release,
# non-syllabic and nasal marks, dental and voice marks.
NARROW = "͡‿.ʰ̯̥̬̪̃̚ʼʲʷˠˑ"


def nuclei(ipa: str) -> list[tuple[int, int]]:
    """(start, end) of every vowel nucleus in an eSpeak-style IPA string."""
    out, i = [], 0
    while i < len(ipa):
        hit = next((n for n in NUCLEI if ipa.startswith(n, i)), None)
        if hit:
            out.append((i, i + len(hit)))
            i += len(hit)
        elif ipa[i] in VOWEL:
            end = i + 1 + (ipa[i + 1:i + 2] == "ː")
            out.append((i, end))
            i = end
        else:
            i += 1
    return out


def secondary(ipa: str) -> str:
    """`ipa` with a secondary stress before every full vowel that has no stress of its own."""
    out, last = [], 0
    for a, b in nuclei(ipa):
        stressed = a > 0 and ipa[a - 1] in STRESS
        full = ipa[a:b] not in REDUCED
        out.append(ipa[last:a])
        if full and not stressed:
            out.append("ˌ")
        out.append(ipa[a:b])
        last = b
    out.append(ipa[last:])
    return "".join(out)


def to_espeak(ipa: str) -> str:
    """A Wiktionary IPA transcription written as eSpeak writes one (see the module note)."""
    s = ipa.strip().strip("/[]")
    s = re.sub(r"\([^)]*\)", "", s)                  # optional sounds: left out
    s = "".join(ch for ch in s if ch not in NARROW)
    s = s.replace("ɫ", "l").replace("r", "ɹ").replace("g", "ɡ").replace("ɝ", "ɜː")
    s = s.replace("ɜːː", "ɜː")
    out = []
    for i, ch in enumerate(s):
        nxt = s[i + 1:i + 2]
        prev = s[i - 1:i]
        if ch == "i" and nxt not in ("ː",) and prev not in ("a", "e", "o", "ɔ") \
                and nxt and nxt not in VOWEL and nxt not in STRESS:
            out.append("iː")
        elif ch == "u" and nxt != "ː" and prev not in ("a", "o"):
            out.append("uː")
        elif ch == "ɑ" and nxt != "ː":
            out.append("ɑː")
        elif ch == "ɔ" and nxt not in ("ː", "ɪ"):
            out.append("ɔː")
        elif ch == "e" and nxt != "ɪ":
            out.append("eɪ")
        elif ch == "o" and nxt != "ʊ":
            out.append("oʊ")
        elif ch == "a" and nxt not in ("ɪ", "ʊ"):
            out.append("æ")
        else:
            out.append(ch)
    s = "".join(out)
    # THE STRESS MARK MOVES TO ITS VOWEL: Wiktionary writes it at the syllable's start
    # (ˈkoʊˌsiːkənt), eSpeak right before the nucleus (kˈoʊsˌiːkənt)
    moved, pending = [], ""
    spans = {a: b for a, b in nuclei(s)}
    i = 0
    while i < len(s):
        if s[i] in STRESS:
            pending = s[i]
            i += 1
            continue
        if i in spans:
            moved.append(pending + s[i:spans[i]])
            pending = ""
            i = spans[i]
            continue
        moved.append(s[i])
        i += 1
    return "".join(moved)


def pick(entries: list) -> str:
    """The American reading among kaikki entries' `sounds`, or "" for none we can use: one tagged
    for this accent first, else an untagged one written in no other accent's symbols."""
    sounds = [s for e in entries for s in e.get("sounds", []) if s.get("ipa")]
    for s in sounds:
        if OURS & set(s.get("tags") or []):
            return s["ipa"]
    for s in sounds:
        if not s.get("tags") and not any(t in s["ipa"] for t in THEIRS):
            return s["ipa"]
    return ""


class Lexicon:
    """Wiktionary's readings, kept in `cache_dir`; eSpeak's own `speak(words, voice)` beside them."""

    def __init__(self, speak, cache_dir, fetch=None) -> None:
        self._speak = speak
        self._path = Path(cache_dir) / "wiktionary.json"
        self._fetch = fetch or self._get
        self._cache: dict | None = None
        self._offline_until = 0.0
        self.last: list[tuple[str, str, str]] = []   # (word, reading, where it came from)

    # -- the cache ----------------------------------------------------------------------

    def _load(self) -> dict:
        if self._cache is None:
            try:
                self._cache = json.loads(self._path.read_text(encoding="utf-8"))
            except (OSError, ValueError):
                self._cache = {}
        return self._cache

    def _save(self) -> None:
        try:
            self._path.parent.mkdir(parents=True, exist_ok=True)
            tmp = self._path.with_suffix(".part")
            tmp.write_text(json.dumps(self._cache, ensure_ascii=False, sort_keys=True), encoding="utf-8")
            os.replace(tmp, self._path)
        except OSError as exc:
            print(f"ghost/voice: the lexicon cache could not be written ({exc})", file=sys.stderr)

    # -- Wiktionary ------------------------------------------------------------------------

    @staticmethod
    def _get(word: str):
        """kaikki's entries for `word` (a list), [] when Wiktionary has none, None when the
        network did not answer."""
        q = urllib.parse.quote
        url = URL.format(a=q(word[0]), ab=q(word[:2]), word=q(word))
        req = urllib.request.Request(url, headers={"User-Agent": "ghost-notes voice lexicon"})
        try:
            with urllib.request.urlopen(req, timeout=FETCH_TIMEOUT) as r:
                return [json.loads(line) for line in r.read().decode("utf-8").splitlines() if line.strip()]
        except urllib.error.HTTPError as exc:
            return [] if exc.code == 404 else None
        except (urllib.error.URLError, OSError, ValueError):
            return None

    def wiktionary(self, word: str, mode: str) -> str:
        """Wiktionary's American reading of `word` in eSpeak's spelling, "" for none."""
        if mode not in ("fetch", "cache"):
            return ""
        key = word.lower()
        cache = self._load()
        got = cache.get(key)
        stale = got is None or time.time() - float(got.get("t", 0)) > 86400 * (
            HIT_DAYS if got.get("ipa") else MISS_DAYS)
        if stale and mode == "fetch" and time.time() >= self._offline_until:
            raw = ""
            answered = True
            for form in dict.fromkeys([word, key, key.capitalize()]):
                entries = self._fetch(form)
                if entries is None:
                    answered = False
                    self._offline_until = time.time() + OFFLINE_RETRY
                    break
                raw = pick(entries)
                if raw:
                    break
            if answered:
                got = {"ipa": to_espeak(raw) if raw else "", "raw": raw, "t": time.time()}
                cache[key] = got
                self._save()
        return str((got or {}).get("ipa", ""))

    # -- the pass --------------------------------------------------------------------------

    def annotate(self, tokens: list, voice: str, mode: str, pmap: dict) -> int:
        """Set `ipa` on every `rare` token: Wiktionary's reading or eSpeak's, with the full vowels
        stressed - where that differs from eSpeak's own. Returns how many were rewritten."""
        self.last = []
        n = 0
        for t in tokens:
            if not t.get("rare") or t.get("arpa") or t.get("ipa"):
                continue
            word = str(t.get("text", "")).strip()
            if not word.isalpha():
                continue
            try:
                said = (self._speak([word], voice) or [""])[0].strip()
            except Exception as exc:  # noqa: BLE001 - a phonemizer fault must not lose audio
                print(f"ghost/voice: lexicon - eSpeak failed on {word!r} ({exc})", file=sys.stderr)
                continue
            base, where = self.wiktionary(word, mode), "wiktionary"
            if not base or not all(ch in pmap for ch in base):
                base, where = said, "espeak"
            if not base:
                continue
            ipa = secondary(base)
            if ipa != said and all(ch in pmap for ch in ipa):
                t["ipa"] = ipa
                self.last.append((word, ipa, where))
                n += 1
        return n
