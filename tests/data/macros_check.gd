extends SceneTree

## macros_check - the names a line of a note may carry ([code]src/data/macros.gd[/code]), filled. No renderer.
##
##   godot --headless --path . --script res://tests/data/macros_check.gd
##
## - A line of names: the default title filled; a missing value leaves nothing dangling (control: every value filled, the
##   line's own separators stand as written); a gap in the middle closes up; no name twice; an unknown macro is left as
##   written; a line naming none is as written (control: the same line naming one is tidied).
## - Prose: filled and nothing else touched - its lines, a leading dash and a doubled separator kept (control: the same text
##   as a line is tidied).
## - What a line names, which a note does not fill (an empty value is filled, `%date%` always is, an unknown one is no claim),
##   and the sentence saying what each filled one stands for, only those.
## - The dates, on a pinned clock: tonight keeps its date until noon (control: after noon it is today's), the date never does;
##   a form writes it, across a month's and a year's end; a count runs to tonight (control: after noon, one more); a told date
##   stands in any form; a malformed one and a percent sign are words.
## - Every row has a label naming its own key, which its own pattern finds, and a blurb; every date's label is a date to the
##   highlighter too.

const Macros := preload("res://src/data/macros.gd")

var _fails := 0


func _ok(cond: bool, what: String) -> void:
	if cond:
		print("  ok   ", what)
	else:
		_fails += 1
		print("  FAIL ", what)


func _initialize() -> void:
	print("macros_check")
	_line()
	_fill()
	_claims()
	_dates()
	var dates := RegEx.create_from_string(Macros.DATES)
	for k in Macros.ROWS:
		var label := Registry.label(Macros.ROWS, k)
		_ok(label.begins_with("%" + String(k)) and Array(Macros.named_in(label)) == [String(k)]
				and not Registry.blurb(Macros.ROWS, k).is_empty(),
			"the row %s is labeled by its key, its pattern finds it, and it says what it stands for" % k)
		var takes := String(Registry.field(Macros.ROWS, k, "takes", ""))
		_ok(takes.is_empty() == (dates.search(label) == null), "the highlighter finds %s as a date only if it is one" % label)
	print("macros_check: %s" % ("FAILED (%d)" % _fails if _fails > 0 else "ok"))
	quit(1 if _fails > 0 else 0)


func _line() -> void:
	var v := {"title": "Truthful Tarot", "episode": "The Tower"}
	_ok(Macros.line("%title%: %episode%", v) == "Truthful Tarot: The Tower", "the default title")
	_ok(Macros.line("%title%: %episode%", {"title": "A Note"}) == "A Note", "no episode leaves nothing dangling")
	_ok(Macros.line("%title%: %episode%", {"episode": "Bare"}) == "Bare", "no title neither")
	_ok(Macros.line("with Pen & Ink - %episode%", {"title": "T"}) == "with Pen & Ink", "a byline with no episode is the words alone")
	_ok(Macros.line("with Pen & Ink - %episode%", {"episode": "The Tower"}) == "with Pen & Ink - The Tower", "...and with one, both")
	_ok(Macros.line("%title%: %episode%", {"title": "Truthful Tarot", "episode": "truthful tarot: Named"})
		== "truthful tarot: Named", "a name is never said twice")
	var gap := Macros.line("%title% - %episode% - %date%", {"title": "T", "date": "D"})
	_ok(gap == "T - D", "a gap in the middle closes up (%s)" % gap)
	_ok(Macros.line("%title% #%seed% %what%", {"title": "T", "seed": "7"}) == "T #7 %what%", "an unknown macro is left as written")
	_ok(Macros.line("Part -- %episode%:", {"episode": "One"}) == "Part -- One:",
		"control: every value filled, the line's own separators stand as written")
	_ok(Macros.line("  - a line: -- ", {"title": "T"}) == "- a line: --", "a line naming none is as written")
	_ok(Macros.line("  - a line: -- %episode%", {"title": "T"}) == "a line", "control: the same line naming an empty one is tidied")
	_ok(Macros.line("%date%", {}) == Time.get_date_string_from_system(), "the date is today's unless told")


func _fill() -> void:
	var text := "- %title%, episode %seed%: %episode%\n\nMore -- below."
	var v := {"title": "T", "seed": "7", "episode": "E"}
	_ok(Macros.fill(text, v) == "- T, episode 7: E\n\nMore -- below.", "prose is filled, its lines and marks kept")
	_ok(Macros.fill("- %title%: %episode% -- end", {"title": "T"}) == "- T:  -- end",
		"an empty value in prose leaves its words as written")
	_ok(Macros.line("- %title%: %episode% -- end", {"title": "T"}) == "T: end", "control: the same text as a line is tidied")
	_ok(Macros.fill("50% of %what%", v) == "50% of %what%", "a percent sign and an unknown macro are words")


func _claims() -> void:
	_ok(Array(Macros.named_in("%episode% | %title% #%seed%")) == ["title", "episode", "seed"], "what a line names, in the rows' order")
	_ok(Macros.unfilled("%title%: %episode% (%date%)", {"title": "", "episode": ""}).is_empty()
		and Array(Macros.unfilled("%title% #%seed% %what%", {"title": "T"})) == ["seed"],
		"a value filled empty is filled, the date always is, and an unknown macro is no claim")
	var said := Macros.said({"title": "T"})
	_ok(said.begins_with("%title% is ") and said.contains("%date% is ") and not said.contains("%seed%") and said.ends_with("."),
		"the sentence says what each filled one stands for, only those (%s)" % said)
	_ok(Macros.said({}).begins_with("%date% is "), "control: with nothing filled, the date alone")


## A clock pinned to [param day] of November 2026 at [param hour].
func _at(day: int, hour: int, month := 11, year := 2026) -> Dictionary:
	return {"year": year, "month": month, "day": day, "hour": hour, "minute": 30, "second": 0}


func _dates() -> void:
	var late := _at(21, 1)
	var noon := _at(21, 13)
	_ok(Macros.dated("%tonight%", {}, late) == "2026-11-20", "at half past one, tonight is the evening it began")
	_ok(Macros.dated("%tonight%", {}, noon) == "2026-11-21", "control: after noon, tonight is today's")
	_ok(Macros.dated("%date%", {}, late) == "2026-11-21", "the date is the calendar's, past midnight too")
	_ok(Macros.dated("%tonight MM/DD/YYYY%, %tonight MON DD%, %date YY%", {}, late) == "11/20/2026, NOV 20, 26",
		"a form writes the date")
	_ok(Macros.dated("%tonight MON DD%", {}, _at(1, 3, 12)) == "NOV 30" and Macros.dated("%tonight MM/DD/YYYY%", {}, _at(1, 2, 1, 2027))
		== "12/31/2026", "tonight before noon crosses a month's and a year's end")
	var night := "NIGHT %nights since 2019-11-20%"
	_ok(Macros.dated(night, {}, _at(20, 23)) == "NIGHT 2,557" and Macros.dated(night, {}, late) == "NIGHT 2,557",
		"a count of nights runs to tonight, the same after midnight")
	_ok(Macros.dated(night, {}, noon) == "NIGHT 2,558", "control: after noon, one more night")
	_ok(Macros.dated("%days since 2019-11-20%", {}, late) == "2,558", "a count of days runs to today")
	_ok(Macros.dated("%days since 2026-11-25%", {}, late) == "-4" and Macros.counted(1234567) == "1,234,567",
		"a count before its date is negative, and a long one has its commas")
	_ok(Macros.dated("%date MM/DD%", {"date": "[date]"}, late) == "[date]", "a told date stands in any form")
	_ok(Macros.dated("%nights since 2019-11% %date mm/dd% 50% of %what%", {}, late) == "%nights since 2019-11% %date mm/dd% 50% of %what%",
		"a malformed date, a percent sign and an unknown macro are words")
	_ok(Macros.line("%title% - %tonight MON DD%", {"title": "T"}, late) == "T - NOV 20"
		and Macros.fill("- %title%: %nights since 2019-11-20% nights", {"title": "T"}, late) == "- T: 2,557 nights",
		"a line and prose fill their dates with the rest")
	_ok(Macros.line("%title% - %date%", {"title": "T", "date": ""}, late) == "T", "a date told empty is a gap")
	_ok(Macros.written(Macros.date_of("2026-11-20"), "MON DD, YYYY") == "NOV 20, 2026" and Macros.date_of("tonight").is_empty(),
		"a written date is read back, and anything else is none")
