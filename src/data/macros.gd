extends RefCounted

## Macros - the names a line of a note may carry (`%title%`, `%episode%`, `%author%`, `%book%`, `%seed%`, `%date%`), a row
## each ([constant ROWS]), and the line with them filled. One set for every place that takes them: the YouTube title and
## description, a show's Byline under its name on the title screen. Whoever fills one hands what the note says now (its Body
## card's Title, Episode, Author and Book; a show's episode and its seed); `%date%` is today's unless told.
##
## [method line] fills a line of names (a title, a byline) and tidies what an empty value leaves dangling; [method fill]
## fills prose (a description) and touches nothing else. A line naming none is as written.
##
## Loaded by path (no class_name), as youtube.gd is: an app already running when this file lands still loads what reads it.

## A macro a row: `%key%` in a line, `label` as written, `blurb` what it stands for. An `always` one is filled whatever
## the note is; the rest only where whoever fills the line hands it ([method unfilled]).
const ROWS := {
	"title": {"label": "%title%", "blurb": "the note's Title, on its Body card (a show's name)"},
	"episode": {"label": "%episode%", "blurb": "what this video is called: the Episode on the Body card (a show's, its episode's title)"},
	"author": {"label": "%author%", "blurb": "who wrote it: the Author on the Body card"},
	"book": {"label": "%book%", "blurb": "the book it belongs to: the Book on the Body card"},
	"seed": {"label": "%seed%", "blurb": "the episode's seed - a show's episode's number"},
	"date": {"label": "%date%", "blurb": "today's date: the day it renders or goes up", "always": true},
}
## What a gap is tidied of at a line's ends ([method line]).
const TRIM := " :-|·–,/"
## Separators that stand once where two meet across a gap.
const SEPARATORS := "([:|·–-])(\\s*[:|·–-])+"


## [param text] as a line of names: each `%key%` it names filled from [param values] ([constant ROWS], `%date%` today's
## unless told; a key of [param values] beyond them too), an unknown one left as written. Where a value is empty, what it
## leaves dangling goes (": " at either end, two separators where one stood, a doubled space), so "%title%: %episode%" with
## no Episode is the title alone. No name twice: an episode whose name already begins with the title's stands for both.
static func line(text: String, values: Dictionary) -> String:
	var named := named_in(text)
	if named.is_empty():
		return text.strip_edges()
	var v := _values(values)
	var name := str(v.get("title", "")).strip_edges()
	var ep := str(v.get("episode", "")).strip_edges()
	if not name.is_empty() and ep.to_lower().begins_with(name.to_lower()) and named.has("episode"):
		v["title"] = ""
	var gap := false
	for k in named:
		gap = gap or str(v.get(k, "")).strip_edges().is_empty()
	var out := text
	for k in v:
		out = out.replace("%" + str(k) + "%", str(v[k]).strip_edges())
	if not gap:
		return out.strip_edges()
	out = RegEx.create_from_string(SEPARATORS).sub(out, "$1", true)
	out = " ".join(out.split(" ", false))
	while not out.is_empty() and TRIM.contains(out[0]):
		out = out.substr(1)
	while not out.is_empty() and TRIM.contains(out[out.length() - 1]):
		out = out.left(-1)
	return out.strip_edges()


## [param text] with each `%key%` it names replaced by [param values]' ([constant ROWS], `%date%` today's unless told), and
## nothing else touched: prose keeps its lines and punctuation as written.
static func fill(text: String, values: Dictionary) -> String:
	if named_in(text).is_empty():
		return text
	var v := _values(values)
	var out := text
	for k in v:
		out = out.replace("%" + str(k) + "%", str(v[k]).strip_edges())
	return out


## The macros [param text] names ([constant ROWS] keys), in the rows' order.
static func named_in(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	for k in ROWS:
		if text.contains("%" + String(k) + "%"):
			out.append(String(k))
	return out


## The macros [param text] names that [param values] does not fill: a key it lacks, unless the row is `always` filled
## (`%seed%` on a note with no episodes). Empty, every name in it is the note's.
static func unfilled(text: String, values: Dictionary) -> PackedStringArray:
	var out := PackedStringArray()
	for k in named_in(text):
		if not bool(Registry.field(ROWS, k, "always", false)) and not values.has(k):
			out.append(k)
	return out


## What each macro [param values] fills stands for, as a sentence: "%title% is the note's Title ...; %date% is today's
## date ..." - only those it fills ([method unfilled]).
static func said(values: Dictionary) -> String:
	var parts := PackedStringArray()
	for k in ROWS:
		if bool(Registry.field(ROWS, k, "always", false)) or values.has(k):
			parts.append("%s is %s" % [Registry.label(ROWS, k), Registry.blurb(ROWS, k)])
	return "%s." % "; ".join(parts) if not parts.is_empty() else ""


## Every row's key filled empty, today's date, then [param values] over them.
static func _values(values: Dictionary) -> Dictionary:
	var v := {}
	for k in ROWS:
		v[k] = ""
	v["date"] = Time.get_date_string_from_system()
	v.merge(values, true)
	return v
