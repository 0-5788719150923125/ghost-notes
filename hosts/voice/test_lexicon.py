#!/usr/bin/env python3
"""Tests for the reading of words eSpeak has to guess at (lexicon.py).

Run it directly with the voice venv's python - no pytest needed:

    ~/.local/share/godot/app_userdata/ghost/voice_venv/bin/python hosts/voice/test_lexicon.py

eSpeak is real here (the readings it guesses are the subject); Wiktionary is NOT - a fake
fetch hands back kaikki's own entries for the words, so the suite never touches the network.

  THE REPORT - cosine, cotangent and cosecant come out exactly as the clip the user chose
  ("B sounds quite a bit better", 2026-10-16): kˈoʊsˌaɪn, kˈoʊtˌændʒənt, kˈoʊsˌiːkənt.
  THE CONVERSION - Wiktionary's transcription in eSpeak's spelling: the stress on the vowel, the
  long vowels long, the narrow detail gone; an accent not ours is not used.
  THE HOLDS - a word not marked rare, one with an authored reading, a reading the voice cannot
  spell and a word whose readings already agree are left exactly as they were; "off" asks nobody.
  THE CACHE - a fetched reading is kept and read back without asking again; a word Wiktionary
  lacks is remembered as missing; a network that does not answer is not, and is not asked again
  for a while.
"""

from __future__ import annotations

import sys
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
if str(HERE) not in sys.path:
    sys.path.insert(0, str(HERE))

import lexicon  # noqa: E402
from test_homographs import _speak  # noqa: E402  (the same eSpeak call the backend makes)

# kaikki's entries for the words, as its site answers (the `sounds` only)
KAIKKI = {
    "cosine": [{"sounds": [{"ipa": "/ˈkəʊ.saɪn/", "tags": ["UK"]}, {"ipa": "/ˈkoʊ.saɪn/", "tags": ["US"]}]}],
    "cotangent": [{"sounds": [{"ipa": "/ˈkoʊˌtænd͡ʒənt/", "tags": ["US"]}]}],
    "cosecant": [{"sounds": [{"ipa": "/ˈkoʊˌsiːkənt/", "tags": ["US"]}]}],
    "trigonometry": [{"sounds": [{"ipa": "/ˌtɹɪɡəˈnɒmətɹi/"}]}],
}
# every symbol the voice can spell: everything eSpeak and the conversion write, and no more
PMAP = {ch: [0] for ch in "abcdefghijklmnopqrstuvwxyzæɑɒɔəɐɛɜɚɪʊʌᵻɹɡʃʒθðŋɾʔˈˌː "}

CHECKS = []


def check(fn):
    CHECKS.append(fn)
    return fn


def ok(cond, what):
    if not cond:
        raise AssertionError(what)
    print(f"    ok   {what}")


class Fetch:
    """kaikki, from KAIKKI: a word it lacks is [] (a 404); `down` makes the network not answer."""

    def __init__(self, down=False):
        self.asked = []
        self.down = down

    def __call__(self, word):
        self.asked.append(word)
        return None if self.down else KAIKKI.get(word, [])


def _rare(*words, **extra):
    return [{"text": w, "punct": "", "fallback": [], "rare": True, **extra} for w in words]


@check
def the_report():
    with tempfile.TemporaryDirectory() as td:
        lx = lexicon.Lexicon(_speak, td, Fetch())
        toks = _rare("cosine", "cotangent", "cosecant")
        lx.annotate(toks, "en-us", "fetch", PMAP)
        got = [t.get("ipa") for t in toks]
        ok(got == ["kˈoʊsˌaɪn", "kˈoʊtˌændʒənt", "kˈoʊsˌiːkənt"],
           "the three come out as the clip the user chose (%s)" % got)


@check
def the_conversion():
    for raw, want in [("/ˈkoʊˌsiːkənt/", "kˈoʊsˌiːkənt"), ("/ˈkoʊˌtænd͡ʒənt/", "kˈoʊtˌændʒənt"),
                      ("/ˈɹeɪdiən/", "ɹˈeɪdiən"), ("/haɪˈpɑtənus/", "haɪpˈɑːtənuːs"),
                      ("/p(a)ɪˌθaɡəˈɹiːən/", "pɪθˌæɡəɹˈiːən")]:
        ok(lexicon.to_espeak(raw) == want, "%s is written %s (%s)" % (raw, want, lexicon.to_espeak(raw)))
    ok(lexicon.pick(KAIKKI["cosine"]) == "/ˈkoʊ.saɪn/", "the American reading is picked over the British")
    ok(lexicon.pick(KAIKKI["trigonometry"]) == "",
       "the control: an untagged reading in British symbols (ɒ) is not used")


@check
def the_stress():
    ok(lexicon.secondary("kˈoʊsaɪn") == "kˈoʊsˌaɪn", "an unstressed full vowel gets a secondary stress")
    for same in ("tɹˌɪɡənˈɑːmətɹi", "ɹˈeɪdiənz", "sˈiːkənt"):
        ok(lexicon.secondary(same) == same, "the control: reduced vowels take none (%s)" % same)


@check
def the_holds():
    with tempfile.TemporaryDirectory() as td:
        f = Fetch()
        lx = lexicon.Lexicon(_speak, td, f)
        plain = [{"text": "cosine", "punct": "", "fallback": []}]
        pinned = _rare("cosine", arpa=["K", "OW1"])
        lx.annotate(plain + pinned, "en-us", "fetch", PMAP)
        ok("ipa" not in plain[0] and "ipa" not in pinned[0] and not f.asked,
           "a word not marked rare, and one with an authored reading, are not touched or looked up")
        same = _rare("radians")
        lx.annotate(same, "en-us", "fetch", PMAP)
        ok("ipa" not in same[0], "a word whose reading already agrees is left to eSpeak in its sentence")
        narrow = {k: v for k, v in PMAP.items() if k != "ˌ"}
        cannot = _rare("cosine")
        lx.annotate(cannot, "en-us", "fetch", narrow)
        ok("ipa" not in cannot[0], "a reading the voice cannot spell is not sent")
        off = Fetch()
        lo = lexicon.Lexicon(_speak, td + "/off", off)
        toks = _rare("cosine", "cosecant")
        lo.annotate(toks, "en-us", "off", PMAP)
        ok(not off.asked and toks[0].get("ipa") == "kˈoʊsˌaɪn" and toks[1].get("ipa") == "kˈoʊsˌɛkənt",
           "off asks nobody - the stress rule still applies, with eSpeak's own vowels (%s)" % toks[1].get("ipa"))


@check
def the_cache():
    with tempfile.TemporaryDirectory() as td:
        f = Fetch()
        lexicon.Lexicon(_speak, td, f).annotate(_rare("cosecant", "zorbleflux"), "en-us", "fetch", PMAP)
        kept = lexicon.Lexicon(_speak, td, Fetch(down=True))
        toks = _rare("cosecant", "zorbleflux")
        kept.annotate(toks, "en-us", "cache", PMAP)
        ok(toks[0].get("ipa") == "kˈoʊsˌiːkənt", "a fetched reading is kept, and read back with nothing asked")
        again = Fetch()
        lexicon.Lexicon(_speak, td, again).wiktionary("zorbleflux", "fetch")
        ok(not again.asked, "a word Wiktionary lacks is remembered as missing, not asked again")
        down = Fetch(down=True)
        lx = lexicon.Lexicon(_speak, td + "/down", down)
        lx.wiktionary("cosine", "fetch")
        lx.wiktionary("tangent", "fetch")
        ok(down.asked == ["cosine"] and "cosine" not in lx._load(),
           "a network that does not answer is not remembered, and not asked again for a while")


def main() -> int:
    try:
        _speak(["probe"])
    except Exception as exc:  # noqa: BLE001
        print(f"eSpeak is not available in this environment: {exc}")
        return 2
    failed = 0
    for fn in CHECKS:
        print(f"\n{fn.__name__}")
        try:
            fn()
        except AssertionError as exc:
            failed += 1
            print(f"    FAIL {exc}")
    print(f"\n{len(CHECKS) - failed}/{len(CHECKS)} checks passed")
    return 1 if failed else 0


if __name__ == "__main__":
    raise SystemExit(main())
