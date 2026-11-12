#!/usr/bin/env python3
"""Homograph readings chosen by part of speech, elicited from eSpeak itself.

`PiperBackend._espeak` phonemizes word by word (ghost needs to know which phones belong to which word), and
a word alone on the line has no syntax, so eSpeak falls back to its default reading ("he read the book" and
"I will read the book" are not the same word).

No pronunciation table lives here. The word is phonemized a second time inside a carrier phrase that forces
the part of speech the tagger found:

    they will {} them     verb, base/present      (VB VBP VBZ VBG)
    they have {} them     verb, past/participle   (VBD VBN)
    the {} was            noun                    (NN NNS NNP NNPS)
    the {} thing          adjective               (JJ JJR JJS)

    read     alone ɹˈiːd      "they have read them"    ɹˈɛd
    record   alone ɹˈɛkɚd     "they will record them"  ɹᵻkˈɔːɹd
    live     alone lˈaɪv      "they will live them"    lˈɪv
    refuse   alone ɹᵻfjˈuːz   "the refuse was"         ɹˈɛfjuːs

The reading is eSpeak's own, in eSpeak's symbols, for a model trained on eSpeak, so there is no convention
mismatch (223 of g2p_en's 371 entries transcribe differently from eSpeak).

The carriers end in a consonant on purpose: with "they will {} it" / "the {} is" a 3000-word sample gave 257
POS-conditioned readings, nearly all linking R (`miller` is mˈɪlɚ alone, mˈɪlɚɹ before a vowel);
`them`/`was`/`thing` drops that to 24.

A word is rewritten only when the carrier reading differs from what the word-by-word path already produces
(as `Phonemes.SPEAK_AS`), so a word read one way in every frame is untouched. An authored `[R EH1 D]`
override arrives with `arpa` set and is skipped.

Tagging is nltk's averaged perceptron over the sentence ghost already split; the tag alone is not enough,
hence the tense pass below. If nltk or its data is missing the whole pass turns itself off and the reading
is unchanged.

No word lists: homographs come from eSpeak, function words from nltk's stopword corpus, modals,
coordinators, determiners and adverbs from the Penn tags. The one constant is the inflection of BE and HAVE.
Where a category cannot be sourced the limitation is documented and left in place (see rule 8).
"""

from __future__ import annotations

import sys
from pathlib import Path

# Penn Treebank tag -> the frame that forces that reading, and which word of the phonemized result is ours.
# Anything not listed (adverbs, determiners, numbers, foreign words) is left alone: eSpeak has no reading
# keyed to those.
CARRIERS: dict[str, tuple[str, int, int]] = {
    #        frame                    slot  expected words
    "VB": ("they will {} them", 2, 4),
    "VBD": ("they have {} them", 2, 4),
    "NN": ("the {} was", 1, 3),
    "JJ": ("the {} thing", 1, 3),
}

FAMILY: dict[str, str] = {
    "VB": "VB",
    "VBP": "VB",
    "VBZ": "VB",
    "VBG": "VB",
    "VBD": "VBD",
    "VBN": "VBD",
    "NN": "NN",
    "NNS": "NN",
    "NNP": "NN",
    "NNPS": "NN",
    "JJ": "JJ",
    "JJR": "JJ",
    "JJS": "JJ",
}

# The tense pass. The tagger alone is not enough: `read` is spelled the same in every tense, so there is no
# morphological evidence in the word and VB/VBP from this tagger mean "no evidence found", not "present
# tense" ("I stood at the mailbox and read that seed catalog" tags VB, "I read your book in two nights" VBP;
# both are past).
#
# The evidence is in the clause: conjuncts share a tense, a complement inherits its matrix clause's tense,
# and a narrative holds one tense across sentences. So when the tag carries no evidence the tense is taken
# from the nearest preceding finite verb, failing that from the tense the surrounding prose is written in.
#
# Nothing below is a list of words that went wrong:
#   * the closed class comes from nltk's stopword corpus;
#   * modals, coordinators, adverbs, determiners and every other category are Penn Treebank tags (`cannot`,
# `can't`, `won't` and `wouldn't` all come back VBZ rather than MD, so enumerating modals never finishes);
#   * a habitual adverb ("sometimes I read the paper" in a past-tense chapter) is not handled, and is a
# known limitation.
# What is left is one twelve-word constant, closed by construction: the complete inflection of BE and HAVE.

# Every verb tag: "the tagger thinks this is a verb at all", which decides whether the noun/verb fallback in
# `_reading` may run.
VERB_TAGS = frozenset(("VB", "VBP", "VBZ", "VBG", "VBD", "VBN"))
# Tags that ARE evidence of tense, and which way they point.
PAST_TAGS = frozenset(("VBD", "VBN"))
PRESENT_TAGS = frozenset(("VBZ",))
# ...and the two that are not evidence of anything: the bare form and the non-third-person present, spelled
# identically to the past for `read`, `cut`, `set`, `put` and every other invariant verb.
UNMARKED_TAGS = frozenset(("VB", "VBP"))

# Present evidence from an auxiliary, the one place a VBP tag can be trusted. VBP is unmarked on the word
# being decided, and not reliable on other words either (this tagger returns VBP for `forgotten`, which can
# only be VBN). An inflected form of BE or HAVE is reliable: they carry the tense of every periphrastic
# verb. So: VBZ anywhere, VBP only on those.

# The one word list in this file, and a complete one: every inflected form of BE and HAVE, the two
# auxiliaries whose complement is a participle ("was read aloud", "had wound the clock"). DO takes a bare
# infinitive and falls out as "a stopword tagged as a verb that is not one of these", which also catches
# `cannot`, `won't` and `doesn't`.
BE_HAVE = frozenset("be been being am is are was were have has had having".split())

# What can stand between the start of a sentence and an imperative: adverbs, an interjection, a leading
# conjunction. A subject cannot: an imperative has none.
PRE_IMPERATIVE = frozenset(("RB", "RBR", "RBS", "UH", "CC"))

# An imperative the tagger missed. The perceptron has seen few imperatives: a sentence's first word comes
# back a proper noun for its capital, and in lower case an adjective or a noun ("live simply" JJ, "record
# the year" NN), so "Live like a Spartan" fell to the adjective lˈaɪv. What a tag cannot say, the clause can
# (`_imperative`).
# The tags a bare verb is mistaken for; never a plural or a marked form, which no imperative is.
BARE_GUESSES = frozenset(("NN", "NNP", "JJ", "RB", "VB", "VBP"))
# ...and what may follow a first word that is a modifier rather than a verb: what it modifies ("Live music",
# "Close friends").
MODIFIED = frozenset(("NN", "NNS", "NNP", "NNPS", "JJ", "JJS", "CD", "POS", "VBG"))

# A word directly after one of these is a noun or an adjective; position beats the tag (the tagger called
# `object` a verb in "the most legible object a person ever makes").
NOUN_POSITION = frozenset(("DT", "JJ", "JJR", "JJS", "PRP$", "POS", "PDT"))

# Where a leftward scan stops: a coordination or any punctuation, past which the words belong to another
# clause ("I will go and read" must not find `will`, because the conjunct it governs is `go`).
CLAUSE_BREAK = frozenset(("CC", ",", ":", ".", "``", "''"))

# How far back a licenser may sit: three words covers "Can you read this?" and "would he not read" without
# reaching into an unrelated clause.
LICENSER_REACH = 3

# The narrative prior decays per sentence (about 6 sentences of memory), so a chapter that changes tense
# follows within a few sentences.
NARRATIVE_DECAY = 0.85
# How lopsided the count has to be before the prior may decide. It is the weakest evidence here and speaks
# only when nothing else can.
NARRATIVE_MARGIN = 1.5

# Stress is not a reading, but where the stress sits is:
#
#   `above`  əbˈʌv alone, əbˌʌv in "the above thing"   - level, not a homograph
#   `I`      ˈaɪ alone,   aɪ mid-frame                 - a mark appearing, not a reading
#   `object` ˈɑːbdʒɛkt vs ɑːbdʒˈɛkt                    - the noun/verb distinction
#
# So level the marks, compare the bare segments and where the marks are, but treat "no mark at all" as
# matching any position.
_LEVEL = str.maketrans({"ˌ": "ˈ"})
_MARK = "ˈ"


def _enclitic_aux(word: str) -> bool:
    """`I've`, `they'd`, `we're`, `I'm`: a subject with BE or HAVE fused onto it.

    ghost keeps the contraction as one token (the karaoke line shows the source spelling) and this tagger
    reads `I've` as a proper noun, so the auxiliary would go unseen. A suffix test, since these four
    enclitics are the contracted forms of be and have.

    `'s` is absent: it is also the possessive ("the man's read on the situation" is a noun).
    """
    return word.endswith(("'ve", "'d", "'re", "'m"))


def _clitic(word: str) -> tuple:
    """`word` split where the treebank splits it: (head, clitic) - "let's" ("let", "'s"), "don't" ("do",
    "n't"), "can't" ("ca", "n't"), "I've" ("I", "'ve") - or (word, "") for none. English's clitics by
    suffix, as `_enclitic_aux`'s are, but `'d` is HAD or WOULD and the tagger, split, calls it a modal.
    Whole, `_enclitic_aux` reads it as the auxiliary it most often is."""
    w = word.replace("\u2019", "'")
    if len(w) > 3 and w.lower().endswith("n't"):
        return w[:-3], w[-3:]
    for c in ("'s", "'re", "'ve", "'ll", "'m"):
        if len(w) > len(c) and w.lower().endswith(c):
            return w[: -len(c)], w[-len(c):]
    return word, ""


def _tense_at(tags: list, lower: list, j: int) -> str:
    """ "past", "present" or "" for the verb at `j`: a participle's tense read off its auxiliary.

    "are issued" is present and "was issued" is past, and the participle is VBN in both, so VBN cannot be
    taken at face value. The tense of a periphrastic verb sits on its auxiliary; rules 6 and 7 consult this
    rather than reading tags directly.

    A bare VBN with no auxiliary in front of it ("the letter read aloud in court") is a reduced relative,
    and past.
    """
    tag = tags[j]
    if tag in ("VBN", "VBG") and j and lower[j - 1] in BE_HAVE:
        return _tense_at(tags, lower, j - 1)  # the auxiliary carries the tense
    if tag in PAST_TAGS:
        return "past"
    if tag == "VBZ" or (tag == "VBP" and lower[j] in BE_HAVE):
        return "present"
    return ""


def _imperative(tags: list, lower: list) -> bool:
    """Is a sentence's first word its clause's verb (an imperative), by the clause alone?

    It must have something after it that is not what a modifier modifies (a preposition, determiner or
    adverb: "Live like a Spartan", "Record the year", "Live simply", never "Live music played"); its clause,
    to the first break, must hold no other verb; and the clause must end the sentence or hand over to a
    coordinator or adverb rather than a new subject ("Close to midnight, the bells rang" is a fronted
    phrase). A word alone before a break ("Refuse, not cannot") is left to the later rules. A noun the
    following preposition repeats ("Project after project", "day after day") is a noun again and again, not
    a verb with itself as object. An adverb right after the first word counts only where it ends the clause.
    """
    n = len(tags)
    if n < 2 or tags[1] in CLAUSE_BREAK or tags[1] in MODIFIED:
        return False
    if tags[1] == "IN" and n > 2 and lower[2] == lower[0]:
        return False
    # an adverb after it only where the adverb ends the clause ("Live simply."): before more, "Present only
    # as an absence" (a fragment) and "Live only for today" (a verb) are tagged alike
    if tags[1] in ("RB", "RBR", "RBS") and n > 2 and tags[2] not in CLAUSE_BREAK:
        return False
    b = 1
    while b < n and tags[b] not in CLAUSE_BREAK:
        if tags[b] in VERB_TAGS or tags[b] == "MD":
            return False
        b += 1
    if b >= n or tags[b] in (".", "CC"):
        return True
    after = b + 1
    while after < n and tags[after] in CLAUSE_BREAK and tags[after] != "CC":
        after += 1
    return after >= n or tags[after] in ("CC", "IN", "RB", "WRB", "TO")


def _shape(s: str) -> tuple:
    """(segments, stress positions) for a reading, with levels collapsed."""
    segs: list = []
    at: list = []
    for ch in s.translate(_LEVEL):
        if ch == _MARK:
            at.append(len(segs))
        else:
            segs.append(ch)
    return "".join(segs), tuple(at)


def _same_reading(a: str, b: str) -> bool:
    sa, pa = _shape(a)
    sb, pb = _shape(b)
    if sa != sb:
        return False
    return not pa or not pb or pa == pb


def _report(name: str, finished: bool = False) -> None:
    """Tell ghost a download is under way, when running inside the voice host."""
    try:
        from backends import report
    except ImportError:  # the command-line audit, outside the host
        return
    report(name, finished=finished)


class _Corpus:
    """nltk's tagger and stopword list, loaded on demand and never twice.

    Both are data, not code, and nltk does not ship either in the wheel: about 6 MB downloaded on first use.
    This download is allowed to fail: `tag` and `stop` end up filled in or the whole pass is off, and off
    means the reading is unchanged.

    They are fetched together and fail together: without the stopword list the participle rule rewrites `a`,
    `to`, `in` and `I` wherever one follows a `was`.
    """

    tag = None  # callable(list[str]) -> [(word, penn)]
    stop: frozenset = frozenset()
    _tried = False

    # nltk renamed its English tagger between 3.8 and 3.9; ask for both and take whichever the installed
    # version can find.
    RESOURCES = (
        "averaged_perceptron_tagger_eng",
        "averaged_perceptron_tagger",
        "stopwords",
    )

    @classmethod
    def ready(cls) -> bool:
        if cls._tried:
            return cls.tag is not None
        cls._tried = True
        try:
            import nltk
            from nltk.corpus import stopwords
        except ImportError:
            print(
                "ghost/voice: nltk is not installed; homograph readings will "
                "use eSpeak's default for every part of speech",
                file=sys.stderr,
            )
            return False
        # Keep the corpora inside the venv ghost owns, so removing user://voice_venv removes all of it.
        store = Path(sys.prefix) / "nltk_data"
        if str(store) not in nltk.data.path:
            nltk.data.path.insert(0, str(store))
        for attempt in (0, 1):
            try:
                nltk.pos_tag(["read"])
                words = frozenset(stopwords.words("english"))
                if not words:
                    raise LookupError("empty stopword list")
                cls.tag, cls.stop = nltk.pos_tag, words
                return True
            except LookupError:
                if attempt:
                    break
                print(
                    "ghost/voice: downloading the nltk tagger and stopword list "
                    "(once) so homographs can be read in context…",
                    file=sys.stderr,
                )
                store.mkdir(parents=True, exist_ok=True)
                _report("the part-of-speech tagger")
                for name in cls.RESOURCES:
                    try:
                        nltk.download(name, download_dir=str(store), quiet=True)
                    except Exception:  # noqa: BLE001 - offline is not fatal here
                        pass
                _report("the part-of-speech tagger", finished=True)
            except Exception as exc:  # noqa: BLE001
                print(f"ghost/voice: nltk unavailable ({exc})", file=sys.stderr)
                break
        print(
            "ghost/voice: no nltk data; homograph readings will use eSpeak's "
            "default for every part of speech",
            file=sys.stderr,
        )
        return False

    @classmethod
    def closed_class(cls, word: str) -> bool:
        """Is this one of English's function words?

        nltk's stopword corpus: determiners, pronouns, prepositions, conjunctions, particles, the
        auxiliaries and their negated contractions, with none of the homographs in it.
        """
        return word in cls.stop


class Homographs:
    """One per backend instance; the probe cache is what makes it worth keeping.

    `speak(utterances, lang)` is the backend's own word-level phonemizer, the same call the main path uses,
    so a carrier reading and a bare reading are comparable.
    """

    def __init__(self, speak) -> None:
        self._speak = speak
        # (lang, text) -> {family or "" : ipa}. A chapter re-uses its vocabulary
        # heavily, so this settles within the first few sentences.
        self._cache: dict[tuple[str, str], dict[str, str]] = {}
        # Decayed counts of tensed verbs seen so far: the narrative prior. One instance lives for the whole
        # session and sentences arrive in reading order.
        self._past = 0.0
        self._present = 0.0
        # Set by `_family` for the audit output; not used by the reading itself.
        self.last_reasons: list[tuple[str, str, str]] = []

    # -- public ------------------------------------------------------------

    def annotate(self, tokens: list, lang: str) -> int:
        """Set `ipa` on every token whose part of speech changes its reading.

        Mutates `tokens` in place and returns how many were rewritten. Tokens are
        one sentence - the unit the tagger needs and the unit `_synth_tokens`
        already groups by.
        """
        if not _Corpus.ready():
            return 0
        words, owner = self._tagger_input(tokens)
        if not words:
            return 0
        try:
            tagged = _Corpus.tag(words)
        except Exception as exc:  # noqa: BLE001 - a tagger fault must not lose audio
            print(f"ghost/voice: tagging failed ({exc})", file=sys.stderr)
            _Corpus.tag = None
            return 0

        tags = [p for _w, p in tagged]
        lower = [w.lower() for w in words]
        # Before resolving anything: this sentence's own tensed verbs are part of the narrative the next
        # sentence is read against, and of the one this sentence is read against too ("I stood ... and read"
        # is settled by its own `stood`).
        self._observe(tags)

        self.last_reasons = []
        wants: list[tuple[int, str, bool]] = []
        for wi in range(len(tagged)):
            ti = owner[wi]
            if ti < 0:
                continue
            fam, why = self._family(lower, tags, wi, words[wi])
            if fam is not None:
                wants.append((ti, fam, tags[wi] in VERB_TAGS))
                self.last_reasons.append((words[wi], fam, why))
        if not wants:
            return 0

        self._fill(
            lang, [(str(tokens[ti].get("text", "")), fam) for ti, fam, _v in wants]
        )

        changed = 0
        for ti, fam, verbal in wants:
            tok = tokens[ti]
            got = self._reading(lang, str(tok.get("text", "")), fam, verbal)
            if got:
                tok["ipa"] = got
                changed += 1
        return changed

    # -- the tense pass ----------------------------------------------------

    def _observe(self, tags: list) -> None:
        """Fold one sentence's tensed verbs into the narrative prior."""
        self._past *= NARRATIVE_DECAY
        self._present *= NARRATIVE_DECAY
        for t in tags:
            if t in PAST_TAGS:
                self._past += 1.0
            elif t in PRESENT_TAGS:
                self._present += 1.0

    def _narrative(self) -> str:
        """ "past", "present" or "" - what tense the prose has been written in."""
        if self._past > self._present * NARRATIVE_MARGIN + 0.5:
            return "past"
        if self._present > self._past * NARRATIVE_MARGIN + 0.5:
            return "present"
        return ""

    def _family(self, lower: list, tags: list, wi: int, word: str = "") -> tuple:
        """Which carrier this word wants, and the rule that decided it."""
        fam, why = self._decide(lower, tags, wi, word or lower[wi])
        # A word already spelled in the past has no use for the past frame: eSpeak reads "they have resented
        # them" as ɹiːsˈɛntᵻd (re-sented) where the word alone is correctly ɹᵻzˈɛntᵻd. The frame is for
        # verbs whose past is spelled like their present (`read`, `wound`, `cut`, `set`); a regular -ed form
        # keeps the base frame.
        if fam == "VBD" and lower[wi].endswith("ed"):
            return "VB", why + ", already -ed"
        return fam, why

    def _decide(self, lower: list, tags: list, wi: int, word: str) -> tuple:
        """The rule that picks a family, and its name.

        Returns (family or None, reason). The order below is the priority order, strongest evidence first,
        and every rule is about grammar rather than any particular word.
        """
        penn = tags[wi]
        fam = FAMILY.get(penn)
        if _Corpus.closed_class(lower[wi]):
            return None, "closed class"

        # Capitals are not a part of speech. The perceptron reads a capital as a proper noun, so the first
        # word of any sentence and anything in full caps comes back NNP ("Refuse not, cannot"). Left alone,
        # unless its clause says it is the verb (`_imperative`).
        if wi == 0 and penn in BARE_GUESSES and _imperative(tags, lower):
            return "VB", "the clause's verb: no subject, and nothing else in it a verb"
        if penn in ("NNP", "NNPS") and (wi == 0 or word.isupper()):
            return None, "capitalized by position, not a proper noun"

        # 1. A participle the tagger called something else: "were read aloud" comes back JJ and "was wound
        # tight" NN; the auxiliary in front says both are participles.
        #    Not guarded by the tag: the tagger calls `wound` a preposition in "he had wound the clock".
        # What keeps
        #    "it was a refund" and "I was in the room" out is the closed-class check above (nltk's stopwords).
        #    Adverbs and negation do not break the auxiliary's grip ("is not read", "have never read", "had
        # already read"); a subject or an object in between means the auxiliary governs something else.
        for back in range(1, LICENSER_REACH + 1):
            j = wi - back
            if j < 0:
                break
            if lower[j] in BE_HAVE or _enclitic_aux(lower[j]):
                return "VBD", "after auxiliary %r" % lower[j]
            if tags[j] not in ("RB", "RBR", "RBS"):
                break

        # 2. Position beats a verb tag for a word sitting where no verb can sit. Only a verb tag: a
        # determiner after a determiner ("half a breath", "all that winter") is still a determiner.
        if wi and tags[wi - 1] in NOUN_POSITION and penn in VERB_TAGS:
            return "NN", "after %s %r, a noun slot" % (tags[wi - 1], lower[wi - 1])

        # 3. An imperative has no subject, and that outranks the tag (the tagger calls a sentence-opening
        # "Read from the near face" a participle). Verbs only: a sentence-initial noun is just a noun.
        if penn in VERB_TAGS and all(tags[j] in PRE_IMPERATIVE for j in range(wi)):
            return "VB", "no subject before it, imperative"

        # 3a. A verb joined on with no subject of its own takes its first conjunct's form. Right after a
        # coordinator (adverbs between), nothing but the verb before it shares that verb's subject and form:
        # "let's take their words, and turn each one over, and read the side" is a run of commands, `read`
        # as bare as `turn`. The nearest verb before the coordinator is that conjunct's: bare is bare, a
        # participle or a past is past, a present is present. An unmarked VBP is no evidence and leaves it
        # to the later rules. Never an -ed form, which its spelling marks.
        if penn in VERB_TAGS and not lower[wi].endswith("ed"):
            j = wi - 1
            while j >= 0 and tags[j] in ("RB", "RBR", "RBS"):
                j -= 1
            if j >= 0 and tags[j] == "CC":
                for k in range(j - 1, -1, -1):
                    if tags[k] in (".", ":", "``", "''"):
                        break
                    if tags[k] == "MD":
                        return "VB", "joined to a verb under modal %r" % lower[k]
                    if tags[k] not in VERB_TAGS:
                        continue
                    if tags[k] == "VB":
                        return "VB", "joined to bare %r" % lower[k]
                    if tags[k] in PAST_TAGS:
                        return "VBD", "joined to %s %r" % (tags[k], lower[k])
                    if _tense_at(tags, lower, k) == "present":
                        return FAMILY["VBP"], "joined to present %r" % lower[k]
                    break

        # 3b. Coordination agrees in tense, and that outranks a past tag on a verb whose past is spelled
        # like its present: VBD on `read`, `cut`, `set` or `wound` is the tagger guessing from context, and
        # a coordinated present clause is that same context saying otherwise (rule 4 believes a marked tag,
        # right when the spelling marks it).
        #     The guard: across exactly one coordinator (rule 7's reach), so a complement clause cannot
        # qualify ("I know he read it"); nothing past in between ("he stood up and read the letter"); never
        # an -ed form. A finite clause has a subject, and requiring one immediately before the verb keeps
        # this off reduced passives (", read out of him by the only unit"): a comma is not a subject, a
        # pronoun or a noun is. VBN is excluded because a participle tag names a form, not a tense the
        # tagger guessed at.
        subject_before = wi > 0 and tags[wi - 1] in (
            "PRP",
            "NN",
            "NNS",
            "NNP",
            "NNPS",
            "EX",
            "WDT",
            "WP",
        )
        if penn == "VBD" and subject_before and not lower[wi].endswith("ed"):
            crossed = False
            for j in range(wi - 1, -1, -1):
                if tags[j] == "CC":
                    if crossed:
                        break
                    crossed = True
                    continue
                if tags[j] in (".", ":", "``", "''"):
                    break
                if not crossed:
                    continue
                t = _tense_at(tags, lower, j)
                if t == "past":
                    break
                if t == "present":
                    return FAMILY["VBP"], "coordinated with present %r" % lower[j]

        # 4. The tag is real evidence (a past form, a participle, a third-person present, a noun, an
        # adjective). Believe it.
        if penn not in UNMARKED_TAGS:
            return fam, "tagged %s" % penn

        # From here the tag is VB or VBP, which for an invariant verb means the tagger found nothing, not
        # that the word is present tense.

        # 5. A modal, `do` or infinitival `to` forces the bare form outright.
        for back in range(1, LICENSER_REACH + 1):
            j = wi - back
            if j < 0 or tags[j] in CLAUSE_BREAK:
                break
            if tags[j] in ("MD", "TO"):
                return "VB", "bare form after %s %r" % (tags[j], lower[j])
            # ...and DO, plus every negated modal the tagger hands back as a plain verb rather than MD
            # (`cannot`, `can't`, `won't`, `doesn't` come back VBZ). A closed-class word tagged as a verb is
            # an auxiliary; the two whose complement is a participle are named above and every other one
            # takes the bare form.
            if _Corpus.closed_class(lower[j]) and tags[j] in VERB_TAGS:
                return "VB", "bare form after %s %r" % (tags[j], lower[j])

        # 6. The nearest preceding finite verb. Conjuncts share a tense ("I stood ... and read") and a
        # complement clause inherits its matrix clause's ("I'd forgotten I read it"): one scan.
        for j in range(wi - 1, -1, -1):
            t = _tense_at(tags, lower, j)
            if t == "past":
                return "VBD", "follows %s %r" % (tags[j], lower[j])
            if t == "present":
                return fam, "follows %s %r" % (tags[j], lower[j])

        # 7. ...or the first conjunct's tense, taken from the second: "We read it and left." Only across a
        # coordinator, so an unrelated later clause cannot reach back.
        crossed = False
        for j in range(wi + 1, len(tags)):
            if tags[j] in CLAUSE_BREAK:
                crossed = True
                continue
            if not crossed:
                continue
            t = _tense_at(tags, lower, j)
            if t == "past":
                return "VBD", "conjoined with %s %r" % (tags[j], lower[j])
            if t == "present":
                return fam, "conjoined with %s %r" % (tags[j], lower[j])

        # 8. Nothing in the clause at all: fall back to the tense the prose is written in. The weakest
        # evidence, and wrong where no grammar helps: a habitual present inside a past-tense chapter
        # ("sometimes I read the paper") comes out past. The audit below prints every decision that rested
        # on this rule.
        if self._narrative() == "past":
            return "VBD", "past-tense narrative (%.1f past / %.1f present)" % (
                self._past,
                self._present,
            )
        return fam, "no evidence, left as %s" % penn

    # -- internals ---------------------------------------------------------

    def _tagger_input(self, tokens: list) -> tuple[list[str], list[int]]:
        """The sentence as the tagger wants it, and which token each word is.

        Punctuation goes in as its own item (a strong feature for the tagger) and maps to token -1: context
        only, never rewritten.
        """
        words: list[str] = []
        owner: list[int] = []
        for ti, tok in enumerate(tokens):
            # As the page has it: ghost sends each word lower-cased for the phoneme lookup and its source
            # spelling as `cased`, and the tagger reads grammar off capitals (lower-cased, "i live in hell"
            # tags `i` an adjective and `live` is read as the adjective).
            text = str(tok.get("cased") or tok.get("text", "")).strip()
            if text:
                # As the tagger learned it: a contraction is two words in the treebank ("Let 's", "do n't"),
                # and whole it is a word the tagger never saw ("Let's" came back NNP, its verb a name).
                # Split for tagging only; a contraction is context either way (it is not all letters), so
                # nothing it holds is rewritten.
                head, clitic = _clitic(text)
                if clitic:
                    words.extend((head, clitic))
                    owner.extend((-1, -1))
                else:
                    words.append(text)
                    # An authored [R EH1 D] arrives with `arpa` and outranks this whole file; a hyphenated
                    # token is two words to eSpeak and has no single slot in a carrier. Both stay as
                    # context.
                    owner.append(ti if (not tok.get("arpa") and text.isalpha()) else -1)
            punct = str(tok.get("punct", "")).strip()
            if punct:
                words.append(punct)
                owner.append(-1)
        return words, owner

    def _fill(self, lang: str, wanted: list[tuple[str, str]]) -> None:
        """Phonemize every probe not already cached, in one batch.

        One call per sentence rather than per word is less to go wrong in the alignment checks below (eSpeak
        itself is fast: 400 carrier utterances take 0.03 s).

        A claim is only permanent if the answer arrives. The cache entry is written before the call so a
        word repeated inside one sentence is probed once, so both whole-batch failures below release what
        this call claimed and the next sentence asks again; a per-probe shape mismatch is deterministic and
        still sticks.
        """
        utts: list[str] = []
        slots: list[tuple[str, str, int, int]] = []  # text, family, slot, expected
        claimed: list[tuple[str, str]] = []  # (text, family) written by THIS call
        for text, fam in wanted:
            entry = self._cache.setdefault((lang, text), {})
            if "" not in entry:
                entry[""] = ""  # claimed, so a repeated word is probed once
                claimed.append((text, ""))
                utts.append(text)
                slots.append((text, "", 0, 1))
            if fam not in entry:
                entry[fam] = ""
                claimed.append((text, fam))
                frame, at, count = CARRIERS[fam]
                utts.append(frame.format(text))
                slots.append((text, fam, at, count))
            # A past-tagged noun/verb pair still wants the verb reading ("the ledgers record no discrepancy"
            # is ɹᵻkˈɔːɹd whether the tagger said VBD or VBP). The base frame is fetched alongside so the
            # fallback in `_reading` costs no second round trip.
            if fam == "VBD" and "VB" not in entry:
                entry["VB"] = ""
                claimed.append((text, "VB"))
                frame, at, count = CARRIERS["VB"]
                utts.append(frame.format(text))
                slots.append((text, "VB", at, count))
        if not utts:
            return

        def _release() -> None:
            for text, fam in claimed:
                self._cache.get((lang, text), {}).pop(fam, None)

        try:
            spoken = self._speak(utts, lang)
        except Exception as exc:  # noqa: BLE001
            print(f"ghost/voice: homograph probe failed ({exc})", file=sys.stderr)
            _release()
            return
        if len(spoken) != len(utts):
            # phonemizer drops inputs it does not like, and a short batch cannot
            # be realigned - the same failure `_symbols` guards against.
            print(
                "ghost/voice: homograph probe returned %d of %d; skipping this "
                "sentence" % (len(spoken), len(utts)),
                file=sys.stderr,
            )
            _release()
            return
        for (text, fam, at, count), out in zip(slots, spoken):
            parts = str(out).strip().split()
            # eSpeak welds function words together at times. If the frame did not come back with the shape
            # sent, the slot is not where we think it is: nothing is recorded and the word keeps its
            # reading.
            if len(parts) == count:
                self._cache[(lang, text)][fam] = parts[at]

    def _reading(self, lang: str, text: str, fam: str, verbal: bool) -> str:
        entry = self._cache.get((lang, text), {})
        bare = entry.get("", "")
        got = entry.get(fam, "")
        # A noun/verb pair still wants the verb reading when it is tagged past ("the ledgers record no
        # discrepancy" is ɹᵻkˈɔːɹd): eSpeak's past frame answers with the noun for a word whose past is not
        # its bare form, so a VBD that changes nothing falls through to the base verb frame.
        # `verbal` gates it: the auxiliary rule promotes nouns to VBD too ("was wound tight"), and without
        # the gate "it was record heat" would take the verb frame. A word the tagger never called a verb
        # takes the past frame's answer or nothing.
        if verbal and fam == "VBD" and (not got or _same_reading(got, bare)):
            got = entry.get("VB", "")
        if not got or not bare or _same_reading(got, bare):
            return ""
        return got


# -- audit -----------------------------------------------------------------


def _audit(paths: list) -> int:
    """Print every reading this pass would change in a script, and why.

    `tests/voice/pronounce_audit.gd` answers "which words in this chapter are uncertain"; this answers "what
    did the machine decide about them". Sentences are fed in reading order so the narrative prior builds as
    in a real reading; auditing one sentence out of context will not reproduce it.

        <venv>/bin/python hosts/voice/homographs.py chapters/12-*.md
    """
    import re

    from backends.piper import PiperBackend  # noqa: F401 - registers/loads espeak

    speak = PiperBackend._espeak
    hg = Homographs(speak)
    total = 0
    for path in paths:
        text = Path(path).read_text(encoding="utf8", errors="replace")
        print(f"\n=== {path}")
        for raw in re.split(r"(?<=[.!?])\s+", text):
            line = " ".join(raw.split())
            if not line:
                continue
            toks = []
            for word in line.split():
                punct = ""
                while word and word[-1] in ".,;:!?\"'":
                    punct = word[-1] + punct
                    word = word[:-1]
                word = word.lstrip("\"'([")
                if word:
                    toks.append({"text": word, "punct": punct[:1]})
            if not toks:
                continue
            hg.annotate(toks, "en-us")
            for i, tok in enumerate(toks):
                if not tok.get("ipa"):
                    continue
                total += 1
                why = ""
                for word, _fam, reason in hg.last_reasons:
                    if word == tok["text"]:
                        why = reason
                        break
                print(f"  {tok['text']:<12} -> {tok['ipa']:<14} {why}")
                print(
                    f"      {' '.join(t['text'] for t in toks[max(0, i - 7): i + 6])}"
                )
    print(f"\n{total} reading(s) changed")
    return 0


if __name__ == "__main__":
    sys.path.insert(0, str(Path(__file__).resolve().parent))
    raise SystemExit(_audit(sys.argv[1:]))
