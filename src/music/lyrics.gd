extends RefCounted
class_name Lyrics

## Lyrics - a note's words read as a song's: sections, lines, words, and each word's syllables and their stress
## (next/music.md, "Singing"). The note's words are written as lyrics usually are:
##
##   Verse                       a section's name alone on a line (also `## Verse`, `[Verse 2]`, `Chorus:`)
##   Welcome random user         a sung line
##   ...
##   x2                          the section so far sung again (`(x2)`, `×3`)
##
## A blank line ends a stanza. Lines before any section's name are a verse; a heading that names no section (the
## note's title) is not sung. A section's kind is a [constant SongParts.SECTIONS] key: a refrain or hook is a chorus,
## a pre-chorus a bridge, a solo or interlude a break.
##
## Syllables and stress are ghost's own reading ([method Phonemes.lookup]): what a composer places on the beat. The
## voice that sings may split a word otherwise; the singer's host matches its own syllables to the notes it is given.

const KINDS := {"intro": "intro", "verse": "verse", "chorus": "chorus", "refrain": "chorus", "hook": "chorus",
	"pre-chorus": "bridge", "prechorus": "bridge", "bridge": "bridge", "break": "break", "solo": "break",
	"interlude": "break", "instrumental": "break", "outro": "outro", "coda": "outro"}

static var _header := RegEx.create_from_string(
	"(?i)^\\s*(?:#+\\s*)?\\[?\\s*(intro|verse|pre-?chorus|chorus|refrain|hook|bridge|break|solo|interlude|instrumental|outro|coda)\\b[^\\]:]*\\]?\\s*:?\\s*$")
static var _repeat := RegEx.create_from_string("(?i)^\\s*\\(?\\s*[x×]\\s*(\\d+)\\s*\\)?\\s*$")
static var _word := RegEx.create_from_string("[A-Za-z][A-Za-z']*")


## [param body] (a note's words, frontmatter apart) read as sections:
## `[{kind, label, lines: [{text, stanza, words: [{text, syllables, stress: [0|1|2 a syllable]}]}]}]`.
static func parse(body: String) -> Array:
	var sections: Array = []
	var cur: Dictionary = {}
	var stanza := 0
	var blank := false
	for raw in body.replace("\r\n", "\n").split("\n"):
		var line := String(raw).strip_edges()
		if line.is_empty():
			blank = true
			continue
		var h := _header.search(line)
		if h != null:
			var word := h.get_string(1).to_lower().replace(" ", "")
			var kind := String(KINDS.get(word, "verse"))
			cur = {"kind": kind, "label": line.trim_prefix("#").strip_edges().trim_prefix("[").trim_suffix("]").trim_suffix(":").strip_edges(),
				"lines": []}
			sections.append(cur)
			stanza = 0
			blank = false
			continue
		var r := _repeat.search(line)
		if r != null:
			if not cur.is_empty():
				var once: Array = (cur["lines"] as Array).duplicate(true)
				var top := 0
				for l in once:
					top = maxi(top, int(l["stanza"]))
				for k in range(1, maxi(int(r.get_string(1)), 1)):
					for l in once:
						var copy: Dictionary = (l as Dictionary).duplicate(true)
						copy["stanza"] = int(l["stanza"]) + k * (top + 1)
						(cur["lines"] as Array).append(copy)
			continue
		if line.begins_with("#"):
			continue  # the note's title, not sung
		if cur.is_empty():
			cur = {"kind": "verse", "label": "Verse", "lines": []}
			sections.append(cur)
		if blank and not (cur["lines"] as Array).is_empty():
			stanza += 1
		blank = false
		var words := words_of(line)
		if not words.is_empty():
			(cur["lines"] as Array).append({"text": line, "stanza": stanza, "words": words})
	return sections.filter(func(s: Dictionary) -> bool: return not (s["lines"] as Array).is_empty())


## A line's words, each with its syllables and their stress.
static func words_of(line: String) -> Array:
	var out: Array = []
	for m in _word.search_all(line):
		var text := m.get_string()
		var look := Phonemes.lookup(text.to_lower())
		var stress: Array = []
		var phones: Array = look.get("phones", [])
		var marks: Array = look.get("stress", [])
		for i in phones.size():
			if String(Phonemes.TABLE.get(phones[i], {}).get("type", "")) == "vowel":
				stress.append(int(marks[i]) if i < marks.size() else 0)
		if stress.is_empty():
			stress = [1]
		out.append({"text": text, "syllables": stress.size(), "stress": stress})
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
