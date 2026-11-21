extends RefCounted
class_name Lyrics

## Lyrics - a note's words read as a song's: sections, lines, words, each word's syllables and their stress, and how a
## word the note spells is sung (next/music.md, "Singing"). The words are a script like any other, its marks those of
## [ScriptMarks] a song's editor offers ("song"): a section begins at its mark, a line of its own -
##
##   <!-- verse -->              a verse; <!-- chorus -->, <!-- bridge --> the others (a pre-chorus is a bridge, a hook
##                               or refrain a chorus - named so on the card)
##   Welcome random user         a sung line
##   ...
##   <!-- repeat -->             the section so far sung again (<!-- repeat: 3 --> three times in all)
##   <!-- chorus -->             a section's mark with no lines under it: the last section of its kind sung again
##   <!-- break: 8 -->           an instrumental section of 8 bars (a solo, interlude or instrumental is a break), as
##                               <!-- intro: 4 --> and <!-- ending: 4 --> are; bare, INSTRUMENTAL_BARS
##
## An instrumental section rides on the sung section after it (`before`), the last ones on the last (`after`), so a
## section of the words keeps its index whatever is written between them.
## Every other mark is the note's and never sung - a heading, a note to self, a picture, anything fenced - and
## `<!-- say: word = AH1 ... -->` anywhere says how a word is sung as it says how one is spoken: its ARPAbet (`arpa`) and
## IPA (`say`) ride on the word to the voice host, which sings it so, and its syllables and stress are the ones the
## composer places. A blank line ends a stanza; lines before any section's mark are a verse. A section's kind is a
## [constant SongParts.SECTIONS] key.
##
## Syllables and stress are ghost's own reading ([method Phonemes.lookup]): what a composer places on the beat. The
## voice that sings may split a word otherwise; the singer's host matches its own syllables to the notes it is given.

## A section's mark: its name, and the kind of section each name is.
const SECTION := "(?i)^\\s*<!--\\s*(verse|chorus|bridge|pre-?chorus|hook|refrain)\\s*-->\\s*$"
const KINDS := {"verse": "verse", "chorus": "chorus", "bridge": "bridge", "pre-chorus": "bridge", "prechorus": "bridge",
	"hook": "chorus", "refrain": "chorus"}
## An instrumental section's mark: its name and its bars, and the kind of section each name is.
const INSTRUMENTAL := "(?i)^\\s*<!--\\s*(intro|break|solo|interlude|instrumental|ending)\\s*(?::\\s*(\\d+))?\\s*-->\\s*$"
const INSTRUMENTAL_KINDS := {"intro": "intro", "break": "break", "solo": "break", "interlude": "break", "instrumental": "break",
	"ending": "outro"}
const INSTRUMENTAL_BARS := 4
## The section so far sung again: how many times in all (bare, twice).
const REPEAT := "(?i)^\\s*<!--\\s*repeat\\s*(?::\\s*(\\d+))?\\s*-->\\s*$"
const LABELS := {"verse": "Verse", "chorus": "Chorus", "bridge": "Bridge", "pre-chorus": "Pre-chorus", "prechorus": "Pre-chorus",
	"hook": "Hook", "refrain": "Refrain", "intro": "Intro", "break": "Break", "solo": "Solo", "interlude": "Interlude",
	"instrumental": "Instrumental", "ending": "Ending"}

static var _section := RegEx.create_from_string(SECTION)
static var _instrumental := RegEx.create_from_string(INSTRUMENTAL)
static var _repeat := RegEx.create_from_string(REPEAT)
static var _comment := RegEx.create_from_string(Manuscript.COMMENT)
static var _said := RegEx.create_from_string(Manuscript.SAY)
static var _word := RegEx.create_from_string("[A-Za-z][A-Za-z']*")


## [param body] (a note's words, frontmatter apart) read as sections:
## `[{kind, label, lines: [{text, stanza, words: [{text, syllables, stress: [0|1|2 a syllable], arpa?, say?}]}],
## before?, after?: [{kind, label, bars}] the instrumental sections written before it (and, on the last, after it)}]`.
static func parse(body: String) -> Array:
	var said := said_in(body)
	var sections: Array = []
	var cur: Dictionary = {}
	var pending: Array = []  # instrumental sections written since the last section of the words began
	var stanza := 0
	var blank := false
	var fenced := false
	var text := body.replace("\r\n", "\n")
	# a mark that runs over several lines (a long note to self) is taken out whole: none of its lines is sung
	var spans: Array = _comment.search_all(text)
	spans.reverse()
	for m in spans:
		if (m as RegExMatch).get_string().contains("\n"):
			text = text.substr(0, (m as RegExMatch).get_start()) + text.substr((m as RegExMatch).get_end())
	for raw in text.split("\n"):
		var line := String(raw).strip_edges()
		if line.begins_with("```"):
			fenced = not fenced
			continue
		if fenced:
			continue
		if line.is_empty():
			blank = true
			continue
		var h := _section.search(line)
		if h != null:
			var name := h.get_string(1).to_lower()
			cur = {"kind": String(KINDS[name]), "label": String(LABELS[name]), "lines": []}
			if not pending.is_empty():
				cur["before"] = pending
				pending = []
			sections.append(cur)
			stanza = 0
			blank = false
			continue
		var inst := _instrumental.search(line)
		if inst != null:
			var name := inst.get_string(1).to_lower()
			var bars := int(inst.get_string(2)) if not inst.get_string(2).is_empty() else INSTRUMENTAL_BARS
			pending.append({"kind": String(INSTRUMENTAL_KINDS[name]), "label": String(LABELS[name]), "bars": maxi(bars, 1)})
			continue
		var r := _repeat.search(line)
		if r != null:
			if not cur.is_empty():
				var once: Array = (cur["lines"] as Array).duplicate(true)
				var top := 0
				for l in once:
					top = maxi(top, int(l["stanza"]))
				var times := int(r.get_string(1)) if not r.get_string(1).is_empty() else 2
				for k in range(1, maxi(times, 1)):
					for l in once:
						var copy: Dictionary = (l as Dictionary).duplicate(true)
						copy["stanza"] = int(l["stanza"]) + k * (top + 1)
						(cur["lines"] as Array).append(copy)
			continue
		line = _comment.sub(line, "", true).strip_edges()
		if line.is_empty() or line.begins_with("#"):
			continue  # a mark of the note's, or a heading: not sung
		if cur.is_empty():
			cur = {"kind": "verse", "label": "Verse", "lines": []}
			sections.append(cur)
		if blank and not (cur["lines"] as Array).is_empty():
			stanza += 1
		blank = false
		var words := words_of(line, said)
		if not words.is_empty():
			(cur["lines"] as Array).append({"text": line, "stanza": stanza, "words": words})
	# a section's mark with no lines of its own is the last of its kind again
	for i in sections.size():
		if (sections[i]["lines"] as Array).is_empty():
			for j in range(i - 1, -1, -1):
				if String(sections[j]["kind"]) == String(sections[i]["kind"]) and not (sections[j]["lines"] as Array).is_empty():
					sections[i]["lines"] = (sections[j]["lines"] as Array).duplicate(true)
					break
	# a section left with no lines hands what was written before it on to the next
	var out: Array = []
	var carried: Array = []
	for s in sections:
		var before: Array = carried + (s.get("before", []) as Array)
		carried = []
		if (s["lines"] as Array).is_empty():
			carried = before
			continue
		if before.is_empty():
			s.erase("before")
		else:
			s["before"] = before
		out.append(s)
	pending = carried + pending
	if not pending.is_empty() and not out.is_empty():
		out.back()["after"] = pending
	return out


## Every `say:` mark of [param body]: each word -> how it is said ([method Phonemes.said_as]).
static func said_in(body: String) -> Dictionary:
	var out := {}
	for m in _said.search_all(body):
		out.merge(Phonemes.said_as(m.get_string(1)), true)
	return out


## A line's words, each with its syllables and their stress - a word [param said] spells, by its spelling, carrying its
## ARPAbet (`arpa`, a vowel's stress its digit) and IPA (`say`) for the voice that sings it.
static func words_of(line: String, said := {}) -> Array:
	var out: Array = []
	for m in _word.search_all(line):
		var text := m.get_string()
		var told: Dictionary = said.get(text.to_lower(), {})
		var look := told if not (told.get("phones", []) as Array).is_empty() else Phonemes.lookup(text.to_lower())
		var stress: Array = []
		var arpa: Array = []
		var phones: Array = look.get("phones", [])
		var marks: Array = look.get("stress", [])
		for i in phones.size():
			var vowel := String(Phonemes.TABLE.get(phones[i], {}).get("type", "")) == "vowel"
			if vowel:
				stress.append(int(marks[i]) if i < marks.size() else 0)
			arpa.append(String(phones[i]) + (str(int(marks[i]) if i < marks.size() else 0) if vowel else ""))
		if stress.is_empty():
			stress = [1]
		var w := {"text": text, "syllables": stress.size(), "stress": stress}
		if not told.is_empty():
			if not (told.get("phones", []) as Array).is_empty():
				w["arpa"] = arpa
			if told.has("ipa"):
				w["say"] = String(told["ipa"])
		out.append(w)
	return out


## Every sung line of [param sections], in order: `[{text, words, section (its index), kind, at (its place in its
## section)}]`.
static func lines_of(sections: Array) -> Array:
	var out: Array = []
	for si in sections.size():
		var s: Dictionary = sections[si]
		var k := 0
		for l in s["lines"]:
			out.append({"text": l["text"], "words": l["words"], "section": si, "kind": s["kind"], "at": k})
			k += 1
	return out


## The syllables of a line.
static func syllables_of(line: Dictionary) -> int:
	var n := 0
	for w in line.get("words", []):
		n += int(w["syllables"])
	return n
