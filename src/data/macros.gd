extends RefCounted

## Macros - the names a line of a note may carry (`%title%`, `%episode%`, `%author%`, `%book%`, `%seed%`, and the dates
## `%date%`, `%tonight%`, `%days since 2019-11-20%`, `%nights since 2019-11-20%`), a row each ([constant ROWS]), and the
## line with them filled. One set for every place that takes them: the YouTube title and description, a show's Byline
## under its name on the title screen, and - the dates alone - a note's own words, as its reading reads them and its
## medium shows them ([method dated]). Whoever fills one hands what the note says now (its Body card's Title, Episode,
## Author and Book; a show's episode and its seed); a date is the clock's unless told.
##
## A night keeps its date past midnight: `%tonight%` is the evening the night began, the day before until noon
## ([constant NIGHT_TURNS]), so a show made at one in the morning is set on the night it began. A date is written in the
## form after its name (`%tonight MM/DD/YYYY%`: YYYY, YY, MM, DD, MON for NOV), ISO bare; a count is written 2,557.
##
## [method line] fills a line of names (a title, a byline) and tidies what an empty value leaves dangling; [method fill]
## fills prose (a description) and touches nothing else. A line naming none is as written.
##
## Loaded by path (no class_name), as youtube.gd is: an app already running when this file lands still loads what reads it.

## A macro a row: `%key%` in a line, `label` as written, `blurb` what it stands for. An `always` one is filled whatever
## the note is; the rest only where whoever fills the line hands it ([method unfilled]). A date `takes` what follows its
## name ([method pattern]): a `form` to write it in, or the date a count runs `since`; a `night` one counts to tonight.
const ROWS := {
	"title": {"label": "%title%", "blurb": "the note's Title, on its Body card (a show's name)"},
	"episode": {"label": "%episode%", "blurb": "what this video is called: the Episode on the Body card (a show's, its episode's title)"},
	"author": {"label": "%author%", "blurb": "who wrote it: the Author on the Body card"},
	"book": {"label": "%book%", "blurb": "the book it belongs to: the Book on the Body card"},
	"seed": {"label": "%seed%", "blurb": "the episode's seed - a show's episode's number"},
	"date": {"label": "%date%", "blurb": "today's date: the day it renders or goes up", "always": true, "takes": "form"},
	"tonight": {"label": "%tonight%", "blurb": "tonight's date: the evening the night began, the day before until noon", "always": true, "takes": "form", "night": true},
	"days": {"label": "%days since 2019-11-20%", "blurb": "the days from that date to today", "always": true, "takes": "since"},
	"nights": {"label": "%nights since 2019-11-20%", "blurb": "the nights from that date to tonight", "always": true, "takes": "since", "night": true},
}
## What a gap is tidied of at a line's ends ([method line]).
const TRIM := " :-|·–,/"
## Separators that stand once where two meet across a gap.
const SEPARATORS := "([:|·–-])(\\s*[:|·–-])+"
## The hour a night's date turns over: before it, tonight is the night that began the evening before.
const NIGHT_TURNS := 12
## What follows a date's name: the form it is written in (group 1), or the date a count runs from (groups 1-3).
const FORM := " ([A-Z][A-Z/.,: -]*)"
const SINCE := " since (\\d{4})-(\\d{1,2})-(\\d{1,2})"
## Every date macro, as a script's highlighter finds it ([ScriptMarks]); a row's own is [method pattern].
const DATES := "%(?:date|tonight)(?: [A-Z][A-Z/.,: -]*)?%|%(?:days|nights) since \\d{4}-\\d{1,2}-\\d{1,2}%"
const MONTHS := ["JAN", "FEB", "MAR", "APR", "MAY", "JUN", "JUL", "AUG", "SEP", "OCT", "NOV", "DEC"]

static var _re := {}


## [param text] as a line of names: each `%key%` it names filled from [param values] ([constant ROWS], the dates as of
## [param now] unless told; a key of [param values] beyond them too), an unknown one left as written. Where a value is
## empty, what it leaves dangling goes (": " at either end, two separators where one stood, a doubled space), so
## "%title%: %episode%" with no Episode is the title alone. No name twice: an episode whose name already begins with the
## title's stands for both.
static func line(text: String, values: Dictionary, now := {}) -> String:
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
		# a date is never empty unless told so
		var told := values.has(k) or String(Registry.field(ROWS, k, "takes", "")).is_empty()
		gap = gap or (told and str(v.get(k, "")).strip_edges().is_empty())
	var out := dated(text, values, now)
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


## [param text] with each `%key%` it names replaced by [param values]' ([constant ROWS], the dates as of [param now]
## unless told), and nothing else touched: prose keeps its lines and punctuation as written.
static func fill(text: String, values: Dictionary, now := {}) -> String:
	if named_in(text).is_empty():
		return text
	var v := _values(values)
	var out := dated(text, values, now)
	for k in v:
		out = out.replace("%" + str(k) + "%", str(v[k]).strip_edges())
	return out


## [param text] with its dates filled and nothing else touched: each date macro ([constant DATES]) as of [param now]
## ({year, month, day, hour}; the clock's when empty), or as [param values] tells it. What a note's words take.
static func dated(text: String, values := {}, now := {}) -> String:
	if not text.contains("%"):
		return text
	var out := text
	for k in ROWS:
		var takes := String(Registry.field(ROWS, k, "takes", ""))
		if takes.is_empty():
			continue
		var found := _rx(pattern(k)).search_all(out)
		if found.is_empty():
			continue
		var parts := PackedStringArray()
		var at := 0
		for m in found:
			parts.append(out.substr(at, m.get_start() - at))
			parts.append(_date_of(k, takes, m, values, now))
			at = m.get_end()
		parts.append(out.substr(at))
		out = "".join(parts)
	return out


## How [param k] is found in a line: `%key%`, a date with the form it is written in after it, or a count with the date it
## runs since.
static func pattern(k: String) -> String:
	match String(Registry.field(ROWS, k, "takes", "")):
		"form":
			return "%" + k + "(?:" + FORM + ")?%"
		"since":
			return "%" + k + SINCE + "%"
	return "%" + k + "%"


## The macros [param text] names ([constant ROWS] keys), in the rows' order.
static func named_in(text: String) -> PackedStringArray:
	var out := PackedStringArray()
	if not text.contains("%"):
		return out
	for k in ROWS:
		if _rx(pattern(String(k))).search(text) != null:
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


# --- dates ----------------------------------------------------------------------------------------------------------

## Today's date, {year, month, day}: [param now]'s ({year, month, day, hour}), else the clock's.
static func today(now := {}) -> Dictionary:
	var t: Dictionary = now if not now.is_empty() else Time.get_datetime_dict_from_system()
	return {"year": int(t["year"]), "month": int(t["month"]), "day": int(t["day"])}


## Tonight's date: the evening the night began - today's from [constant NIGHT_TURNS] on, the day before until then.
static func tonight(now := {}) -> Dictionary:
	var t: Dictionary = now if not now.is_empty() else Time.get_datetime_dict_from_system()
	var d := today(t)
	return d if int(t.get("hour", NIGHT_TURNS)) >= NIGHT_TURNS else shifted(d, -1)


## [param d] moved on by [param days] (back, where negative).
static func shifted(d: Dictionary, days: int) -> Dictionary:
	var t := Time.get_datetime_dict_from_unix_time(_unix(d) + days * 86400)
	return {"year": int(t["year"]), "month": int(t["month"]), "day": int(t["day"])}


## The days from [param a] to [param b] (negative where [param b] comes first).
static func days_between(a: Dictionary, b: Dictionary) -> int:
	return int(round(float(_unix(b) - _unix(a)) / 86400.0))


## [param d] written in [param form] (YYYY, YY, MM, DD, MON; anything else as written), `YYYY-MM-DD` bare.
static func written(d: Dictionary, form := "") -> String:
	var f := form if not form.is_empty() else "YYYY-MM-DD"
	var out := ""
	var i := 0
	while i < f.length():
		if f.substr(i, 4) == "YYYY":
			out += "%04d" % int(d["year"])
			i += 4
		elif f.substr(i, 3) == "MON":
			out += MONTHS[clampi(int(d["month"]), 1, 12) - 1]
			i += 3
		elif f.substr(i, 2) == "YY":
			out += "%02d" % (int(d["year"]) % 100)
			i += 2
		elif f.substr(i, 2) == "MM":
			out += "%02d" % int(d["month"])
			i += 2
		elif f.substr(i, 2) == "DD":
			out += "%02d" % int(d["day"])
			i += 2
		else:
			out += f[i]
			i += 1
	return out


## A date written `YYYY-MM-DD` as {year, month, day}; {} for anything else.
static func date_of(text: String) -> Dictionary:
	var m := _rx("^(\\d{4})-(\\d{1,2})-(\\d{1,2})$").search(text.strip_edges())
	if m == null:
		return {}
	return {"year": int(m.get_string(1)), "month": int(m.get_string(2)), "day": int(m.get_string(3))}


## [param n] written as a count is: 2,557.
static func counted(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	while s.length() > 3:
		out = "," + s.right(3) + out
		s = s.left(-3)
	return ("-" if n < 0 else "") + s + out


## What the date macro [param k] found as [param m] stands for: as [param values] tells it, else its date written in its
## form, or its count up to that date.
static func _date_of(k: String, takes: String, m: RegExMatch, values: Dictionary, now: Dictionary) -> String:
	if values.has(k):
		return str(values[k]).strip_edges()
	var d := tonight(now) if bool(Registry.field(ROWS, k, "night", false)) else today(now)
	if takes == "form":
		return written(d, m.get_string(1))
	var since := {"year": int(m.get_string(1)), "month": int(m.get_string(2)), "day": int(m.get_string(3))}
	return counted(days_between(since, d))


static func _unix(d: Dictionary) -> int:
	return Time.get_unix_time_from_datetime_dict({"year": int(d["year"]), "month": int(d["month"]), "day": int(d["day"]),
		"hour": 12, "minute": 0, "second": 0})


static func _rx(p: String) -> RegEx:
	if not _re.has(p):
		_re[p] = RegEx.create_from_string(p)
	return _re[p]


## Every row's key filled empty, then [param values] over them: the dates are [method dated]'s.
static func _values(values: Dictionary) -> Dictionary:
	var v := {}
	for k in ROWS:
		v[k] = ""
	v.merge(values, true)
	return v
