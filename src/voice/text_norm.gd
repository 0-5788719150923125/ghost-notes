extends RefCounted
class_name TextNorm

## TextNorm - turn written English into speakable words, before anything else.
##
## A deterministic text transform with no opinion about voice, required by any backend: fold characters
## first (typographic quotes, dashes and the ellipsis to ASCII, so dictionary lookup does not miss),
## then expand numbers (a purely numeric token would otherwise yield an empty phone array in
## [Phonemes.word_to_phones] and vanish from the audio and the subtitles), then hand clean ASCII to the
## tokenizer. See next/voice_intelligibility.md.

# --- character folding ------------------------------------------------------
# Typographic punctuation folded to the ASCII the rest of the front end understands. The dashes become
# a comma: an em dash is a break, not a word.
const FOLD := {
	"‘": "'", "’": "'", "‚": ",", "‛": "'",   # single quotes
	"“": "\"", "”": "\"", "„": "\"", "‟": "\"", # double quotes
	"′": "'", "″": "\"",                                 # primes
	"‐": "-", "‑": "-", "‒": "-", "–": "-",     # hyphens/en dash
	"—": ",", "―": ",",                                  # em dash = a break
	"…": ",",                                                 # ellipsis = a break
	" ": " ", " ": " ", " ": " ", " ": " ",     # exotic spaces
	"­": "",                                                  # soft hyphen
	"×": " times ", "÷": " divided by ",
	"½": " one half ", "¼": " one quarter ", "¾": " three quarters ",
	"°": " degrees ", "™": "", "®": "", "©": "",
}

# --- emphasis sentinels ------------------------------------------------------
#
# Markdown's emphasis markers are typography: the mouth must not speak them and the page must not lose
# them. A matched pair becomes a sentinel, a private-use character that survives every pass below (it is
# in no fold table and is not whitespace, so it stays welded to its word) and is peeled off by
# [Phonemes.parse], which records the level on the word for the subtitle renderer. They toggle, so a run
# spanning several words needs only its two ends marked.
#
# Nothing downstream of the phonemizer sees one: [method normalize] strips them on the way out; only
# [method normalize_marked] keeps them, and it has one caller.
const EMPH_ITALIC := "\uE001"
const EMPH_BOLD := "\uE002"
const EMPH_MARKS := EMPH_ITALIC + EMPH_BOLD
## A hesitation: a longer rest the author asked for (`<!-- hesitation -->`). The Generative panel welds
## one to the word it follows (or leads, when nothing comes before it), and it rides the pipeline as the
## emphasis sentinels do: [Phonemes.parse] peels it into `hold` / `hold_before` on the word, and the
## panel splices the silence into the take there.
const HOLD_MARK := "\uE003"
## Every sentinel, for the passes that treat one as a wrapper (like a quote) rather than part of the word.
const SENTINELS := EMPH_ITALIC + EMPH_BOLD + HOLD_MARK
## Level bits carried on a word: 1 italic, 2 bold, 3 both.
const EMPH_I := 1
const EMPH_B := 2

# Markdown's own flanking rule, shared by every marker character.
const OPEN_BEFORE := " \t\n([{\"'\u201c\u2018"
const SPACE := " \t\n"
const CLOSE_AFTER := " \t\n.,;:!?)]}\"'\u201d\u2019"

# --- number words -----------------------------------------------------------
const ONES := ["zero", "one", "two", "three", "four", "five", "six", "seven",
	"eight", "nine", "ten", "eleven", "twelve", "thirteen", "fourteen",
	"fifteen", "sixteen", "seventeen", "eighteen", "nineteen"]
const TENS := ["", "", "twenty", "thirty", "forty", "fifty", "sixty", "seventy",
	"eighty", "ninety"]
const SCALES := [[1000000000, "billion"], [1000000, "million"], [1000, "thousand"]]
# Ordinals that are not just "<cardinal>th".
const ORDINAL := {
	"one": "first", "two": "second", "three": "third", "five": "fifth",
	"eight": "eighth", "nine": "ninth", "twelve": "twelfth",
}

# Abbreviations whose trailing period is not a sentence boundary. Expanded to their spoken form, which
# also removes the period and the false full stop with it.
const ABBREV := {
	"mr": "mister", "mrs": "missus", "ms": "miz", "dr": "doctor",
	"st": "saint", "mt": "mount", "prof": "professor", "rev": "reverend",
	"jr": "junior", "sr": "senior", "vs": "versus", "etc": "et cetera",
	"approx": "approximately", "dept": "department", "est": "established",
	"fig": "figure", "no": "number", "vol": "volume", "ch": "chapter",
}

## Letter names, for the letter runs inside an alphanumeric token: "H8" reads "aitch eight", "v2" reads
## "vee two". A closed alphabet, not a word list.
##
## Never applied to a word on its own: `a`, `I` and `O` are real English words. Only a single-letter run
## inside a token that also contains a digit is a letter being named - or a letter the script names
## outright, `[a]` ([method _expand_core]): "let [a] be two" is the letter, shown as `a`.
## `a` is `eigh` and not `ay` on purpose: asked of eSpeak, `ay` is ˈaɪ (the word "aye") while the letter
## A is ˈeɪ. Every other entry agrees with the letter's own reading.
const LETTER_NAMES := {
	"a": "eigh", "b": "bee", "c": "see", "d": "dee", "e": "ee", "f": "ef", "g": "gee",
	"h": "aitch", "i": "eye", "j": "jay", "k": "kay", "l": "el", "m": "em", "n": "en",
	"o": "oh", "p": "pee", "q": "cue", "r": "ar", "s": "ess", "t": "tee", "u": "you",
	"v": "vee", "w": "double you", "x": "ex", "y": "why", "z": "zee",
}


## Initialisms eSpeak gets wrong, respelled so they are said the way they are read.
##
## The phonemes are right and the durations are not: en_US-libritts-high reads a short token as a fast
## function word, so `IT` as ˌaɪtˈiː lasts 0.21 s (a blip) where `eye tee` lasts 0.59 s, and `CIA` 0.46 s
## against `see eye eigh` 0.73 s. Giving each letter its own word gives the duration predictor a word to
## time. So these are spelled out for pacing, and the respellings must phonemize to the letter's own
## reading (`eigh`, not `ay`; the gate checks it against eSpeak).
##
## Matched on the exact spelling, case and all: `IT` is the field and `it` the pronoun; `eSIM` and
## `esim` differ to eSpeak. A sentence set entirely in capitals is the one reading this gets wrong; an
## inline `[IH1 T]` overrides it.
##
## Kept short and hand-written: it is a property of the voice, not of English. It is not a general
## abbreviation dictionary and must not grow into one: what a rule can settle belongs in a rule, a
## one-off belongs inline in the script as `[IY1 S IH1 M]`, and anything already correct belongs nowhere.
const INITIALISMS := {
	"CIA": "see eye eigh",
	"eSIM": "ee sim",
	"IT": "eye tee",
}


## Abbreviations that are also ordinary English words, and so need evidence before being treated as
## abbreviations. See [method _abbrev_fits].
##   NEEDS_NUMBER - a reference mark, followed by the number it refers to
##   NEEDS_NAME   - a title, followed by the name it titles
const NEEDS_NUMBER := ["no", "fig", "vol", "ch"]
const NEEDS_NAME := ["mr", "mrs", "ms", "dr", "st", "mt", "prof", "rev", "sr", "jr"]

const CURRENCY := {"$": "dollars", "£": "pounds", "€": "euros", "¥": "yen"}

## Template macros and their defaults.
##
##     ${CHAPTERS_BEFORE_IN_WORDS:25}   ->  25
##     ${TITLE:Charlotte's Web of Lies} ->  Charlotte's Web of Lies
##     ${WORD_COUNT_IN_WORDS}           ->  (nothing, and a warning)
##
## A manuscript can carry facts about itself that only its build knows (chapters before this one, the
## finished word count); the source writes the placeholder and the build resolves it (rift's
## `build.py`). Ghost is handed one chapter with no book around it, so it reads the default: the value
## to read when the resolver is absent. It never works out the real figure.
##
## The macro text is never spoken, so this runs at the very top of [method normalize]: a macro is one
## whitespace-delimited token and every later pass would treat it as a word.
##
## A default may be any length, including paragraphs with blank lines. So this is a scanner, not a
## regex: depth counting takes the value to its matching brace (`${Q:the set {a, b}}`).
const NAME_HEAD := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_"
## A letter named in brackets, `[a]`, as a reader is shown it: the letter.
static var _NAMED_LETTER := RegEx.create_from_string("\\[([A-Za-z])\\]")
const NAME_TAIL := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ_0123456789."


## The entry point. Strip markup, fold, expand, and hand back plain ASCII words.
##
## Abbreviations are resolved before numerals: the ones that are also ordinary words (`no` above all)
## are told apart by what follows ("No. 5" is a number, "the answer was no." is not), and that evidence
## is gone once the 5 has become "five".
static func normalize(text: String) -> String:
	# the sentinels are for the one caller that carries emphasis onto the page (see the note above
	# [constant EMPH_ITALIC])
	return strip_emphasis(String(normalize_marked(text)["text"]))


## The same normalization, plus what each rewritten run was written as.
##
## Returns {"text": String, "spans": [{at, len, src}]}: each span covers a run of the returned text that
## does not read the way the source spelled it (`two thousand nine` for `2009`, `five dollars` for `$5`,
## `doctor` for `Dr.`). Runs that were not rewritten get no span.
##
## The voice says the number and the screen shows the numeral, so both spellings must survive the
## pipeline together ([Phonemes.parse] takes its `display` from here). [method normalize] is this
## function with the spans dropped, so the audio and the subtitles cannot disagree about what was said.
static func normalize_marked(text: String) -> Dictionary:
	# Macros first, before markup or folding: a macro's default has to travel the whole pipeline (a
	# default of `25` is heard as "twenty five" because _expand_numbers still sees it). No span is
	# recorded for one: the default is the source as far as a reader is concerned.
	var s := _expand_macros(text)
	s = _strip_markdown(s)
	s = _fold(s)
	var abbrev: Array = []
	s = _expand_abbrev(s, abbrev)
	var spans: Array = []
	s = _expand_numbers(s, abbrev, spans)
	return {"text": s, "spans": spans}


## Remove Markdown's own punctuation, which is typography and must not be spoken, and where it marks
## emphasis replace it with a sentinel rather than deleting it.
##
## eSpeak speaks an emphasis marker as a word ("*I will never hurt you*" -> "ASTERISK I will never hurt
## you ASTERISK"). It drops `_like this_` word by word, but the subtitle is taken from this text, so
## underscore markers must go too. Deleting a pair would leave the subtitle flat, so a matched pair
## becomes [constant EMPH_ITALIC] / [constant EMPH_BOLD], which [Phonemes.parse] peels into a level on
## the word and the overlay draws slanted or emboldened. Everything unmatched is dropped, so the spoken
## text is unchanged either way.
##
## The pairing is markdown's flanking rule: an opener is preceded by whitespace or an opening bracket and
## followed by a non-space, a closer is preceded by a non-space and followed by whitespace or
## punctuation, and both must be present in the same paragraph before either is touched. `snake_case` is
## untouched (neither underscore flanks anything), `_private` alone is untouched (nothing closes it),
## `* item` is not emphasis (a space follows), and a run of underscores is never emphasis, which keeps
## `__init__` whole at the cost of `__bold__`.
static func _strip_markdown(text: String) -> String:
	var marks := _emphasis_marks(text)
	var out := ""
	var at_line_start := true
	var i := 0
	while i < text.length():
		var c := text[i]
		# A MATCHED PAIR: the run is consumed and its sentinel takes its place.
		if marks.has(i):
			var m: Dictionary = marks[i]
			out += String(m["put"])
			i += int(m["len"])
			at_line_start = false
			continue
		if c == "\n":
			at_line_start = true
			out += c
			i += 1
			continue
		# heading hashes and blockquote arrows, only at the head of a line: elsewhere `#` usually means
		# "number" and `>` "greater than"
		if at_line_start and (c == "#" or c == ">"):
			while i < text.length() and (text[i] == "#" or text[i] == ">" or text[i] == " "):
				i += 1
			continue
		if c != " " and c != "\t":
			at_line_start = false
		# unmatched emphasis, strikethrough and inline code: dropped, not folded to a break (they mark a
		# span, not a pause). An underscore that paired nothing is left alone (`snake_case`).
		if c == "*" or c == "`" or c == "~":
			i += 1
			continue
		out += c
		i += 1
	return out


## Strip every sentinel from `text` - emphasis and hesitation alike - for callers who want speakable
## words and nothing else (everyone except [Phonemes.parse]).
static func strip_emphasis(text: String) -> String:
	if not (text.contains(EMPH_ITALIC) or text.contains(EMPH_BOLD) or text.contains(HOLD_MARK)):
		return text
	var out := ""
	for i in text.length():
		var c := text[i]
		if c != EMPH_ITALIC and c != EMPH_BOLD and c != HOLD_MARK:
			out += c
	return out


## Which marker runs in `text` are a matched emphasis pair: `{start index -> {len, put}}`, where `len` is
## the run's length in characters and `put` the sentinel(s) that replace it.
##
## Separate from the strip because it looks forward: a marker is only a marker if its partner exists.
## The open runs are a stack, so nesting works (`**bold with *italic* in it**`), and the sentinels being
## toggles means the words between carry both levels.
##
## Same paragraph only: an unmatched opener must not take every later marker with it, and emphasis does
## not span a blank line in markdown either.
static func _emphasis_marks(text: String) -> Dictionary:
	var marks := {}
	var open: Array = []                 # [{at, run, ch}], innermost last
	var n := text.length()
	var i := 0
	while i < n:
		var c := text[i]
		if c != "*" and c != "_":
			i += 1
			continue
		var run := i
		while run < n and text[run] == c:
			run += 1
		var width := run - i
		# `__` and longer are never emphasis here (see `_strip_markdown`), and `****` is not a level
		if width > 3 or (c == "_" and width != 1):
			i = run
			continue
		var before := text[i - 1] if i > 0 else " "
		var after := text[run] if run < n else " "
		var can_open := OPEN_BEFORE.contains(before) and not SPACE.contains(after)
		var can_close := not SPACE.contains(before) and CLOSE_AFTER.contains(after)
		# a closer wins over opening a new run, and closes the innermost match (else the second `*` of
		# a pair followed by a space reads as another opener)
		if can_close:
			var k := open.size() - 1
			while k >= 0:
				var o: Dictionary = open[k]
				if String(o["ch"]) == c and int(o["run"]) == width \
						and not _blank_line_between(text, int(o["at"]), i):
					var put := _sentinels(width)
					marks[int(o["at"])] = {"len": width, "put": put}
					marks[i] = {"len": width, "put": put}
					open.resize(k)
					break
				k -= 1
			if k >= 0:
				i = run
				continue
		if can_open:
			open.append({"at": i, "run": width, "ch": c})
		i = run
	return marks


## The sentinels a run of `width` markers stands for: 1 italic, 2 bold, 3 both.
static func _sentinels(width: int) -> String:
	match width:
		1: return EMPH_ITALIC
		2: return EMPH_BOLD
		_: return EMPH_ITALIC + EMPH_BOLD


static func _blank_line_between(text: String, a: int, b: int) -> bool:
	var seen := 0
	for i in range(a, b):
		var c := text[i]
		if c == "\n":
			seen += 1
			if seen >= 2:
				return true
		elif c != " " and c != "\t" and c != "\r":
			seen = 0
	return false



## Every `${...}` in `text`, as [{at, end, name, has_default, value, broken}].
##
## One definition, because [method _expand_macros] (what is read) and [method unresolved_macros] (what is
## reported) must agree about what a macro is.
##
## `broken` marks a `${` that never closed, or one whose name is not a name. Those are left in the text
## verbatim, so they are read aloud and reported; swallowing to end of file would delete the rest of a
## chapter.
static func _scan_macros(text: String) -> Array:
	var out: Array = []
	var i := text.find("${")
	while i >= 0:
		var j := i + 2
		while j < text.length() and (text[j] == " " or text[j] == "\t"):
			j += 1
		var n0 := j
		while j < text.length() and (NAME_TAIL if j > n0 else NAME_HEAD).contains(text[j]):
			j += 1
		var name := text.substr(n0, j - n0)
		var k := j
		while k < text.length() and (text[k] == " " or text[k] == "\t"):
			k += 1
		var row := {"at": i, "end": i + 2, "name": name, "has_default": false,
			"value": "", "broken": true}
		if not name.is_empty() and k < text.length() and text[k] == "}":
			row = {"at": i, "end": k + 1, "name": name, "has_default": false,
				"value": "", "broken": false}
		elif not name.is_empty() and k < text.length() and text[k] == ":":
			# to the matching brace: the value is taken verbatim (a word, a paragraph, several with
			# blank lines), and a brace inside it nests rather than ending it
			var depth := 1
			var v0 := k + 1
			var e := v0
			while e < text.length():
				if text[e] == "{":
					depth += 1
				elif text[e] == "}":
					depth -= 1
					if depth == 0:
						break
				e += 1
			if depth == 0:
				row = {"at": i, "end": e + 1, "name": name, "has_default": true,
					"value": text.substr(v0, e - v0), "broken": false}
		out.append(row)
		i = text.find("${", int(row["end"]))
	return out


## How one unusable macro is named to a human, so the log and the panel say the same thing.
static func _macro_label(m: Dictionary) -> String:
	if not bool(m["broken"]):
		return String(m["name"])
	if String(m["name"]).is_empty():
		return "${…} (not a macro name)"
	return "${%s (never closed)" % String(m["name"])


## Replace every `${NAME:default}` with its default.
##
## A macro with no default expands to nothing and warns with its name (reading the placeholder aloud is
## wrong, and deleting it in silence is too). `${NAME:}` is an explicitly empty default and is silent.
static func _expand_macros(text: String) -> String:
	if not text.contains("${"):
		return text                 # the overwhelmingly common case, at no cost
	var out := ""
	var at := 0
	var bad: PackedStringArray = PackedStringArray()
	for row in _scan_macros(text):
		var m: Dictionary = row
		out += text.substr(at, int(m["at"]) - at)
		if bool(m["broken"]):
			out += text.substr(int(m["at"]), int(m["end"]) - int(m["at"]))
			bad.append(_macro_label(m))
		elif bool(m["has_default"]):
			out += String(m["value"])
		else:
			bad.append(_macro_label(m))
		at = int(m["end"])
	out += text.substr(at)
	if not bad.is_empty():
		push_warning("ghost/text: %d template macro(s) will not read as intended: %s - write "
			% [bad.size(), ", ".join(bad)] + "${NAME:value} to say what to read instead")
	return out


## The macros in `text` that will not be read as intended - no default, or malformed. Same scan and rule
## as [method _expand_macros], asked without the answer, so a panel can say so before narration is made.
static func unresolved_macros(text: String) -> PackedStringArray:
	var out: PackedStringArray = PackedStringArray()
	if not text.contains("${"):
		return out
	for row in _scan_macros(text):
		var m: Dictionary = row
		if bool(m["broken"]) or not bool(m["has_default"]):
			out.append(_macro_label(m))
	return out


static func _fold(text: String) -> String:
	var out := ""
	for i in text.length():
		var c := text[i]
		out += String(FOLD[c]) if FOLD.has(c) else c
	return out


## Cardinals under a thousand. The recursive core everything else calls.
static func _under_thousand(n: int) -> String:
	if n < 20:
		return String(ONES[n])
	if n < 100:
		var t: String = TENS[n / 10]
		return t if n % 10 == 0 else t + " " + String(ONES[n % 10])
	var h: String = String(ONES[n / 100]) + " hundred"
	return h if n % 100 == 0 else h + " " + _under_thousand(n % 100)


## Any non-negative integer, spoken the way a reader would say it.
static func cardinal(n: int) -> String:
	if n == 0:
		return "zero"
	var parts: Array = []
	var rest := n
	for pair in SCALES:
		var value: int = pair[0]
		if rest >= value:
			parts.append(_under_thousand(rest / value) + " " + String(pair[1]))
			rest = rest % value
	if rest > 0:
		parts.append(_under_thousand(rest))
	return " ".join(parts)


static func ordinal(n: int) -> String:
	var words := cardinal(n)
	var idx := words.rfind(" ")
	var head := words.substr(0, idx + 1) if idx >= 0 else ""
	var tail := words.substr(idx + 1)
	if ORDINAL.has(tail):
		return head + String(ORDINAL[tail])
	if tail.ends_with("y"):                      # twenty -> twentieth
		return head + tail.substr(0, tail.length() - 1) + "ieth"
	return head + tail + "th"


## A four-digit year reads as two pairs - "nineteen eighty five", not "one thousand nine hundred and
## eighty five". 2000-2009 read as full cardinals.
static func year(n: int) -> String:
	if n < 1100 or n > 2999:
		return cardinal(n)
	var hi := n / 100
	var lo := n % 100
	# the 2000s first, or 2000 reads as "twenty hundred"
	if n >= 2000 and n <= 2009:
		return cardinal(n)
	if lo == 0:
		return cardinal(hi) + " hundred"
	if lo < 10:
		return cardinal(hi) + " oh " + cardinal(lo)
	return cardinal(hi) + " " + cardinal(lo)


static func _is_digits(s: String) -> bool:
	if s.is_empty():
		return false
	for i in s.length():
		if s[i] < "0" or s[i] > "9":
			return false
	return true


## Runs on folded text, so it only ever sees ASCII. Walk the text token by token, replacing anything
## numeric with words.
##
## Splits on all whitespace and puts it back exactly: `_expand_token` peels trailing punctuation from a
## set that does not contain `\n`, so a token split on the space character alone (`"2009.\n"`) would
## keep its numeral, and [method Phonemes.word_to_phones] would drop the word. The whitespace is emitted
## verbatim because it is structure: paragraph breaks reach the sentence splitter, and `\n` is a full
## stop to it.
##
## `marks_in` are the spans [method _expand_abbrev] recorded over this text, and `marks_out` collects the
## spans over the returned text - what this pass rewrites and whatever came in, moved to where it now
## sits. This pass knows both offsets (input cursor and output length at every token boundary), so it
## merges them. The two rewrites cannot overlap: nothing in ABBREV expands to digits.
static func _expand_numbers(text: String, marks_in: Array = [],
		marks_out: Array = []) -> String:
	var out := ""
	var mi := 0                         # next unconsumed incoming mark
	var starts := true                  # is the next token the start of a sentence?
	var i := 0
	var n := text.length()
	while i < n:
		var c := text[i]
		if c == " " or c == "\t" or c == "\n" or c == "\r":
			out += c
			# a line break starts a sentence, so a numeral after one keeps its capital: the tokenizer
			# treats `\n` as a full stop, and the sentence splitter reads a lower-case word after a stop
			# as a continuation
			if c == "\n":
				starts = true
			i += 1
			continue
		var j := i
		while j < n and not (text[j] in " \t\n\r"):
			j += 1
		var tok := text.substr(i, j - i)
		var was := i                    # this token's offset in the INPUT
		i = j
		var done := _expand_token(tok)
		# a numeral opening a sentence keeps its capital ("5 was missing." expands to "Five was
		# missing"): a lower-case word after a full stop is read by the sentence splitter as a
		# continuation (a dialogue tag)
		if starts and done != tok and done.length() > 0:
			done = done.substr(0, 1).to_upper() + done.substr(1)
		# what a reader should see: whatever the source said. An incoming mark means an earlier pass
		# already replaced this token, so its `src` is the original.
		var src := strip_emphasis(tok)     # shown to a reader; see _expand_abbrev
		if src.contains("["):
			src = _NAMED_LETTER.sub(src, "$1", true)   # `[a]` is shown as the letter it names
		var span := done.length()
		var rewritten := done != tok
		while mi < marks_in.size() and int((marks_in[mi] as Dictionary)["at"]) < was:
			mi += 1
		if mi < marks_in.size() and int((marks_in[mi] as Dictionary)["at"]) == was:
			var m: Dictionary = marks_in[mi]
			src = String(m["src"])
			# the mark's length, not this token's: an abbreviation can expand to more than one word
			# (`etc.` -> `et cetera`) and this pass sees only the first of them
			span = int(m["len"])
			rewritten = true
			mi += 1
		if rewritten:
			marks_out.append({"at": out.length(), "len": span, "src": src})
		out += done
		# the next token starts a sentence if this one ended one; closing wrappers are stripped first
		# so `it."` counts
		var tail := tok.rstrip("\"')]" + SENTINELS)
		starts = tail.length() > 0 and tail[tail.length() - 1] in ".!?"
	return out


static func _expand_token(tok: String) -> String:
	# hold trailing punctuation aside so it still reaches the tokenizer
	var tail := ""
	while tok.length() > 0 and tok[tok.length() - 1] in ".,!?;:\"')" + SENTINELS:
		tail = tok[tok.length() - 1] + tail
		tok = tok.substr(0, tok.length() - 1)
	var head := ""
	while tok.length() > 0 and tok[0] in "\"'(" + SENTINELS:
		head += tok[0]
		tok = tok.substr(1)
	if tok.is_empty():
		return head + tail

	var body := _expand_core(tok)
	return head + body + tail


static func _expand_core(tok: String) -> String:
	# a letter named: `[a]` is the letter, said by its name and shown as the letter ([method
	# _expand_numbers] keeps the source). A lone consonant in brackets would be a one-phoneme ARPAbet
	# word, which no script means.
	if tok.length() == 3 and tok[0] == "[" and tok[2] == "]" and LETTER_NAMES.has(tok[1].to_lower()):
		return String(LETTER_NAMES[tok[1].to_lower()])
	# currency: $5, £1.50
	var first := tok.substr(0, 1)
	if CURRENCY.has(first) and tok.length() > 1:
		var amount := _expand_core(tok.substr(1))
		return amount + " " + String(CURRENCY[first])
	# percentages
	if tok.ends_with("%"):
		return _expand_core(tok.substr(0, tok.length() - 1)) + " percent"
	# ordinals written with a suffix: 1st, 22nd, 3rd, 14th
	for suf in ["st", "nd", "rd", "th"]:
		if tok.length() > suf.length() and tok.to_lower().ends_with(suf):
			var digits := tok.substr(0, tok.length() - suf.length())
			if _is_digits(digits):
				return ordinal(int(digits))
	# times: 9:30
	if tok.contains(":"):
		var bits := tok.split(":")
		if bits.size() == 2 and _is_digits(bits[0]) and _is_digits(bits[1]):
			var m := int(bits[1])
			if m == 0:
				return cardinal(int(bits[0])) + " o'clock"
			return cardinal(int(bits[0])) + (" oh " if m < 10 else " ") + cardinal(m)
	# decimals: 3.14 reads digit by digit after the point
	if tok.contains("."):
		var bits2 := tok.split(".")
		if bits2.size() == 2 and _is_digits(bits2[0]) and _is_digits(bits2[1]):
			var frac := ""
			for i in String(bits2[1]).length():
				frac += " " + String(ONES[int(String(bits2[1])[i])])
			return cardinal(int(bits2[0])) + " point" + frac
	# thousands separators: 1,200
	if tok.contains(",") and _is_digits(tok.replace(",", "")):
		return cardinal(int(tok.replace(",", "")))
	# numeric ranges only (1939-1945, 3-4): a hyphen is part of how a compound is spelled ("twenty-five",
	# "self-report") and the karaoke line shows the source spelling, so only a hyphen where a number is
	# involved is split
	if tok.contains("-") and tok.length() > 1:
		var pieces := tok.split("-", false)
		var numeric := false
		for piece in pieces:
			if _is_digits(String(piece)):
				numeric = true
				break
		if numeric:
			var parts: Array = []
			for piece in pieces:
				parts.append(_expand_core(String(piece)))
			return " ".join(parts)
	# bare digits: a plausible year reads as pairs, everything else as a cardinal
	if _is_digits(tok):
		var n := int(tok)
		if tok.length() == 4 and n >= 1100 and n <= 2999:
			return year(n)
		return cardinal(n)
	# letters and digits welded together ("H8", "v2", "3D", "A4"): everything above has had its chance,
	# so what is left is an identifier, read as its parts (a digit run as a number, a lone letter as its
	# name, a real word inside the token left alone). [method Phonemes.word_to_phones] walks letters, so
	# "H8" would otherwise come back as a single phone.
	var has_alpha := false
	var has_digit := false
	for i in tok.length():
		var c := tok[i]
		if c >= "0" and c <= "9":
			has_digit = true
		elif (c >= "a" and c <= "z") or (c >= "A" and c <= "Z"):
			has_alpha = true
	if has_alpha and has_digit:
		var parts: Array = []
		var run := ""
		var run_digit := false
		for i in tok.length():
			var c2 := tok[i]
			var is_d := c2 >= "0" and c2 <= "9"
			if run.is_empty() or is_d == run_digit:
				run += c2
				run_digit = is_d
				continue
			parts.append(_run_words(run, run_digit))
			run = c2
			run_digit = is_d
		if not run.is_empty():
			parts.append(_run_words(run, run_digit))
		return " ".join(parts)
	return tok


## One run of an alphanumeric token: digits as a number, a single letter as its name, anything
## longer as the word it already is.
static func _run_words(run: String, digits: bool) -> String:
	if digits:
		return cardinal(int(run))
	if run.length() == 1 and LETTER_NAMES.has(run.to_lower()):
		return String(LETTER_NAMES[run.to_lower()])
	return run


## Dotted abbreviations, expanded so their period stops being read as the end of a sentence.
## Case-insensitive on the abbreviation, and only when the period is present ("no" the word must not
## become "number"). `marks` collects {at, len, src} over the returned text for every token this
## rewrites, so [method normalize_marked] can tell a reader that `doctor` was written `Dr.`; empty for
## every other caller.
static func _expand_abbrev(text: String, marks: Array = []) -> String:
	var out: Array = []
	var at := 0                       # output offset of the token about to be written
	var words := text.split(" ", false)
	for i in words.size():
		var raw := words[i]
		var tok := String(raw)
		# a wrapper must not hide the abbreviation: matching the whole token, `"Mr.` never equals `mr.`
		# and the sentence would break inside the name. Strip the wrappers, match, put them back.
		var head := ""
		var body := tok
		# the emphasis sentinels count as wrappers here as a quote does: `*Mr. Smith*` must find `mr.`
		while body.length() > 0 and body[0] in "\"'(" + SENTINELS:
			head += body[0]
			body = body.substr(1)
		var tail := ""
		while body.length() > 0 and body[body.length() - 1] in "\"')" + SENTINELS:
			tail = body[body.length() - 1] + tail
			body = body.substr(0, body.length() - 1)
		# initialisms first, against `body` rather than `lower` (the case is the match). Trailing
		# sentence punctuation moves into the tail so `CIA.` finds `CIA`, and a possessive or plural `s`
		# is carried onto the last spoken word.
		var mark := ""
		var stem := body
		while stem.length() > 0 and stem[stem.length() - 1] in ".,;:!?":
			mark = stem[stem.length() - 1] + mark
			stem = stem.substr(0, stem.length() - 1)
		var plural := ""
		if stem.ends_with("'s") and INITIALISMS.has(stem.substr(0, stem.length() - 2)):
			plural = "s"
			stem = stem.substr(0, stem.length() - 2)
		elif stem.length() > 1 and stem.ends_with("s") \
				and INITIALISMS.has(stem.substr(0, stem.length() - 1)):
			plural = "s"
			stem = stem.substr(0, stem.length() - 1)
		if INITIALISMS.has(stem):
			var spoken := head + String(INITIALISMS[stem]) + plural + mark + tail
			marks.append({"at": at, "len": spoken.length(), "src": strip_emphasis(tok)})
			out.append(spoken)
			at += spoken.length() + 1
			continue

		var lower := body.to_lower()
		var matched := false
		for key in ABBREV:
			if lower == key + "." and _abbrev_fits(key, words, i):
				var said := head + String(ABBREV[key]) + tail
				# `src` is what the reader is shown, so the sentinels come off it; they stay in `said`
				marks.append({"at": at, "len": said.length(), "src": strip_emphasis(tok)})
				out.append(said)
				at += said.length() + 1        # the joining space
				matched = true
				break
		if not matched:
			out.append(tok)
			at += tok.length() + 1
	return " ".join(out)


## Is this really the abbreviation, or the ordinary word spelled the same way that happens to end a
## sentence?
##
## A sentence-final "no" always ends in a period, so the period is no evidence. What separates them is
## what comes next:
##   a reference abbreviation is followed by its number  - "No. 5", "fig. 3", "ch. 12"
##   a title is followed by the name it titles           - "Mr. Smith", "St. Paul"
## Everything else in the table ("etc.", "vs.", "approx.") is never an ordinary English word, so it
## needs no evidence and expands unconditionally.
static func _abbrev_fits(key: String, words: PackedStringArray, at: int) -> bool:
	var needs_number := NEEDS_NUMBER.has(key)
	var needs_name := NEEDS_NAME.has(key)
	if not needs_number and not needs_name:
		return true
	if at + 1 >= words.size():
		return false                     # nothing follows: it ended a sentence, so it is the word
	var nxt := String(words[at + 1]).lstrip("\"'(" + SENTINELS)
	if nxt.is_empty():
		return false
	if needs_number:
		return nxt[0] >= "0" and nxt[0] <= "9"
	# a title needs a capitalized word after it, which is what a name looks like
	return nxt[0] >= "A" and nxt[0] <= "Z"

